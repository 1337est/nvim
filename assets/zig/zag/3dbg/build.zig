const std = @import("std");

const main_file = "src/main.zig";
const exe = "3dbg";
const tests = "3dbg_test";

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    // Module
    const mod = b.createModule(.{
        .root_source_file = b.path(main_file),
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });

    // Test: Compile -> Run
    const compile_tests = b.addTest(.{
        .name = tests,
        .root_module = mod,
    });
    const run_tests = b.addRunArtifact(compile_tests);
    run_tests.setCwd(b.path("."));
    run_tests.setEnvironmentVariable("ZIG_EXE", b.graph.zig_exe);
    run_tests.has_side_effects = true;

    const test_step = b.step("test", "Run all tests");
    test_step.dependOn(&run_tests.step);

    // Executable: Test -> Compile
    const compile_exe = b.addExecutable(.{
        .name = exe,
        .root_module = mod,
    });
    compile_exe.step.dependOn(test_step);

    // Install: Compile -> Install
    const install_exe = b.addInstallArtifact(compile_exe, .{});

    const install_step = b.getInstallStep();
    install_step.dependOn(&install_exe.step);

    // Run: Install -> Run
    const run_exe = b.addRunArtifact(compile_exe);
    run_exe.setCwd(b.path("."));
    run_exe.addPassthruArgs();
    run_exe.step.dependOn(install_step);

    const run_step = b.step("run", "Run 3dbg locally");
    run_step.dependOn(&run_exe.step);
}
