const std = @import("std");
const builtin = @import("builtin");
const package = @import("build.zig.zon");

const artifact_name = "example";
const root_source_file = "src/main.zig";
const compress_packages = false;
const package_files: []const []const u8 = &.{"README.md"};
const package_directories: []const []const u8 = &.{};

// TODO: Add local here
const InstallScope = enum { user, system };

comptime {
    const minimum = std.SemanticVersion.parse(package.minimum_zig_version) catch
        @compileError("Invalid minimum_zig_version in build.zig.zon");
    if (builtin.zig_version.order(minimum) == .lt)
        @compileError("Use Zig " ++ package.minimum_zig_version ++ " or newer");
}

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const release_optimize = b.option(std.lang.Optimize, "release-optimize", "Optimization used for release packages") orelse .fast;
    const versioned = b.option(bool, "versioned", "Install into a project- and version-specific directory") orelse false;
    const version = try releaseVersion(b);

    const exe = try addExecutable(b, target, optimize);
    addLocalInstallation(b, exe, versioned);
    try addScopedInstallation(b, exe, .user, versioned);
    try addScopedInstallation(b, exe, .system, versioned);
    b.step("check", "Compile without installing or running").dependOn(&exe.step);

    const run = b.addRunArtifact(exe);
    run.step.dependOn(b.getInstallStep());
    run.setCwd(b.path(""));
    run.addPassthruArgs();
    b.step("run", "Build, install, and run this application").dependOn(&run.step);

    const test_step = addTests(b, optimize);
    const assets = try addRuntimeAssets(b);
    try addRelease(b, target, release_optimize, version, versioned, assets, test_step);
}

fn addLocalInstallation(b: *std.Build, exe: *std.Build.Step.Compile, versioned: bool) void {
    if (versioned) {
        const install = b.addInstallArtifact(exe, .{
            .dest_dir = .{ .override = .{ .custom = b.fmt("{s}/bin", .{package.version}) } },
        });
        b.getInstallStep().dependOn(&install.step);
    } else {
        b.installArtifact(exe);
    }

    const destination = if (versioned)
        b.fmt("zig-out/{s}/bin/{s}", .{ package.version, exe.out_filename })
    else
        b.fmt("zig-out/bin/{s}", .{exe.out_filename});
    const uninstall = b.addSystemCommand(&.{ "rm", "-f", "--", destination });
    uninstall.setCwd(b.path(""));
    b.step("uninstall-local", "Remove only this project's local executable").dependOn(&uninstall.step);
}

fn addScopedInstallation(b: *std.Build, exe: *std.Build.Step.Compile, scope: InstallScope, versioned: bool) !void {
    const base = switch (scope) {
        .user => b.fmt("{s}/.local", .{b.graph.environ_map.get("HOME") orelse return error.HomeNotSet}),
        .system => "/usr/local",
    };
    const prefix = if (versioned)
        b.fmt("{s}/zig-out/{s}/{s}", .{ base, artifact_name, package.version })
    else
        base;
    const destination = b.fmt("{s}/bin/{s}", .{ prefix, exe.out_filename });
    const scope_name = @tagName(scope);

    const install = b.addSystemCommand(&.{ "install", "-D", "-m", "0755", "--" });
    install.addFileArg(exe.getEmittedBin());
    install.addArg(destination);
    b.step(b.fmt("install-{s}", .{scope_name}), b.fmt("Install for {s}", .{scope_name})).dependOn(&install.step);

    const uninstall = b.addSystemCommand(&.{ "rm", "-f", "--", destination });
    b.step(b.fmt("uninstall-{s}", .{scope_name}), b.fmt("Uninstall for {s}", .{scope_name})).dependOn(&uninstall.step);
}

fn createModule(b: *std.Build, target: std.Build.ResolvedTarget, optimize: std.lang.Optimize) *std.Build.Module {
    return b.createModule(.{
        .root_source_file = b.path(root_source_file),
        .target = target,
        .optimize = optimize,
    });
}

fn addExecutable(b: *std.Build, target: std.Build.ResolvedTarget, optimize: std.lang.Optimize) !*std.Build.Step.Compile {
    return b.addExecutable(.{
        .name = artifact_name,
        .version = try std.SemanticVersion.parse(package.version),
        .root_module = createModule(b, target, optimize),
    });
}

