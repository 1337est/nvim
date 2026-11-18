const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const all_tests = b.step("test", "Run all project tests");

    // -------------------------------------------------------------------
    // Programs
    // -------------------------------------------------------------------

    // 3dbg
    _ = addProgram(b, all_tests, "3dbg", .{
        .root_source_file = b.path("src/3dbg.zig"),
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });

    // clift
    _ = addProgram(b, all_tests, "clift", .{
        .root_source_file = b.path("src/clift.zig"),
        .target = target,
        .optimize = optimize,
    });

    // doop
    const doop = addProgram(b, all_tests, "doop", .{
        .root_source_file = b.path("src/doop.zig"),
        .target = target,
        .optimize = optimize,
    });
    if (target.result.os.tag == .windows) {
        doop.linkSystemLibrary("user32", .{ .use_pkg_config = .no });
        doop.linkSystemLibrary("kernel32", .{ .use_pkg_config = .no });
    }

    // nostrum
    const nostrum = addProgram(b, all_tests, "nostrum", .{
        .root_source_file = b.path("src/nostrum.zig"),
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });
    nostrum.linkSystemLibrary("sqlite3", .{ .use_pkg_config = .no });

    // TODO: Finish the rest of this later by adding it
    // rhei
    _ = addProgram(b, all_tests, "rhei", .{
        .root_source_file = b.path("src/rhei.zig"),
        .target = target,
        .optimize = optimize,
    });

    // TODO: Finish the rest of this later by adding it
    // wagon
    _ = addProgram(b, all_tests, "wagon", .{
        .root_source_file = b.path("src/wagon.zig"),
        .target = target,
        .optimize = optimize,
    });

    // view
    _ = addProgram(b, all_tests, "view", .{
        .root_source_file = b.path("src/view.zig"),
        .target = target,
        .optimize = optimize,
    });

    // zwe
    _ = addProgram(b, all_tests, "zwe", .{
        .root_source_file = b.path("src/zwe.zig"),
        .target = target,
        .optimize = optimize,
    });
    // Generate ZWE configuration and Neovim integration files
    const zwe_generator = b.addExecutable(.{
        .name = "zwe-generator",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/zwe.zig"),
            .target = b.graph.host,
            .optimize = optimize,
        }),
    });
    inline for (.{
        .{ "--print-nvim-lua", "zwe.lua", "share/zwe/nvim/lua/zwe.lua" },
        .{ "--print-nvim-lsp", "zls.lua", "share/zwe/nvim/lsp/zls.lua" },
        .{ "--print-config", "config.zon", "share/zwe/config.zon" },
    }) |artifact| {
        const run = b.addRunArtifact(zwe_generator);
        run.addArg(artifact[0]);
        const output = run.captureStdOut(.{
            .basename = artifact[1],
        });
        b.getInstallStep().dependOn(
            &b.addInstallFile(output, artifact[2]).step,
        );
    }

    // template
    _ = addProgram(b, all_tests, "template", .{
        .root_source_file = b.path("src/template.zig"),
        .target = target,
        .optimize = optimize,
    });

    // udeploy
    _ = addProgram(b, all_tests, "udeploy", .{
        .root_source_file = b.path("src/udeploy.zig"),
        .target = target,
        .optimize = optimize,
    });

    // -------------------------------------------------------------------
    // Libraries
    // -------------------------------------------------------------------

    // systemd
    _ = addLibrary(b, all_tests, "systemd", .{
        .root_source_file = b.path("lib/systemd.zig"),
        .target = target,
        .optimize = optimize,
    });

    // ramen
    _ = addLibrary(b, all_tests, "ramen", .{
        .root_source_file = b.path("lib/ramen.zig"),
        .target = target,
        .optimize = optimize,
    });

    // sockman
    _ = addLibrary(b, all_tests, "sockman", .{
        .root_source_file = b.path("lib/sockman.zig"),
        .target = target,
        .optimize = optimize,
    });
}

// -----------------------------------------------------------------------------
// Generic project functions
// -----------------------------------------------------------------------------

// src/project.zig files that serve as runnable executables
fn addProgram(
    b: *std.Build,
    all_tests: *std.Build.Step,
    name: []const u8,
    options: std.Build.Module.CreateOptions,
) *std.Build.Module {
    const mod = b.createModule(options);

    // Test: Compile -> Run
    const compile_tests = b.addTest(.{
        .name = b.fmt("{s}_test", .{name}),
        .root_module = mod,
    });

    const run_tests = b.addRunArtifact(compile_tests);
    run_tests.setCwd(b.path("."));
    run_tests.setEnvironmentVariable("ZIG_EXE", b.graph.zig_exe);
    run_tests.has_side_effects = true;

    const test_step = b.step(
        b.fmt("test-{s}", .{name}),
        b.fmt("Run {s} tests", .{name}),
    );
    test_step.dependOn(&run_tests.step);
    all_tests.dependOn(test_step);

    // Executable: Test -> Compile
    const compile_exe = b.addExecutable(.{
        .name = name,
        .root_module = mod,
    });
    compile_exe.step.dependOn(test_step);

    const build_step = b.step(name, b.fmt("Build {s}", .{name}));
    build_step.dependOn(&compile_exe.step);

    // Install: Compile -> Install
    const install_exe = b.addInstallArtifact(compile_exe, .{});
    b.getInstallStep().dependOn(&install_exe.step);

    // Run: Install -> Run
    const run_exe = b.addRunArtifact(compile_exe);
    run_exe.setCwd(b.path("."));
    run_exe.addPassthruArgs();
    run_exe.step.dependOn(&install_exe.step);

    const run_step = b.step(
        b.fmt("run-{s}", .{name}),
        b.fmt("Run {s} locally", .{name}),
    );
    run_step.dependOn(&run_exe.step);

    return mod;
}

// lib/project.zig files that serve as libraries
fn addLibrary(
    b: *std.Build,
    all_tests: *std.Build.Step,
    name: []const u8,
    options: std.Build.Module.CreateOptions,
) *std.Build.Module {
    const mod = b.addModule(name, options);

    // Test: Compile -> Run
    const compile_tests = b.addTest(.{
        .name = b.fmt("{s}_test", .{name}),
        .root_module = mod,
    });

    const run_tests = b.addRunArtifact(compile_tests);

    const test_step = b.step(
        b.fmt("test-{s}", .{name}),
        b.fmt("Run {s} tests", .{name}),
    );
    test_step.dependOn(&run_tests.step);
    all_tests.dependOn(test_step);

    return mod;
}
