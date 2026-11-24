const std = @import("std");

// Expose Project to other packages' build.zig files.
pub const Project = @import("noodles/Project.zig");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const sockman = b.addModule("Sockman", .{
        .root_source_file = b.path("broth/Sockman.zig"),
        .target = target,
        .optimize = optimize,
    });

    const project = b.addModule("Project", .{
        .root_source_file = b.path("noodles/Project.zig"),
        .target = target,
        .optimize = optimize,
    });

    const broth = b.addModule("broth", .{
        .root_source_file = b.path("broth.zig"),
        .target = target,
        .optimize = optimize,
    });
    broth.addImport("Sockman", sockman);

    const noodles = b.addModule("noodles", .{
        .root_source_file = b.path("noodles.zig"),
        .target = target,
        .optimize = optimize,
    });
    noodles.addImport("Project", project);

    const ramen = b.addModule("ramen", .{
        .root_source_file = b.path("ramen.zig"),
        .target = target,
        .optimize = optimize,
    });
    ramen.addImport("broth", broth);
    ramen.addImport("noodles", noodles);
}