fn addTests(b: *std.Build, optimize: std.lang.Optimize) *std.Build.Step {
    const tests = b.addTest(.{
        .name = artifact_name ++ "-tests",
        .root_module = createModule(b, b.graph.host, optimize),
    });
    const run_tests = b.addRunArtifact(tests);
    const test_step = b.step("test", "Build and run this project's tests on the host");
    test_step.dependOn(&run_tests.step);
    return test_step;
}

fn addRuntimeAssets(b: *std.Build) !std.Build.LazyPath {
    const assets = b.addWriteFiles();
    _ = assets.addCopyFile(b.path("build.zig.zon"), "build.zig.zon");
    for (package_files) |path| {
        if (!safePath(path)) return error.InvalidAssetPath;
        _ = assets.addCopyFile(b.path(path), path);
    }
    for (package_directories) |path| {
        if (!safePath(path)) return error.InvalidAssetPath;
        _ = assets.addCopyDirectory(b.path(path), path, .{});
    }
    b.step("runtime-assets", "Stage this project's package assets in the build cache").dependOn(&assets.step);
    return assets.getDirectory();
}

fn addRelease(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    optimize: std.lang.Optimize,
    version: []const u8,
    versioned: bool,
    assets: std.Build.LazyPath,
    test_step: *std.Build.Step,
) !void {
    const tool = b.addExecutable(.{
        .name = artifact_name ++ "-package-tool",
        .root_module = b.createModule(.{
            .root_source_file = b.path("build.zig"),
            .target = b.graph.host,
            .optimize = .safe,
        }),
    });
    const release_exe = try addExecutable(b, target, optimize);
    const target_name = b.fmt("{s}-{s}-{s}", .{
        @tagName(target.result.cpu.arch),
        @tagName(target.result.os.tag),
        @tagName(target.result.abi),
    });
    const archive = addPackage(b, tool, release_exe, assets, test_step, version, versioned, target_name);
    b.step("package", "Build a release package for the selected target").dependOn(archive);
}

fn releaseVersion(b: *std.Build) ![]const u8 {
    const tag = b.option([]const u8, "release-tag", "Require v<package version>") orelse "";
    const revision = b.option([]const u8, "revision", "Hexadecimal development revision") orelse "";
    if (!safeName(artifact_name) or !safeName(package.version)) return error.InvalidPackageName;
    if (tag.len != 0 and revision.len != 0) return error.ConflictingPackageOptions;
    if (tag.len != 0 and !std.mem.eql(u8, tag, "v" ++ package.version)) return error.ReleaseTagMismatch;

    var version = try std.SemanticVersion.parse(package.version);
    if (revision.len != 0) {
        if (revision.len > 64) return error.InvalidPackageRevision;
        for (revision) |byte| {
            if (!std.ascii.isHex(byte)) return error.InvalidPackageRevision;
        }
        version.pre = if (version.pre) |pre|
            b.fmt("{s}.dev.{s}", .{ pre, revision })
        else
            b.fmt("dev.{s}", .{revision});
    }
    return std.fmt.allocPrint(b.allocator, "{f}", .{version});
}

fn addPackage(
    b: *std.Build,
    tool: *std.Build.Step.Compile,
    executable: *std.Build.Step.Compile,
    assets: std.Build.LazyPath,
    test_step: *std.Build.Step,
    version: []const u8,
    versioned: bool,
    target_name: []const u8,
) *std.Build.Step {
    const name = b.fmt("{s}-{s}-{s}", .{ artifact_name, version, target_name });
    const staged = b.addWriteFiles();
    _ = staged.addCopyDirectory(assets, "", .{});
    _ = staged.addCopyFile(executable.getEmittedBin(), b.fmt("bin/{s}", .{executable.out_filename}));
    _ = staged.add("release.env", b.fmt(
        "PACKAGE_NAME={s}\nPROJECT_VERSION={s}\nPACKAGE_VERSION={s}\nTARGET={s}\n",
        .{ artifact_name, package.version, version, target_name },
    ));

    const archive = b.addRunArtifact(tool);
    archive.addArg(name);
    archive.addDirectoryArg(staged.getDirectory());
    const tar = archive.addOutputFileArg(b.fmt("{s}.tar", .{name}));
    archive.step.dependOn(test_step);

    const output = if (compress_packages) blk: {
        const compress = b.addSystemCommand(&.{ "xz", "--compress", "--stdout", "--threads=1", "--check=crc64", "-6", "--" });
        compress.removeEnvironmentVariable("XZ_DEFAULTS");
        compress.removeEnvironmentVariable("XZ_OPT");
        compress.addFileArg(tar);
        break :blk compress.captureStdOut(.{ .basename = b.fmt("{s}.tar.xz", .{name}) });
    } else tar;
    const suffix = if (compress_packages) ".tar.xz" else ".tar";
    const subdir = if (versioned) b.fmt("{s}/release", .{package.version}) else "release";
    const install = b.addInstallFile(output, b.fmt("{s}/{s}{s}", .{ subdir, name, suffix }));
    return &install.step;
}

