const std = @import("std");
const Io = std.Io;
const Path = Io.Dir.path;
const Allocator = std.mem.Allocator;

pub const Defaults = struct {
    zig_exe: []const u8 = "zig",
    lsp_exe: []const u8 = "zls",
};
pub const Workspace = struct {
    name: []const u8,
    path: []const u8,
    zig_exe: ?[]const u8 = null,
    lsp_exe: ?[]const u8 = null,
    trusted: bool = false,
};
pub const Config = struct {
    schema_version: u32 = 1,
    zig_version: ?[]const u8 = null,
    zwe_version: ?[]const u8 = null,
    defaults: Defaults = .{},
    workspaces: []const Workspace = &.{},
};
pub const Record = struct {
    name: ?[]const u8,
    path: []const u8,
    root: []const u8,
    entry: ?[]const u8,
    kind: enum { build, file, directory },
    zig_exe: []const u8,
    lsp_exe: []const u8,
    trusted: bool,
    available: bool,
};
pub const Loaded = struct {
    config_path: []const u8,
    missing: bool,
    defaults: Defaults,
    workspaces: []const Record,
};

fn eql(a: []const u8, b: []const u8) bool { return std.mem.eql(u8, a, b); }
fn cleanString(value: []const u8) bool {
    return value.len != 0 and std.mem.findScalar(u8, value, 0) == null;
}
pub fn validName(name: []const u8) bool {
    if (name.len == 0 or !std.ascii.isAlphabetic(name[0])) return false;
    for (name) |c| if (!std.ascii.isAlphabetic(c) and c != '_') return false;
    return true;
}
pub fn validate(config: Config) !void {
    if (config.workspaces.len > 4096) return error.TooManyWorkspaces;
    if (config.schema_version != 1) return error.UnsupportedConfigSchema;
    if (!cleanString(config.defaults.zig_exe) or !cleanString(config.defaults.lsp_exe)) return error.InvalidDefaultTool;
    for (config.workspaces, 0..) |ws, i| {
        if (!validName(ws.name)) {
            std.log.err("workspace name must start with a letter and contain only letters/underscores: {s}", .{ws.name});
            return error.InvalidWorkspaceName;
        }
        if (!cleanString(ws.path)) return error.InvalidWorkspacePath;
        if (ws.zig_exe) |exe| if (!cleanString(exe)) return error.InvalidWorkspaceTool;
        if (ws.lsp_exe) |exe| if (!cleanString(exe)) return error.InvalidWorkspaceTool;
        for (config.workspaces[0..i]) |previous| if (eql(previous.name, ws.name)) {
            std.log.err("duplicate workspace name: {s}", .{ws.name});
            return error.DuplicateWorkspaceName;
        };
    }
}

fn expand(init: std.process.Init, value: []const u8) ![]const u8 {
    const a = init.arena.allocator();
    if (eql(value, "~") or std.mem.startsWith(u8, value, "~/")) {
        const home = init.environ_map.get("HOME") orelse return error.HomeNotSet;
        if (!Path.isAbsolute(home)) return error.HomeMustBeAbsolute;
        return std.fmt.allocPrint(a, "{s}{s}", .{ home, value[1..] });
    }
    return value;
}
fn absolute(init: std.process.Init, base: []const u8, raw: []const u8) ![]const u8 {
    const a = init.arena.allocator();
    const path = try Path.resolve(a, &.{ base, try expand(init, raw) });
    return Io.Dir.realPathFileAbsoluteAlloc(init.io, path, a) catch |err| switch (err) {
        error.FileNotFound => path,
        else => return err,
    };
}
fn cwd(init: std.process.Init) ![]const u8 {
    return Io.Dir.cwd().realPathFileAlloc(init.io, ".", init.arena.allocator());
}
fn tool(init: std.process.Init, base: []const u8, value: []const u8) ![]const u8 {
    if (std.mem.findScalar(u8, value, '/') != null or eql(value, "~")) return absolute(init, base, value);
    return value;
}
fn fileExists(init: std.process.Init, path: []const u8) bool {
    const file = Io.Dir.openFileAbsolute(init.io, path, .{}) catch return false;
    defer file.close(init.io);
    const stat = file.stat(init.io) catch return false;
    return stat.kind == .file;
}
fn dirExists(init: std.process.Init, path: []const u8) bool {
    const dir = Io.Dir.cwd().openDir(init.io, path, .{}) catch return false;
    dir.close(init.io);
    return true;
}
fn inside(path: []const u8, root: []const u8) bool {
    return eql(path, root) or (eql(root, "/") and Path.isAbsolute(path)) or
        (path.len > root.len and std.mem.startsWith(u8, path, root) and path[root.len] == '/');
}
fn describe(init: std.process.Init, base: []const u8, name: ?[]const u8, raw: []const u8, defaults: Defaults, trusted: bool) !Record {
    const a = init.arena.allocator();
    const path = try absolute(init, base, raw);
    var result: Record = .{
        .name = name, .path = path, .root = path, .entry = null, .kind = .directory,
        .zig_exe = defaults.zig_exe, .lsp_exe = defaults.lsp_exe, .trusted = trusted, .available = false,
    };
    if (eql(Path.basename(path), "build.zig")) {
        result.root = Path.dirname(path) orelse "/";
        result.entry = path;
        result.kind = .build;
        result.available = fileExists(init, path);
    } else if (std.mem.endsWith(u8, path, ".zig") and !dirExists(init, path)) {
        result.root = Path.dirname(path) orelse "/";
        result.entry = path;
        result.kind = .file;
        result.available = fileExists(init, path);
    } else {
        const build = try Path.resolve(a, &.{ path, "build.zig" });
        if (fileExists(init, build)) {
            result.entry = build;
            result.kind = .build;
            result.available = true;
        } else if (fileExists(init, path)) {
            result.root = Path.dirname(path) orelse "/";
        }
    }
    return result;
}
fn defaultPath(init: std.process.Init) ![]const u8 {
    if (init.environ_map.get("XDG_CONFIG_HOME")) |xdg| {
        if (xdg.len != 0 and Path.isAbsolute(xdg)) return Path.resolve(init.arena.allocator(), &.{ xdg, "zwe/config.zon" });
    }
    return absolute(init, try cwd(init), "~/.config/zwe/config.zon");
}
pub fn load(init: std.process.Init, requested: ?[]const u8) !Loaded {
    const a = init.arena.allocator();
    const location = if (requested) |p| try absolute(init, try cwd(init), p) else try defaultPath(init);
    const base = Path.dirname(location) orelse "/";
    const source = Io.Dir.cwd().readFileAllocOptions(init.io, location, a, .limited(1024 * 1024), .of(u8), 0) catch |err| {
        if (err == error.FileNotFound and requested == null) {
            return .{ .config_path = location, .missing = true, .defaults = .{}, .workspaces = &.{} };
        }
        std.log.err("cannot read ZWE configuration {s}: {s}", .{ location, @errorName(err) });
        return err;
    };
    var diagnostics: std.zon.parse.Diagnostics = undefined;
    const config = std.zon.parse.fromSlice(Config, .{
        .gpa = init.gpa, .arena = a, .source = source, .diagnostics = &diagnostics,
    }) catch |err| {
        std.log.err("invalid ZWE configuration {s}: {s}", .{ location, @errorName(err) });
        return err;
    };
    try validate(config);
    const defaults: Defaults = .{
        .zig_exe = try tool(init, base, config.defaults.zig_exe),
        .lsp_exe = try tool(init, base, config.defaults.lsp_exe),
    };
    const records = try a.alloc(Record, config.workspaces.len);
    for (config.workspaces, records, 0..) |ws, *record, i| {
        const tools: Defaults = .{
            .zig_exe = if (ws.zig_exe) |exe| try tool(init, base, exe) else defaults.zig_exe,
            .lsp_exe = if (ws.lsp_exe) |exe| try tool(init, base, exe) else defaults.lsp_exe,
        };
        record.* = try describe(init, base, ws.name, ws.path, tools, ws.trusted);
        for (records[0..i]) |previous| if (eql(previous.path, record.path) or
            (previous.kind != .file and record.kind != .file and eql(previous.root, record.root)))
        {
            std.log.err("workspaces {s} and {s} select the same project", .{ previous.name.?, ws.name });
            return error.DuplicateWorkspacePath;
        };
    }
    return .{ .config_path = location, .missing = false, .defaults = defaults, .workspaces = records };
}

