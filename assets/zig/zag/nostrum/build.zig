const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const mod = b.addModule("nostrum", .{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
    });
    // For @cImport("sqlite3.h") inside the nostrum module
    mod.addIncludePath(b.path("sqlite"));

    const exe = b.addExecutable(.{
        .name = "nostrum",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
            .link_libc = true, // SQLite needs libc
            .imports = &.{
                .{ .name = "nostrum", .module = mod },
            },
        }),
    });
    exe.root_module.addIncludePath(b.path("sqlite")); // for sqlite3.c includes
    // Compile sqlite3.c into the executable
    exe.root_module.addCSourceFile(.{
        .file = b.path("sqlite/sqlite3.c"),
        .flags = &.{
            "-DSQLITE_THREADSAFE=1",
            "-DSQLITE_OMIT_LOAD_EXTENSION",
        },
    });

    b.installArtifact(exe);

    const run_step = b.step("run", "Run the app");

    const run_cmd = b.addRunArtifact(exe);
    run_step.dependOn(&run_cmd.step);

    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const mod_tests = b.addTest(.{
        .root_module = mod,
    });

    const run_mod_tests = b.addRunArtifact(mod_tests);

    const exe_tests = b.addTest(.{
        .root_module = exe.root_module,
    });

    const run_exe_tests = b.addRunArtifact(exe_tests);

    const test_step = b.step("test", "Run tests");
    test_step.dependOn(&run_mod_tests.step);
    test_step.dependOn(&run_exe_tests.step);
}