const ArchiveEntry = struct {
    path: []const u8,
    kind: std.Io.File.Kind,
};

fn entryLessThan(_: void, a: ArchiveEntry, b: ArchiveEntry) bool {
    return std.mem.order(u8, a.path, b.path) == .lt;
}

fn safeName(name: []const u8) bool {
    if (name.len == 0 or name[0] == '.') return false;
    for (name) |byte| {
        if (!std.ascii.isAlphanumeric(byte) and byte != '-' and byte != '_' and byte != '.' and byte != '+')
            return false;
    }
    return true;
}

fn safePath(path: []const u8) bool {
    if (path.len == 0 or std.fs.path.isAbsolute(path) or std.mem.indexOfAny(u8, path, "\\\x00") != null)
        return false;
    var parts = std.mem.splitScalar(u8, path, '/');
    while (parts.next()) |part| {
        if (part.len == 0 or std.mem.eql(u8, part, ".") or std.mem.eql(u8, part, ".."))
            return false;
    }
    return true;
}

pub fn main(init: std.process.Init) !void {
    const args = try init.minimal.args.toSlice(init.arena.allocator());
    if (args.len != 4 or !safeName(args[1])) return error.InvalidPackageArguments;

    const cwd = std.Io.Dir.cwd();
    const input = try cwd.openDir(init.io, args[2], .{ .iterate = true });
    defer input.close(init.io);

    var entries: std.ArrayList(ArchiveEntry) = .empty;
    defer {
        for (entries.items) |entry| init.gpa.free(entry.path);
        entries.deinit(init.gpa);
    }
    {
        var walker = try input.walk(init.gpa);
        defer {
            while (walker.inner.stack.items.len != 0) walker.leave(init.io);
            walker.deinit();
        }
        while (try walker.next(init.io)) |entry| {
            if (entry.kind != .file and entry.kind != .directory) return error.UnsupportedArchiveEntry;
            const path = try init.gpa.dupe(u8, entry.path);
            errdefer init.gpa.free(path);
            if (builtin.os.tag == .windows) std.mem.replaceScalar(u8, path, '\\', '/');
            if (!safePath(path)) return error.InvalidArchivePath;
            try entries.append(init.gpa, .{ .path = path, .kind = entry.kind });
        }
    }
    std.mem.sort(ArchiveEntry, entries.items, {}, entryLessThan);

    const output = try cwd.createFile(init.io, args[3], .{});
    errdefer cwd.deleteFile(init.io, args[3]) catch {};
    defer output.close(init.io);
    var write_buffer: [64 * 1024]u8 = undefined;
    var writer = output.writer(init.io, &write_buffer);
    var tar: std.tar.Writer = .{ .underlying_writer = &writer.interface };
    try tar.writeDir(args[1], .{ .mode = 0o755, .mtime = 0 });
    tar.prefix = args[1];

    var read_buffer: [64 * 1024]u8 = undefined;
    for (entries.items) |entry| {
        if (entry.kind == .directory) {
            try tar.writeDir(entry.path, .{ .mode = 0o755, .mtime = 0 });
        } else {
            const file = try input.openFile(init.io, entry.path, .{});
            defer file.close(init.io);
            const stat = try file.stat(init.io);
            if (stat.kind != .file) return error.UnsupportedArchiveEntry;
            var reader = file.reader(init.io, &read_buffer);
            try tar.writeFileStream(entry.path, stat.size, &reader.interface, .{
                .mode = if (std.mem.startsWith(u8, entry.path, "bin/")) 0o755 else 0o644,
                .mtime = 0,
            });
        }
    }
    try tar.finishPedantically();
    try writer.interface.flush();
}
