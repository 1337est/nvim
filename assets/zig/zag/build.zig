const std = @import("std");
const Project = @import("ramen").Project;

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const all_tests = b.step("test", "Run all project tests");

    // -------------------------------------------------------------------
    // Ramen
    // -------------------------------------------------------------------

    const ramen = b.dependency("ramen", .{
        .target = target,
        .optimize = optimize,
    });

    // -------------------------------------------------------------------
    // Executables
    // -------------------------------------------------------------------

    // 3dbg
    _ = try Project.init(b, all_tests, "3dbg", .local, .exe, .{
        .root_source_file = b.path("src/3dbg.zig"),
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });

    // doop
    const doop = try Project.init(b, all_tests, "doop", .local, .exe, .{
        .root_source_file = b.path("src/doop.zig"),
        .target = target,
        .optimize = optimize,
    });
    if (target.result.os.tag == .windows) {
        doop.module.linkSystemLibrary("user32", .{ .use_pkg_config = .no });
        doop.module.linkSystemLibrary("kernel32", .{ .use_pkg_config = .no });
    }

    // nostrum
    _ = try Project.init(b, all_tests, "nostrum", .local, .exe, .{
        .root_source_file = b.path("src/nostrum.zig"),
        .target = target,
        .optimize = optimize,
        .link_libc = true,
        .imports = &.{
            .{ .name = "sqlite3", .module = ramen.module("sqlite3") },
        },
    });

    // wagon
    const wagon = try Project.init(b, all_tests, "wagon", .local, .exe, .{
        .root_source_file = b.path("src/wagon.zig"),
        .target = target,
        .optimize = optimize,
    });

    // rhei
    const rhei = try Project.init(b, all_tests, "rhei", .local, .exe, .{
        .root_source_file = b.path("src/rhei.zig"),
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });
    rhei.module.linkSystemLibrary("xkbcommon", .{});

    // Reuse the compiled Wagon executable for Wayland protocol generation.
    inline for (.{
        .{ "wayland", "wayland" },
        .{ "wayland", "ext-idle-notify-v1" },
        .{ "wlr", "wlr-layer-shell-unstable-v1" },
        .{ "river", "river-window-management-v1" },
        .{ "river", "river-xkb-bindings-v1" },
    }) |wayland_protocol| {
        const wagon_run = b.addRunArtifact(wagon.artifact);
        wagon_run.addFileArg(b.path(b.fmt(
            "src/rhei/protocol/{s}/{s}.xml",
            .{ wayland_protocol[0], wayland_protocol[1] },
        )));
        const wagon_output = wagon_run.addOutputFileArg(
            wayland_protocol[1] ++ ".zig",
        );
        rhei.module.addImport(
            wayland_protocol[1],
            b.createModule(.{ .root_source_file = wagon_output }),
        );
    }

    // view
    _ = try Project.init(b, all_tests, "view", .local, .exe, .{
        .root_source_file = b.path("src/view.zig"),
        .target = target,
        .optimize = optimize,
    });

    // zwe
    const zwe = try Project.init(b, all_tests, "zwe", .local, .exe, .{
        .root_source_file = b.path("src/zwe.zig"),
        .target = target,
        .optimize = optimize,
    });

    // Reuse the compiled ZWE executable for configuration and Neovim files.
    inline for (.{
        .{ "--print-nvim-lua", "zwe.lua", "share/zwe/nvim/lua/zwe.lua" },
        .{ "--print-nvim-lsp", "zls.lua", "share/zwe/nvim/lsp/zls.lua" },
        .{ "--print-config", "config.zon", "share/zwe/config.zon" },
    }) |zwe_arg| {
        const zwe_run = b.addRunArtifact(zwe.artifact);
        zwe_run.addArg(zwe_arg[0]);
        const zwe_output = zwe_run.captureStdOut(.{
            .basename = zwe_arg[1],
        });
        zwe.install_step.dependOn(
            &b.addInstallFile(zwe_output, zwe_arg[2]).step,
        );
    }

    // template
    _ = try Project.init(b, all_tests, "template", .local, .exe, .{
        .root_source_file = b.path("src/template.zig"),
        .target = target,
        .optimize = optimize,
    });

    // udeploy
    _ = try Project.init(b, all_tests, "udeploy", .local, .exe, .{
        .root_source_file = b.path("src/udeploy.zig"),
        .target = target,
        .optimize = optimize,
    });
}
