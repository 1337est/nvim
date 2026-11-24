const std = @import("std");

// Expose Project to other packages' build.zig files.
pub const Project = @import("noodles/Project.zig");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Ramen root
    const ramen = b.addModule("ramen", .{
        .root_source_file = b.path("ramen.zig"),
        .target = target,
        .optimize = optimize,
    });

    // Broth root
    const broth = b.addModule("broth", .{
        .root_source_file = b.path("broth.zig"),
        .target = target,
        .optimize = optimize,
    });
    ramen.addImport("broth", broth);

    const sockman = b.addModule("Sockman", .{
        .root_source_file = b.path("broth/Sockman.zig"),
        .target = target,
        .optimize = optimize,
    });
    broth.addImport("Sockman", sockman);

    // Noodles root
    const noodles = b.addModule("noodles", .{
        .root_source_file = b.path("noodles.zig"),
        .target = target,
        .optimize = optimize,
    });
    ramen.addImport("noodles", noodles);

    const project = b.addModule("Project", .{
        .root_source_file = b.path("noodles/Project.zig"),
        .target = target,
        .optimize = optimize,
    });
    noodles.addImport("Project", project);

    const clift = b.addModule("clift", .{
        .root_source_file = b.path("noodles/clift.zig"),
        .target = target,
        .optimize = optimize,
    });
    noodles.addImport("clift", clift);

    const linux = b.addModule("linux", .{
        .root_source_file = b.path("noodles/linux.zig"),
        .target = target,
        .optimize = optimize,
    });
    noodles.addImport("linux", linux);

    // Toppings root
    const toppings = b.addModule("toppings", .{
        .root_source_file = b.path("toppings.zig"),
        .target = target,
        .optimize = optimize,
    });
    ramen.addImport("toppings", toppings);
}
