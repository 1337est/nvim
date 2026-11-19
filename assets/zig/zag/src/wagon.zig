const std = @import("std");
const linux = std.os.linux;

// ── Output buffer ──────────────────────────────────────────────────

const Out = struct {
    buf: [2 * 1024 * 1024]u8 = undefined,
    pos: usize = 0,

    fn w(self: *Out, s: []const u8) void {
        @memcpy(self.buf[self.pos..][0..s.len], s);
        self.pos += s.len;
    }
    fn wName(self: *Out, s: []const u8) void {
        if (needsEscape(s)) {
            self.w("@\"");
            self.w(s);
            self.w("\"");
        } else self.w(s);
    }
    fn wInt(self: *Out, val: usize) void {
        var tmp: [20]u8 = undefined;
        const s = std.fmt.bufPrint(&tmp, "{d}", .{val}) catch unreachable;
        self.w(s);
    }
    fn slice(self: *Out) []const u8 {
        return self.buf[0..self.pos];
    }
};

fn needsEscape(s: []const u8) bool {
    const kws = [_][]const u8{
        "error",    "type",   "enum",      "struct",   "union",
        "align",    "test",   "return",    "fn",       "break",
        "continue", "else",   "for",       "while",    "switch",
        "and",      "or",     "async",     "await",    "suspend",
        "resume",   "cancel", "defer",     "errdefer", "catch",
        "try",      "null",   "undefined", "true",     "false",
        "inline",   "pub",    "const",     "var",      "extern",
        "export",   "if",     "orelse",    "comptime", "unreachable",
    };
    for (&kws) |kw| {
        if (std.mem.eql(u8, s, kw)) return true;
    }
    // leading digit
    if (s.len > 0 and s[0] >= '0' and s[0] <= '9') return true;
    return false;
}

// ── XML helpers ────────────────────────────────────────────────────

fn getAttr(content: []const u8, attr: []const u8) ?[]const u8 {
    var i: usize = 0;
    while (i + attr.len < content.len) : (i += 1) {
        if (!std.mem.eql(u8, content[i..][0..attr.len], attr)) continue;
        const after = i + attr.len;
        if (after >= content.len or content[after] != '=') continue;
        // check it's a word boundary before attr name
        if (i > 0 and isIdChar(content[i - 1])) continue;
        if (after + 1 >= content.len) return null;
        const q = content[after + 1];
        if (q != '"' and q != '\'') return null;
        const start = after + 2;
        const end = std.mem.indexOfScalar(u8, content[start..], q) orelse return null;
        return content[start..][0..end];
    }
    return null;
}

fn isIdChar(c: u8) bool {
    return (c >= 'a' and c <= 'z') or (c >= 'A' and c <= 'Z') or
        (c >= '0' and c <= '9') or c == '_' or c == '-';
}

fn tagName(content: []const u8) []const u8 {
    // skip leading whitespace
    var s: usize = 0;
    while (s < content.len and (content[s] == ' ' or content[s] == '\t' or content[s] == '\n')) : (s += 1) {}
    var e: usize = s;
    while (e < content.len and isIdChar(content[e])) : (e += 1) {}
    return content[s..e];
}

// ── Protocol model (per-interface, buffered) ───────────────────────

const MAX_MSGS = 48;
const MAX_ENUMS = 16;
const MAX_ENTRIES = 256;

const MsgInfo = struct { name: []const u8 = "" };
const EntryInfo = struct { name: []const u8 = "", value: []const u8 = "" };
const EnumInfo = struct {
    name: []const u8 = "",
    entries: [MAX_ENTRIES]EntryInfo = undefined,
    entry_count: u16 = 0,
};

const Iface = struct {
    name: []const u8 = "",
    version: []const u8 = "1",
    reqs: [MAX_MSGS]MsgInfo = undefined,
    req_count: u8 = 0,
    evts: [MAX_MSGS]MsgInfo = undefined,
    evt_count: u8 = 0,
    enums: [MAX_ENUMS]EnumInfo = undefined,
    enum_count: u8 = 0,
};

// ── Emit one interface ─────────────────────────────────────────────

fn emitIface(out: *Out, iface: *const Iface) void {
    out.w("pub const ");
    out.wName(iface.name);
    out.w(" = struct {\n");
    out.w("    pub const name = \"");
    out.w(iface.name);
    out.w("\";\n    pub const version: u32 = ");
    out.w(iface.version);
    out.w(";\n");

    if (iface.req_count > 0) {
        out.w("    pub const request = struct {\n");
        for (iface.reqs[0..iface.req_count], 0..) |msg, i| {
            out.w("        pub const ");
            out.wName(msg.name);
            out.w(": u16 = ");
            out.wInt(i);
            out.w(";\n");
        }
        out.w("    };\n");
    }

    if (iface.evt_count > 0) {
        out.w("    pub const event = struct {\n");
        for (iface.evts[0..iface.evt_count], 0..) |msg, i| {
            out.w("        pub const ");
            out.wName(msg.name);
            out.w(": u16 = ");
            out.wInt(i);
            out.w(";\n");
        }
        out.w("    };\n");
    }

    for (iface.enums[0..iface.enum_count]) |e| {
        out.w("    pub const ");
        out.wName(e.name);
        out.w(" = struct {\n");
        for (e.entries[0..e.entry_count]) |ent| {
            out.w("        pub const ");
            out.wName(ent.name);
            out.w(" = ");
            out.w(ent.value);
            out.w(";\n");
        }
        out.w("    };\n");
    }

    out.w("};\n\n");
}

// ── Main ───────────────────────────────────────────────────────────

