const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const module = b.addModule("zwe", .{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });
    const exe = b.addExecutable(.{ .name = "zwe", .root_module = module });
    b.installArtifact(exe);

    const generator = b.addExecutable(.{
        .name = "zwe-generator",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = b.graph.host,
            .optimize = optimize,
        }),
    });
    inline for (.{
        .{ "--print-nvim-lua", "zwe.lua", "share/zwe/nvim/lua/zwe.lua" },
        .{ "--print-nvim-lsp", "zls.lua", "share/zwe/nvim/lsp/zls.lua" },
        .{ "--print-config", "config.zon", "share/zwe/config.zon" },
    }) |artifact| {
        const run = b.addRunArtifact(generator);
        run.addArg(artifact[0]);
        const output = run.captureStdOut(.{ .basename = artifact[1] });
        b.getInstallStep().dependOn(&b.addInstallFile(output, artifact[2]).step);
    }

    const tests = b.addTest(.{ .root_module = module });
    const run_tests = b.addRunArtifact(tests);
    b.step("test", "Run ZWE regression tests").dependOn(&run_tests.step);
    b.step("check", "Compile ZWE without installing").dependOn(&exe.step);

    const install_user = installUserArtifact(b);
    const uninstall_user = uninstallUserArtifact(b);

    b.step("install-user", "Install to ~/.local with ~/.cache/zig").dependOn(&install_user.step);
    b.step("uninstall-user", "Install to ~/.local with ~/.cache/zig").dependOn(&uninstall_user.step);
}

fn installUserArtifact(b: *std.Build) *std.Build.Step.Run {
    const home = b.graph.environ_map.get("HOME") orelse @panic("HOME not set");
    const cache = b.pathJoin(&.{ home, ".cache", "zig" });
    const prefix = b.pathJoin(&.{ home, ".local" });

    const install = b.addSystemCommand(&.{ b.graph.zig_exe, "build", "install", "--prefix", prefix, "--cache-dir", cache });
    install.setCwd(b.path("."));
    return install;
}

fn uninstallUserArtifact(b: *std.Build) *std.Build.Step.Run {
    const home = b.graph.environ_map.get("HOME") orelse @panic("HOME not set");
    const prefix = b.pathJoin(&.{ home, ".local" });

    const uninstall = b.addSystemCommand(&.{
        "rm",
        "-f",
        b.pathJoin(&.{ prefix, "bin/zwe" }),
        b.pathJoin(&.{ prefix, "share/zwe/nvim/lua/zwe.lua" }),
        b.pathJoin(&.{ prefix, "share/zwe/nvim/lsp/zls.lua" }),
        b.pathJoin(&.{ prefix, "share/zwe/config.zon" }),
    });
    uninstall.has_side_effects = true;
    return uninstall;
}
