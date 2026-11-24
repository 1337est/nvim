const std = @import("std");

// Build-time API
pub const Project = @import("noodles/Project.zig");

pub fn build(b: *std.Build) !void {
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

    // Extract SQLite amalgamation for sqlite3 module and tc
    const archive = b.addExecutable(.{
        .name = "sqlite3_archive",
        .root_module = b.createModule(.{
            .root_source_file = b.path("noodles/Project/Archive.zig"),
            .target = b.graph.host,
        }),
    });
    const extract = b.addRunArtifact(archive);
    extract.addArg("extract");
    extract.addFileArg2(
        b.path("toppings/sqlite-amalgamation-3540100.zip"),
        .{},
    );
    const directory = extract.addOutputDirectoryArg2("source", .{});
    const sqlite_dir = directory.path(b, "sqlite-amalgamation-3540100");

    const tc_sqlite3 = b.addTranslateC(.{
        .root_source_file = sqlite_dir.path(b, "sqlite3.h"),
        .target = target,
        .optimize = optimize,
    });
    tc_sqlite3.addIncludePath(sqlite_dir);
    const sqlite3 = b.addModule("sqlite3", .{
        .root_source_file = b.path("toppings/sqlite3.zig"),
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });
    sqlite3.addCSourceFile(.{ .file = sqlite_dir.path(b, "sqlite3.c") });
    sqlite3.addImport("tc_sqlite3", tc_sqlite3.addModule("tc_sqlite3"));
    toppings.addImport("sqlite3", sqlite3);
}
