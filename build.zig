const std = @import("std");

pub fn build(b: *std.Build) void {
    const module = b.addModule("zwe", .{
        .root_source_file = b.path("assets/zwe.zig"),
        .target = b.standardTargetOptions(.{}),
        .optimize = b.standardOptimizeOption(.{}),
    });
    const exe = b.addExecutable(.{ .name = "zwe", .root_module = module });
    b.installArtifact(exe);
    const tests = b.addTest(.{ .root_module = module });
    const run_tests = b.addRunArtifact(tests);
    b.step("test", "Run ZWE regression tests").dependOn(&run_tests.step);
    b.step("check", "Compile ZWE without installing").dependOn(&exe.step);
}