pub fn resolve(init: std.process.Init, loaded: Loaded, raw: []const u8) !Record {
    const a = init.arena.allocator();
    const path = try absolute(init, try cwd(init), raw);
    var selected: ?Record = null;
    for (loaded.workspaces) |ws| {
        const match = if (ws.kind == .build) inside(path, ws.root) else eql(path, ws.path);
        if (match and (selected == null or ws.root.len > selected.?.root.len)) selected = ws;
    }
    if (selected) |ws| return ws;
    // Package copies and generated files belong to their enclosing project.
    var limit = path.len;
    for ([_][]const u8{ "/zig-pkg/", "/.zig-cache/", "/zig-out/" }) |marker| {
        if (std.mem.find(u8, path, marker)) |at| limit = @min(limit, at);
    }
    const probe = path[0..limit];
    var dir = if (dirExists(init, probe)) probe else Path.dirname(probe) orelse "/";
    while (true) {
        const build = try Path.resolve(a, &.{ dir, "build.zig" });
        if (fileExists(init, build)) return describe(init, dir, null, build, loaded.defaults, false);
        const parent = Path.dirname(dir) orelse break;
        if (eql(parent, dir)) break;
        dir = parent;
    }
    return describe(init, try cwd(init), null, path, loaded.defaults, false);
}

pub fn run(init: std.process.Init, command: enum { config, resolve }, args: []const []const u8) !void {
    var requested: ?[]const u8 = null;
    var query: ?[]const u8 = null;
    var from_snapshot = false;
    var i: usize = 0;
    while (i < args.len) : (i += 1) {
        if (eql(args[i], "--config")) {
            i += 1;
            if (i == args.len or requested != null) return error.InvalidArguments;
            requested = args[i];
        } else if (eql(args[i], "--snapshot") and command == .resolve and !from_snapshot) {
            from_snapshot = true;
        } else if (command == .resolve and query == null) query = args[i]
        else return error.InvalidArguments;
    }
    if (from_snapshot and requested != null) return error.InvalidArguments;
    const loaded = if (from_snapshot) blk: {
        var input = Io.File.stdin().readerStreaming(init.io, &.{});
        const bytes = try input.interface.allocRemaining(init.arena.allocator(), .limited(16 * 1024 * 1024));
        break :blk try std.json.parseFromSliceLeaky(Loaded, init.arena.allocator(), bytes, .{});
    } else try load(init, requested);
    var buffer: [8192]u8 = undefined;
    var output = Io.File.stdout().writerStreaming(init.io, &buffer);
    if (command == .config) {
        try std.json.Stringify.value(loaded, .{}, &output.interface);
    } else {
        const path = query orelse return error.MissingWorkspacePath;
        const record = try resolve(init, loaded, path);
        try std.json.Stringify.value(record, .{}, &output.interface);
    }
    try output.interface.writeByte('\n');
    try output.interface.flush();
}
