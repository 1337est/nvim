const std = @import("std");
pub const Project = @This();

pub const Systemd = @import("Project/Systemd.zig");
pub const Archive = @import("Project/Archive.zig");
pub const Scope = @import("Project/Scope.zig").Scope;

pub const Kind = union(enum) {
    exe,
    lib,
    c_src_archive: struct {
        path: []const u8,
        source_file: []const u8,
        sha3_256: []const u8,
    },
};

b: *std.Build,
name: []const u8,
scope: Scope,
kind: Kind,
module: *std.Build.Module,
test_step: *std.Build.Step,
compile_step: *std.Build.Step,
artifact: *std.Build.Step.Compile,
install_step: *std.Build.Step,
install_artifact: *std.Build.Step.InstallArtifact,

run_step: ?*std.Build.Step = null, // only for Kind.exe
runner: ?*std.Build.Step.Run = null, // only for Kind.exe

systemd: ?Systemd = null, // Optional systemd unit file generation/handling

pub fn init(
    b: *std.Build,
    all_tests: *std.Build.Step,
    name: []const u8,
    scope: Scope,
    kind: Kind,
    options: std.Build.Module.CreateOptions,
) !Project {
    // Define the module and its named stages.
    const module = switch (kind) {
        .exe => b.createModule(options),
        .lib, .c_src_archive => b.addModule(name, options),
    };
    const test_step = b.step(b.fmt("{s}-test", .{name}), b.fmt("Test {s}", .{name}));
    const compile_step = b.step(name, b.fmt("Compile {s}", .{name}));
    const install_step = b.step(b.fmt("{s}-install", .{name}), b.fmt("Install {s}", .{name}));
    all_tests.dependOn(test_step);
    compile_step.dependOn(test_step);
    install_step.dependOn(compile_step);

    const artifact = switch (kind) {
        .exe => b.addExecutable(.{ .name = name, .root_module = module }),
        .lib, .c_src_archive => b.addLibrary(.{
            .name = name,
            .root_module = module,
            .linkage = .static,
        }),
    };

    // Attach the work to each stage.
    switch (kind) {
        .exe, .lib => {
            const tests = b.addTest(.{ .name = b.fmt("{s}_test", .{name}), .root_module = module });
            const run_tests = b.addRunArtifact(tests);
            if (kind == .exe) {
                run_tests.setCwd(b.path("."));
                run_tests.setEnvironmentVariable("ZIG_EXE", b.graph.zig_exe);
                run_tests.has_side_effects = true;
            }
            test_step.dependOn(&run_tests.step);
            artifact.step.dependOn(test_step);
            compile_step.dependOn(&artifact.step);
        },
        .c_src_archive => |source| {
            const tool = b.addExecutable(.{
                .name = b.fmt("{s}_archive", .{name}),
                .root_module = b.createModule(.{
                    .root_source_file = b.path("lib/ramen/noodles/Project/Archive.zig"),
                    .target = b.graph.host,
                }),
            });

            const verify = b.addRunArtifact(tool);
            verify.addArg("verify");
            verify.addFileArg2(b.path(source.path), .{});
            verify.addArg(source.sha3_256);
            verify.expectExitCode(0);
            test_step.dependOn(&verify.step);

            const extract = b.addRunArtifact(tool);
            extract.addArg("extract");
            extract.addFileArg2(b.path(source.path), .{});
            const directory = extract.addOutputDirectoryArg2("source", .{});
            extract.step.dependOn(test_step);
            compile_step.dependOn(&extract.step);
            artifact.step.dependOn(compile_step);

            const c_source = directory.path(b, source.source_file);
            module.addCSourceFile(.{ .file = c_source });
            module.addIncludePath(c_source.dirname());
            artifact.installHeadersDirectory(c_source.dirname(), "", .{});
        },
    }

    // Install each artifact after its compile stage.
    const install_artifact = b.addInstallArtifact(artifact, .{});
    install_artifact.step.dependOn(compile_step);
    install_step.dependOn(&install_artifact.step);
    b.getInstallStep().dependOn(install_step);

    // Only executable projects have a run stage.
    var run_step: ?*std.Build.Step = null;
    var runner: ?*std.Build.Step.Run = null;
    if (kind == .exe) {
        const step = b.step(b.fmt("{s}-run", .{name}), b.fmt("Run {s}", .{name}));
        const run_exe = b.addRunArtifact(artifact);
        run_exe.setCwd(b.path("."));
        run_exe.addPassthruArgs();
        step.dependOn(install_step);
        run_exe.step.dependOn(install_step);
        step.dependOn(&run_exe.step);
        run_step = step;
        runner = run_exe;
    }

    return .{
        .b = b,
        .name = name,
        .scope = scope,
        .kind = kind,
        .module = module,
        .test_step = test_step,
        .compile_step = compile_step,
        .artifact = artifact,
        .install_step = install_step,
        .install_artifact = install_artifact,
        .run_step = run_step,
        .runner = runner,
    };
}

pub fn configureSystemd(self: *Project, definition: Systemd, enabled: bool) !void {
    self.systemd = definition;
    if (!enabled) return;

    const b = self.b;
    const verification = try definition.validate(b);
    const unit_file = try definition.stage(b);
    const name = std.fs.path.basename(definition.project_file.path);

    switch (self.scope) {
        .local => {
            const installation = b.addInstallFile(
                unit_file,
                b.fmt("systemd/{s}", .{name}),
            );

            installation.step.dependOn(&verification.step);
            self.install_step.dependOn(&installation.step);
        },
        .user, .system => return error.SystemdScopeNotImplemented,
    }
}