fn sysWrite(fd: i32, data: []const u8) void {
    var off: usize = 0;
    while (off < data.len) {
        const rc: isize = @bitCast(linux.write(fd, data[off..].ptr, data[off..].len));
        if (rc <= 0) return;
        off += @intCast(rc);
    }
}

pub fn main(init: std.process.Init) !void {
    var args = init.minimal.args.iterate();
    _ = args.next(); // skip program name
    const in_path = args.next() orelse {
        std.debug.print("usage: waygen-scanner <input.xml> <output.zig>\n", .{});
        return error.MissingArgs;
    };
    const out_path = args.next() orelse {
        std.debug.print("usage: waygen-scanner <input.xml> <output.zig>\n", .{});
        return error.MissingArgs;
    };

    // Read input XML
    const in_rc = linux.open(in_path.ptr, .{ .ACCMODE = .RDONLY }, 0);
    const in_fd: i32 = @intCast(@as(isize, @bitCast(in_rc)));
    if (in_fd < 0) return error.OpenFailed;
    defer _ = linux.close(in_fd);

    var xml_buf: [1024 * 1024]u8 = undefined;
    var xml_len: usize = 0;
    while (true) {
        const rc: isize = @bitCast(linux.read(in_fd, xml_buf[xml_len..].ptr, xml_buf[xml_len..].len));
        if (rc <= 0) break;
        xml_len += @intCast(rc);
    }
    const xml = xml_buf[0..xml_len];

    // Output
    var out: Out = .{};
    out.w("// Auto-generated by waygen-scanner — do not edit\n\n");

    // Parse state
    var iface: Iface = .{};
    var in_iface = false;
    var in_enum = false;
    var cur_enum: u8 = 0;
    var in_request = false;
    var in_event = false;

    var pos: usize = 0;
    while (pos < xml.len) {
        // Find next '<'
        const lt = std.mem.indexOfScalar(u8, xml[pos..], '<') orelse break;
        pos += lt + 1;
        if (pos >= xml.len) break;

        // Skip comments
        if (pos + 2 < xml.len and xml[pos] == '!' and xml[pos + 1] == '-' and xml[pos + 2] == '-') {
            const end = std.mem.indexOf(u8, xml[pos..], "-->") orelse break;
            pos += end + 3;
            continue;
        }
        // Skip PIs
        if (xml[pos] == '?') {
            const end = std.mem.indexOf(u8, xml[pos..], "?>") orelse break;
            pos += end + 2;
            continue;
        }
        // Skip <!
        if (xml[pos] == '!') {
            const end = std.mem.indexOfScalar(u8, xml[pos..], '>') orelse break;
            pos += end + 1;
            continue;
        }

        // Closing tag
        if (xml[pos] == '/') {
            pos += 1;
            const gt = std.mem.indexOfScalar(u8, xml[pos..], '>') orelse break;
            const close = tagName(xml[pos..][0..gt]);
            pos += gt + 1;

            if (std.mem.eql(u8, close, "interface")) {
                if (in_iface) emitIface(&out, &iface);
                in_iface = false;
            } else if (std.mem.eql(u8, close, "enum")) {
                in_enum = false;
            } else if (std.mem.eql(u8, close, "request")) {
                in_request = false;
            } else if (std.mem.eql(u8, close, "event")) {
                in_event = false;
            }
            continue;
        }

        // Opening / self-closing tag
        const gt = std.mem.indexOfScalar(u8, xml[pos..], '>') orelse break;
        const full = xml[pos..][0..gt];
        const self_closing = gt > 0 and xml[pos + gt - 1] == '/';
        const content = if (self_closing) full[0 .. full.len - 1] else full;
        pos += gt + 1;

        const tname = tagName(content);

        if (std.mem.eql(u8, tname, "interface")) {
            const iname = getAttr(content, "name") orelse continue;
            const ver = getAttr(content, "version") orelse "1";
            iface = .{ .name = iname, .version = ver };
            in_iface = true;
        } else if (std.mem.eql(u8, tname, "request") and in_iface) {
            const rname = getAttr(content, "name") orelse continue;
            iface.reqs[iface.req_count] = .{ .name = rname };
            iface.req_count += 1;
            in_request = !self_closing;
        } else if (std.mem.eql(u8, tname, "event") and in_iface) {
            const ename = getAttr(content, "name") orelse continue;
            iface.evts[iface.evt_count] = .{ .name = ename };
            iface.evt_count += 1;
            in_event = !self_closing;
        } else if (std.mem.eql(u8, tname, "enum") and in_iface) {
            const enname = getAttr(content, "name") orelse continue;
            cur_enum = iface.enum_count;
            iface.enums[cur_enum] = .{ .name = enname };
            iface.enum_count += 1;
            in_enum = !self_closing;
        } else if (std.mem.eql(u8, tname, "entry") and in_enum) {
            const ent_name = getAttr(content, "name") orelse continue;
            const ent_val = getAttr(content, "value") orelse continue;
            const ec = iface.enums[cur_enum].entry_count;
            iface.enums[cur_enum].entries[ec] = .{ .name = ent_name, .value = ent_val };
            iface.enums[cur_enum].entry_count += 1;
        }

        // Self-closing enum
        if (self_closing and std.mem.eql(u8, tname, "enum")) {
            in_enum = false;
        }
    }

    // Flush last interface if XML didn't close properly
    if (in_iface) emitIface(&out, &iface);

    // Write output
    const out_rc = linux.open(out_path.ptr, .{ .ACCMODE = .WRONLY, .CREAT = true, .TRUNC = true }, 0o644);
    const out_fd: i32 = @intCast(@as(isize, @bitCast(out_rc)));
    if (out_fd < 0) return error.OutputFailed;
    defer _ = linux.close(out_fd);

    sysWrite(out_fd, out.slice());
}
