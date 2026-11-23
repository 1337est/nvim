const std = @import("std");
const Project = @import("lib/Project.zig");

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const all_tests = b.step("test", "Run all project tests");

    // -------------------------------------------------------------------
    // Libraries
    // -------------------------------------------------------------------

    // ramen
    _ = try Project.init(b, all_tests, "ramen", .lib, .{
        .root_source_file = b.path("lib/ramen.zig"),
        .target = target,
        .optimize = optimize,
    });

    // sockman
    _ = try Project.init(b, all_tests, "sockman", .lib, .{
        .root_source_file = b.path("lib/sockman.zig"),
        .target = target,
        .optimize = optimize,
    });

    // clift
    _ = try Project.init(b, all_tests, "clift", .lib, .{
        .root_source_file = b.path("lib/clift.zig"),
        .target = target,
        .optimize = optimize,
    });

    // sqlite
    const sqlite = try Project.init(b, all_tests, "sqlite3", .{
        .c_src_archive = .{
            .path = "lib/sqlite-amalgamation-3540100.zip",
            .source_file = "sqlite-amalgamation-3540100/sqlite3.c",
            .sha3_256 = "92281c86e2957f9b9305890f9ac04204caa7b677cc868dc326d942689df28e30",
        },
    }, .{
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });

    // -------------------------------------------------------------------
    // Executables
    // -------------------------------------------------------------------

    // 3dbg
    _ = try Project.init(b, all_tests, "3dbg", .exe, .{
        .root_source_file = b.path("src/3dbg.zig"),
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });

    // doop
    const doop = try Project.init(b, all_tests, "doop", .exe, .{
        .root_source_file = b.path("src/doop.zig"),
        .target = target,
        .optimize = optimize,
    });
    if (target.result.os.tag == .windows) {
        doop.module.linkSystemLibrary("user32", .{ .use_pkg_config = .no });
        doop.module.linkSystemLibrary("kernel32", .{ .use_pkg_config = .no });
    }

    // nostrum
    const nostrum = try Project.init(b, all_tests, "nostrum", .exe, .{
        .root_source_file = b.path("src/nostrum.zig"),
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });
    nostrum.module.linkLibrary(sqlite.artifact);

    // wagon
    const wagon = try Project.init(b, all_tests, "wagon", .exe, .{
        .root_source_file = b.path("src/wagon.zig"),
        .target = target,
        .optimize = optimize,
    });

    // rhei
    const rhei = try Project.init(b, all_tests, "rhei", .exe, .{
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
    _ = try Project.init(b, all_tests, "view", .exe, .{
        .root_source_file = b.path("src/view.zig"),
        .target = target,
        .optimize = optimize,
    });

    // zwe
    const zwe = try Project.init(b, all_tests, "zwe", .exe, .{
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
    _ = try Project.init(b, all_tests, "template", .exe, .{
        .root_source_file = b.path("src/template.zig"),
        .target = target,
        .optimize = optimize,
    });

    // udeploy
    _ = try Project.init(b, all_tests, "udeploy", .exe, .{
        .root_source_file = b.path("src/udeploy.zig"),
        .target = target,
        .optimize = optimize,
    });
}
