const std = @import("std");
const builtin = @import("builtin");
const package = @import("build.zig.zon"); // is there a better way to get this?

const artifact_name = "example";
const root_source_file = "src/main.zig";

const InstallScope = enum { local, user, system };

comptime {
    const minimum = std.SemanticVersion.parse(package.minimum_zig_version) catch
        @compileError("Invalid minimum_zig_version in build.zig.zon");
    if (builtin.zig_version.order(minimum) == .lt)
        @compileError("Use Zig " ++ package.minimum_zig_version ++ " or newer");
}

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const scope = b.option(InstallScope, "scope", "Installation scope") orelse .local;
    const versioned = b.option(bool, "versioned", "Install into a project- and version-specific directory") orelse false;

    const exe = try addExecutable(b, target, optimize);

    const tests = b.addTest(.{
        .name = artifact_name ++ "-tests",
        .root_module = createModule(b, b.graph.host, optimize),
    });
    const run_tests = b.addRunArtifact(tests);

    const run = b.addRunArtifact(exe);
    run.step.dependOn(b.getInstallStep());
    run.setCwd(b.path(""));
    run.addPassthruArgs();

    const base = switch (scope) {
        .local => "zig-out",
        .user => b.pathJoin(&.{ b.graph.environ_map.get("HOME") orelse return error.HomeNotSet, ".local" }),
        .system => "/usr/local",
    };
    const prefix = if (versioned)
        b.pathJoin(&.{ base, artifact_name, package.version })
    else
        base;
    const destination = b.pathJoin(&.{ prefix, "bin", exe.out_filename });

    const install = b.addSystemCommand(&.{ "install", "-Dm755", "--" });
    install.addFileArg(exe.getEmittedBin());
    install.addArg(destination);
    install.setCwd(b.path(""));
    install.has_side_effects = true;

    const uninstall = b.addSystemCommand(&.{ "rm", "-f", "--", destination });
    uninstall.setCwd(b.path(""));
    uninstall.has_side_effects = true;

    b.step("check", "Compile without installing or running").dependOn(&exe.step);
    b.step("test", "Build and run this project's tests on the host").dependOn(&run_tests.step);
    b.step("run", "Build, install, and run this application").dependOn(&run.step);
    b.getInstallStep().dependOn(&install.step);
    b.getUninstallStep().dependOn(&uninstall.step);
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
