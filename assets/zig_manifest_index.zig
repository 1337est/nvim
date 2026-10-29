//! Zig 0.17.0. Read a JSON array of manifest paths from stdin; emit projects/errors.
//! Parses ZON with Zig's own parser. Does not evaluate or execute build.zig.
const std = @import("std");
const Allocator = std.mem.Allocator;
const Zoir = std.zig.Zoir;
const Node = Zoir.Node;

const Project = struct {
    manifest: []const u8,
    dependencies: std.json.Value = .{ .object = .empty },
    minimum_zig_version: ?[]const u8 = null,
};
const Failure = struct { manifest: []const u8, @"error": []const u8 };

pub fn main(init: std.process.Init) u8 {
    run(init) catch |err| {
        std.debug.print("zig_manifest_index: {s}\n", .{@errorName(err)});
        return 1;
    };
    return 0;
}

fn run(init: std.process.Init) !void {
    const arena = init.arena.allocator();
    var input = std.Io.File.stdin().readerStreaming(init.io, &.{});
    const json = try input.interface.allocRemaining(arena, .limited(16 * 1024 * 1024));
    const paths = try std.json.parseFromSliceLeaky([]const []const u8, arena, json, .{});
    var projects: std.ArrayList(Project) = .empty;
    var errors: std.ArrayList(Failure) = .empty;
    for (paths) |path| {
        var detail: ?[]const u8 = null;
        const project = index(init, path, &detail) catch |err| {
            if (err == error.OutOfMemory) return err;
            try errors.append(arena, .{ .manifest = path, .@"error" = detail orelse @errorName(err) });
            continue;
        };
        try projects.append(arena, project);
    }
    var buffer: [8192]u8 = undefined;
    var output = std.Io.File.stdout().writerStreaming(init.io, &buffer);
    try std.json.Stringify.value(.{ .projects = projects.items, .errors = errors.items }, .{
        .emit_null_optional_fields = false,
    }, &output.interface);
    try output.interface.writeByte('\n');
    try output.interface.flush();
}

fn index(init: std.process.Init, path: []const u8, detail: *?[]const u8) !Project {
    if (!std.fs.path.isAbsolute(path)) return error.ExpectedAbsoluteManifestPath;
    var scratch: std.heap.ArenaAllocator = .init(init.gpa);
    defer scratch.deinit();
    const temp = scratch.allocator();
    const arena = init.arena.allocator();
    const source = try std.Io.Dir.cwd().readFileAllocOptions(
        init.io,
        path,
        temp,
        .limited(4 * 1024 * 1024),
        .of(u8),
        0,
    );
    const tree = try std.zig.Ast.parse(temp, source, .{ .mode = .zon });
    const zoir = try std.zig.ZonGen.generate(temp, tree, .{});
    if (zoir.hasCompileErrors()) {
        const problem = zoir.compile_errors[0];
        const token = problem.token.unwrap() orelse tree.nodeMainToken(
            @fromBackingInt(@intCast(problem.node_or_offset)),
        );
        const loc = tree.tokenLocation(0, token);
        const offset = if (problem.token != .none) problem.node_or_offset else 0;
        detail.* = try std.fmt.allocPrint(arena, "{d}:{d}: {s}", .{
            loc.line + 1, loc.column + offset + 1, problem.msg.get(&zoir),
        });
        return error.InvalidZon;
    }

    var project: Project = .{ .manifest = path };
    const root = try fields(Node.Index.root.get(&zoir));
    for (root.names, 0..) |name, i| {
        const value = root.vals.at(@intCast(i)).get(&zoir);
        if (std.mem.eql(u8, name.get(&zoir), "minimum_zig_version")) {
            project.minimum_zig_version = try string(arena, value);
        } else if (std.mem.eql(u8, name.get(&zoir), "dependencies")) {
            const dependencies = try fields(value);
            for (dependencies.names, 0..) |dep_name, j| {
                const dependency = try dependencyValue(arena, &zoir, dependencies.vals.at(@intCast(j)));
                try project.dependencies.object.put(arena, try arena.dupe(u8, dep_name.get(&zoir)), dependency);
            }
        }
    }
    return project;
}

fn fields(node: Node) !@FieldType(Node, "struct_literal") {
    return switch (node) {
        .struct_literal => |value| value,
        .empty_literal => .{ .names = &.{}, .vals = .{ .start = .root, .len = 0 } },
        else => error.ExpectedObject,
    };
}

fn string(arena: Allocator, node: Node) ![]const u8 {
    return switch (node) {
        .string_literal => |value| try arena.dupe(u8, value),
        else => error.ExpectedString,
    };
}

fn dependencyValue(arena: Allocator, zoir: *const Zoir, node: Node.Index) !std.json.Value {
    const object = try fields(node.get(zoir));
    var result: std.json.Value = .{ .object = .empty };
    for (object.names, 0..) |name, i| {
        const key = name.get(zoir);
        const value = object.vals.at(@intCast(i)).get(zoir);
        if (std.mem.eql(u8, key, "url") or std.mem.eql(u8, key, "path") or std.mem.eql(u8, key, "hash")) {
            try result.object.put(arena, try arena.dupe(u8, key), .{ .string = try string(arena, value) });
        } else if (std.mem.eql(u8, key, "lazy")) {
            const lazy = switch (value) {
                .true => true,
                .false => false,
                else => return error.ExpectedBoolean,
            };
            try result.object.put(arena, "lazy", .{ .bool = lazy });
        }
    }
    if (result.object.contains("url") == result.object.contains("path"))
        return error.DependencyMustHaveExactlyOneUrlOrPath;
    return result;
}
