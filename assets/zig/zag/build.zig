const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const all_tests = b.step("test", "Run all project tests");

    // -------------------------------------------------------------------
    // Programs
    // -------------------------------------------------------------------

    // 3dbg
    const dbg_mod = exeMod(b, all_tests, "3dbg", .{
        .root_source_file = b.path("src/3dbg.zig"),
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });
    const dbg = exeCompile(b, "3dbg", dbg_mod);
    const dbg_install = exeInstall(b, dbg);
    exeRun(b, dbg, dbg_install);

    // clift
    const clift_mod = exeMod(b, all_tests, "clift", .{
        .root_source_file = b.path("src/clift.zig"),
        .target = target,
        .optimize = optimize,
    });
    const clift = exeCompile(b, "clift", clift_mod);
    const clift_install = exeInstall(b, clift);
    exeRun(b, clift, clift_install);

    // doop
    const doop_mod = exeMod(b, all_tests, "doop", .{
        .root_source_file = b.path("src/doop.zig"),
        .target = target,
        .optimize = optimize,
    });
    if (target.result.os.tag == .windows) {
        doop_mod.linkSystemLibrary("user32", .{ .use_pkg_config = .no });
        doop_mod.linkSystemLibrary("kernel32", .{ .use_pkg_config = .no });
    }
    const doop = exeCompile(b, "doop", doop_mod);
    const doop_install = exeInstall(b, doop);
    exeRun(b, doop, doop_install);

    // nostrum
    const nostrum_mod = exeMod(b, all_tests, "nostrum", .{
        .root_source_file = b.path("src/nostrum.zig"),
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });
    nostrum_mod.linkSystemLibrary("sqlite3", .{ .use_pkg_config = .no });
    const nostrum = exeCompile(b, "nostrum", nostrum_mod);
    const nostrum_install = exeInstall(b, nostrum);
    exeRun(b, nostrum, nostrum_install);

    // wagon
    const wagon_mod = exeMod(b, all_tests, "wagon", .{
        .root_source_file = b.path("src/wagon.zig"),
        .target = target,
        .optimize = optimize,
    });
    const wagon = exeCompile(b, "wagon", wagon_mod);
    const wagon_install = exeInstall(b, wagon);
    exeRun(b, wagon, wagon_install);

    // rhei
    const rhei_mod = exeMod(b, all_tests, "rhei", .{
        .root_source_file = b.path("src/rhei.zig"),
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });
    rhei_mod.linkSystemLibrary("xkbcommon", .{});

    // Reuse the compiled Wagon executable for wayland protocol generation.
    inline for (.{
        .{ "wayland", "wayland" },
        .{ "wayland", "ext-idle-notify-v1" },
        .{ "wlr", "wlr-layer-shell-unstable-v1" },
        .{ "river", "river-window-management-v1" },
        .{ "river", "river-xkb-bindings-v1" },
    }) |wayland_protocol| {
        const wagon_run = b.addRunArtifact(wagon);
        wagon_run.addFileArg(b.path("src/rhei/protocol/" ++ wayland_protocol[0] ++ "/" ++ wayland_protocol[1] ++ ".xml"));
        const wagon_output = wagon_run.addOutputFileArg(wayland_protocol[1] ++ ".zig");
        rhei_mod.addImport(wayland_protocol[1], b.createModule(.{ .root_source_file = wagon_output }));
    }

    const rhei = exeCompile(b, "rhei", rhei_mod);
    const rhei_install = exeInstall(b, rhei);
    exeRun(b, rhei, rhei_install);

    // view
    const view_mod = exeMod(b, all_tests, "view", .{
        .root_source_file = b.path("src/view.zig"),
        .target = target,
        .optimize = optimize,
    });
    const view = exeCompile(b, "view", view_mod);
    const view_install = exeInstall(b, view);
    exeRun(b, view, view_install);

    // zwe
    const zwe_mod = exeMod(b, all_tests, "zwe", .{
        .root_source_file = b.path("src/zwe.zig"),
        .target = target,
        .optimize = optimize,
    });
    const zwe = exeCompile(b, "zwe", zwe_mod);
    const zwe_install = exeInstall(b, zwe);
    exeRun(b, zwe, zwe_install);

    // Reuse the compiled ZWE executable for configuration and Neovim files.
    inline for (.{
        .{ "--print-nvim-lua", "zwe.lua", "share/zwe/nvim/lua/zwe.lua" },
        .{ "--print-nvim-lsp", "zls.lua", "share/zwe/nvim/lsp/zls.lua" },
        .{ "--print-config", "config.zon", "share/zwe/config.zon" },
    }) |zwe_arg| {
        const zwe_run = b.addRunArtifact(zwe);
        zwe_run.addArg(zwe_arg[0]);
        const zwe_output = zwe_run.captureStdOut(.{
            .basename = zwe_arg[1],
        });
        b.getInstallStep().dependOn(
            &b.addInstallFile(zwe_output, zwe_arg[2]).step,
        );
    }

    // template
    const template_mod = exeMod(b, all_tests, "template", .{
        .root_source_file = b.path("src/template.zig"),
        .target = target,
        .optimize = optimize,
    });
    const template = exeCompile(b, "template", template_mod);
    const template_install = exeInstall(b, template);
    exeRun(b, template, template_install);

    // udeploy
    const udeploy_mod = exeMod(b, all_tests, "udeploy", .{
        .root_source_file = b.path("src/udeploy.zig"),
        .target = target,
        .optimize = optimize,
    });
    const udeploy = exeCompile(b, "udeploy", udeploy_mod);
    const udeploy_install = exeInstall(b, udeploy);
    exeRun(b, udeploy, udeploy_install);

    // -------------------------------------------------------------------
    // Libraries
    // -------------------------------------------------------------------

    // systemd
    _ = libMod(b, all_tests, "systemd", .{
        .root_source_file = b.path("lib/systemd.zig"),
        .target = target,
        .optimize = optimize,
    });

    // ramen
    _ = libMod(b, all_tests, "ramen", .{
        .root_source_file = b.path("lib/ramen.zig"),
        .target = target,
        .optimize = optimize,
    });

    // sockman
    _ = libMod(b, all_tests, "sockman", .{
        .root_source_file = b.path("lib/sockman.zig"),
        .target = target,
        .optimize = optimize,
    });
}

