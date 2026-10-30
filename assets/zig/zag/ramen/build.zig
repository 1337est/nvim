const std = @import("std");

pub const Systemd = @import("lib/Systemd.zig");

pub fn build(b: *std.Build) void {
    _ = b.addModule("linux", .{
        .root_source_file = b.path("lib/linux.zig"),
    });

    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const sockman = b.addModule("libsockman", .{
        .root_source_file = b.path("lib/Sockman.zig"),
        .target = target,
        .optimize = optimize,
    });
    const sockman_tests = b.addTest(.{
        .root_module = sockman,
    });
    const run_sockman_tests = b.addRunArtifact(sockman_tests);
    b.getInstallStep().dependOn(&run_sockman_tests.step);
}
