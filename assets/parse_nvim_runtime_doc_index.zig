//! Parse Neovim's runtime/doc/index.txt using Zig 0.17.0.
//!
//! Run:   zig run parse_nvim_runtime_doc_index.zig -- ./index.txt
//! Build: zig build-exe parse_nvim_runtime_doc_index.zig
//!        ./parse_nvim_runtime_doc_index ./index.txt
//!
//! Output: TSV, one record per line, with this header:
//! section<TAB>keys<TAB>tag<TAB>note<TAB>description
//! Note: 1 = cursor movement; 2 = undoable/redoable; 1,2 = both.
//! Empty tags are intentional. Repeated keys and aliases are preserved.
//! This parses the documented commands, not your live Neovim configuration.

const std = @import("std");
const Allocator = std.mem.Allocator;

const usage =
    "Usage: parse_nvim_runtime_doc_index <path/to/index.txt>\n" ++
    "Example: zig run parse_nvim_runtime_doc_index.zig -- ./index.txt\n";

pub fn main(init: std.process.Init) u8 {
    return run(init) catch |err| {
        std.debug.print("parse_nvim_runtime_doc_index: {s}\n", .{@errorName(err)});
        return 1;
    };
}

fn run(init: std.process.Init) !u8 {
    const arena = init.arena.allocator();
    const args = try init.minimal.args.toSlice(arena);

    if (args.len == 2 and (std.mem.eql(u8, args[1], "--help") or
        std.mem.eql(u8, args[1], "-h")))
    {
        try std.Io.File.stdout().writeStreamingAll(init.io, usage);
        return 0;
    }
    if (args.len != 2) {
        try std.Io.File.stderr().writeStreamingAll(init.io, usage);
        return 2;
    }

    // Relative paths are resolved from the shell's current working directory.
    const input = std.Io.Dir.cwd().readFileAlloc(
        init.io,
        args[1],
        arena,
        .unlimited,
    ) catch |err| {
        std.debug.print("Cannot read '{s}': {s}\n", .{ args[1], @errorName(err) });
        return 1;
    };

    var buffer: [16 * 1024]u8 = undefined;
    var stdout = std.Io.File.stdout().writerStreaming(init.io, &buffer);
    var parser: Parser = .{ .allocator = arena, .out = &stdout.interface };
    try parser.parse(input);
    if (parser.count == 0) return error.NoMappingsFound;
    try stdout.interface.flush();
    return 0;
}

const Row = struct {
    keys: []const u8,
    tag: []const u8 = "",
};