// -----------------------------------------------------------------------------
// Generic project functions
// -----------------------------------------------------------------------------

const Project = struct {
    b: *std.Build,
    all_tests: *std.Build.Step, // To add to the top level test step
    name: []const u8, // executable, project, module, etc, name
    module: ?*std.Build.Module = null, // CreateOptions live here
    test_step: ?*std.Build.Step = null,
    executable: ?*std.Build.Step.Compile = null,
    install_artifact: ?*std.Build.Step.InstallArtifact = null,
    runner: ?*std.Build.Step.Run = null,
};

// 1. Create an executable module and its compile-and-run test steps.
fn exeMod(
    b: *std.Build,
    all_tests: *std.Build.Step,
    name: []const u8,
    options: std.Build.Module.CreateOptions,
) *std.Build.Module {
    const mod = b.createModule(options);

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

    return mod;
}

// 2. Test -> Compile. Reuse the test step created by exeMod.
fn exeCompile(
    b: *std.Build,
    name: []const u8,
    mod: *std.Build.Module,
) *std.Build.Step.Compile {
    const compile_exe = b.addExecutable(.{
        .name = name,
        .root_module = mod,
    });

    const test_step = b.top_level_steps.get(b.fmt("test-{s}", .{name})) orelse
        @panic("exeMod must be called with the same name before exeCompile");
    compile_exe.step.dependOn(&test_step.step);

    const build_step = b.step(name, b.fmt("Build {s}", .{name}));
    build_step.dependOn(&compile_exe.step);

    return compile_exe;
}

// 3. Compile -> Install.
fn exeInstall(
    b: *std.Build,
    compile_exe: *std.Build.Step.Compile,
) *std.Build.Step.InstallArtifact {
    const install_exe = b.addInstallArtifact(compile_exe, .{});
    b.getInstallStep().dependOn(&install_exe.step);
    return install_exe;
}

// 4. Install -> Run.
fn exeRun(
    b: *std.Build,
    compile_exe: *std.Build.Step.Compile,
    install_exe: *std.Build.Step.InstallArtifact,
) void {
    const run_exe = b.addRunArtifact(compile_exe);
    run_exe.setCwd(b.path("."));
    run_exe.addPassthruArgs();
    run_exe.step.dependOn(&install_exe.step);

    const run_step = b.step(
        b.fmt("run-{s}", .{compile_exe.name}),
        b.fmt("Run {s} locally", .{compile_exe.name}),
    );
    run_step.dependOn(&run_exe.step);
}

// 1. lib/project.zig files that serve as libraries
fn libMod(
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
