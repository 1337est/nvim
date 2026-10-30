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

    // Always run the generator on the build host, including when cross-compiling.
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
}