const Parser = struct {
    allocator: Allocator,
    out: *std.Io.Writer,
    section: []const u8 = "",
    subsection: []const u8 = "",
    in_table: bool = false,
    has_notes: bool = false,
    terminal_continuation: bool = false,
    count: usize = 0,

    // Adjacent rows with no description share the next description block.
    // For example, c_CTRL-R_CTRL-R and c_CTRL-R_CTRL-O in the supplied index.
    pending: std.ArrayList(Row) = .empty,
    description: std.ArrayList(u8) = .empty,
    note: []const u8 = "",

    fn parse(self: *Parser, input: []const u8) !void {
        const bytes = if (std.mem.startsWith(u8, input, "\xef\xbb\xbf")) input[3..] else input;
        var lines = std.mem.splitScalar(u8, bytes, '\n');
        while (lines.next()) |raw| {
            const line = std.mem.trimEnd(u8, raw, "\r");
            const text = trim(line);

            if (text.len == 0) {
                try self.flush();
                self.terminal_continuation = false;
                continue;
            }
            if (sectionTitle(text)) |title| {
                try self.flush();
                self.section = title;
                self.subsection = "";
                self.in_table = false;
                self.has_notes = false;
                self.terminal_continuation = false;
                continue;
            }
            if (std.mem.startsWith(u8, text, "====")) {
                try self.flush();
                self.in_table = false;
                self.terminal_continuation = false;
                continue;
            }
            if (std.mem.startsWith(u8, text, "Tag") and
                (std.mem.find(u8, text, "action") != null or
                    std.mem.find(u8, text, "Action") != null))
            {
                try self.flush();
                self.in_table = true;
                self.has_notes = std.mem.find(u8, text, "Note") != null;
                continue;
            }
            if (std.mem.startsWith(u8, text, "commands in ")) {
                try self.flush();
                self.subsection = withoutHelpTags(text["commands in ".len..]);
                self.in_table = true;
                continue;
            }
            if (std.mem.startsWith(u8, text, "----")) continue;

            // Terminal mode lists its two special commands in prose, not a table.
            if (std.mem.eql(u8, self.section, "Terminal mode")) {
                if (std.mem.startsWith(u8, text, "Use |")) {
                    const rest = text["Use |".len..];
                    if (std.mem.find(u8, rest, "| to ")) |end| {
                        try self.flush();
                        const tag = rest[0..end];
                        const key_tag = if (std.mem.startsWith(u8, tag, "t_")) tag[2..] else tag;
                        const keys = try self.allocator.dupe(u8, key_tag);
                        for (keys) |*c| {
                            if (c.* == '_') c.* = ' ';
                        }
                        try self.pending.append(self.allocator, .{ .keys = keys, .tag = tag });
                        try self.appendDescription(rest[end + "| to ".len ..]);
                        self.terminal_continuation = true;
                        continue;
                    }
                }
                if (self.terminal_continuation) try self.appendDescription(text);
                continue;
            }
            if (!self.in_table) continue;

            // A tagged row begins in column zero. Tags can be references,
            // definitions (the mouse-wheel rows), or a quoted option ('cedit').
            if (line[0] == '|' or line[0] == '*' or line[0] == '\'') {
                const end = std.mem.findScalarPos(u8, line, 1, line[0]) orelse continue;
                if (end + 1 >= line.len or !isSpace(line[end + 1])) continue;
                const tag = if (line[0] == '\'') line[0 .. end + 1] else line[1..end];
                try self.startRow(tag, trim(line[end + 1 ..]), true);
                continue;
            }

            // In the original help file, untagged keys start at visual column
            // 16 (zero-based); wrapped descriptions start at column 32 or 35.
            // Expand only the leading indentation, using Vim's 8-column tabs.
            const indent = indentation(line);
            if (indent.columns >= 16 and indent.columns < 30) {
                try self.startRow("", text, false);
            } else if (indent.columns >= 30 and self.pending.items.len != 0) {
                try self.appendDescription(text);
            } else {
                // Do not attach explanatory prose or the final modeline.
                try self.flush();
                self.in_table = false;
            }
        }
        try self.flush();
    }

    fn startRow(self: *Parser, tag: []const u8, text: []const u8, tagged: bool) !void {
        if (text.len == 0) return;
        if (self.description.items.len != 0) try self.flush();
        const boundary = commandEnd(text, tagged);
        try self.pending.append(self.allocator, .{ .keys = trim(text[0..boundary]), .tag = tag });
        try self.appendDescription(text[boundary..]);
    }

    fn appendDescription(self: *Parser, text: []const u8) !void {
        var words = std.mem.tokenizeAny(u8, text, " \t\r");
        while (words.next()) |word| {
            if (self.has_notes and self.description.items.len == 0 and self.note.len == 0 and
                (std.mem.eql(u8, word, "1") or std.mem.eql(u8, word, "2") or
                    std.mem.eql(u8, word, "1,2")))
            {
                self.note = word;
                continue;
            }
            if (self.description.items.len != 0) try self.description.append(self.allocator, ' ');
            try self.description.appendSlice(self.allocator, word);
        }
    }

    fn flush(self: *Parser) !void {
        for (self.pending.items) |row| {
            if (self.count == 0) try self.out.writeAll("section\tkeys\ttag\tnote\tdescription\n");
            try self.out.writeAll(self.section);
            if (self.subsection.len != 0) try self.out.print(" / {s}", .{self.subsection});
            try self.out.print("\t{s}\t{s}\t{s}\t{s}\n", .{
                row.keys, row.tag, self.note, self.description.items,
            });
            self.count += 1;
        }
        self.pending.clearRetainingCapacity();
        self.description.clearRetainingCapacity();
        self.note = "";
    }
};

fn trim(text: []const u8) []const u8 {
    return std.mem.trim(u8, text, " \t\r");
}

fn isSpace(c: u8) bool {
    return c == ' ' or c == '\t';
}

fn withoutHelpTags(text: []const u8) []const u8 {
    return trim(text[0 .. std.mem.findScalar(u8, text, '*') orelse text.len]);
}

fn sectionTitle(text: []const u8) ?[]const u8 {
    const end = std.mem.findAny(u8, text, " \t") orelse return null;
    if (end == 0 or !std.ascii.isDigit(text[0])) return null;
    var has_dot = false;
    for (text[0..end]) |c| {
        if (c == '.') {
            has_dot = true;
        } else if (!std.ascii.isDigit(c)) return null;
    }
    if (!has_dot) return null;
    return withoutHelpTags(text[end..]);
}

fn indentation(line: []const u8) struct { bytes: usize, columns: usize } {
    var bytes: usize = 0;
    var columns: usize = 0;
    while (bytes < line.len and isSpace(line[bytes])) : (bytes += 1) {
        columns = if (line[bytes] == '\t') (columns / 8 + 1) * 8 else columns + 1;
    }
    return .{ .bytes = bytes, .columns = columns };
}

fn commandEnd(text: []const u8, tagged: bool) usize {
    // Most rows use a tab after the entire command, including its arguments.
    if (std.mem.findScalar(u8, text, '\t')) |end| return end;

    // A few long rows use spaces alone, e.g. "CTRL-V {number} insert ..."
    // and ":menut[ranslate] add ...". A long key may also occupy the whole
    // line, with its description below. Single key letters and CTRL-*, <...>,
    // {...}, etc. remain part of the command.
    // Untagged no-tab text ("Meta characters (0x80 ...)") is a whole key field.
    if (!tagged) return text.len;
    var i: usize = 0;
    while (i < text.len) : (i += 1) {
        if (text[i] != ' ') continue;
        var next = i;
        while (next < text.len and text[next] == ' ') : (next += 1) {}
        if (next == text.len) return i;
        if (next - i >= 2) return i;
        var end = next;
        while (end < text.len and !isSpace(text[end])) : (end += 1) {}
        const word = text[next..end];
        if (word.len > 1 and std.ascii.isLower(word[0])) return i;
        i = end - 1;
    }
    return text.len;
}
