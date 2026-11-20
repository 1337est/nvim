const std = @import("std");

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const all_tests = b.step("test", "Run all project tests");

    // -------------------------------------------------------------------
    // Libraries
    // -------------------------------------------------------------------

    // ramen
    _ = Project.init(b, all_tests, "ramen", .lib, .{
        .root_source_file = b.path("lib/ramen.zig"),
        .target = target,
        .optimize = optimize,
    });

    // systemd
    _ = Project.init(b, all_tests, "systemd", .lib, .{
        .root_source_file = b.path("lib/systemd.zig"),
        .target = target,
        .optimize = optimize,
    });

    // sockman
    _ = Project.init(b, all_tests, "sockman", .lib, .{
        .root_source_file = b.path("lib/sockman.zig"),
        .target = target,
        .optimize = optimize,
    });

    // clift
    _ = Project.init(b, all_tests, "clift", .lib, .{
        .root_source_file = b.path("lib/clift.zig"),
        .target = target,
        .optimize = optimize,
    });

    // sqlite
    const sqlite = Project.init(b, all_tests, "sqlite3", .lib, .{
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });
    // TODO: Replace with std/Build/Module.include_dirs. Cleaner
    const sqlite_include = try sqlite.addCArchive(
        "lib/sqlite/sqlite-amalgamation-3540100.zip",
        "sqlite-amalgamation-3540100",
        "sqlite3.c",
    );

    // -------------------------------------------------------------------
    // Executables
    // -------------------------------------------------------------------

    // 3dbg
    _ = Project.init(b, all_tests, "3dbg", .exe, .{
        .root_source_file = b.path("src/3dbg.zig"),
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });

    // doop
    const doop = Project.init(b, all_tests, "doop", .exe, .{
        .root_source_file = b.path("src/doop.zig"),
        .target = target,
        .optimize = optimize,
    });
    if (target.result.os.tag == .windows) {
        doop.module.linkSystemLibrary("user32", .{ .use_pkg_config = .no });
        doop.module.linkSystemLibrary("kernel32", .{ .use_pkg_config = .no });
    }

    // nostrum
    const nostrum = Project.init(b, all_tests, "nostrum", .exe, .{
        .root_source_file = b.path("src/nostrum.zig"),
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });
    nostrum.module.addIncludePath(sqlite_include);
    nostrum.module.linkLibrary(sqlite.artifact);

    // wagon
    const wagon = Project.init(b, all_tests, "wagon", .exe, .{
        .root_source_file = b.path("src/wagon.zig"),
        .target = target,
        .optimize = optimize,
    });

    // rhei
    const rhei = Project.init(b, all_tests, "rhei", .exe, .{
        .root_source_file = b.path("src/rhei.zig"),
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });
    rhei.module.linkSystemLibrary("xkbcommon", .{});

    // Reuse the compiled Wagon executable for Wayland protocol generation.
    inline for (.{
        .{ "wayland", "wayland" },
        .{ "wayland", "ext-idle-notify-v1" },
        .{ "wlr", "wlr-layer-shell-unstable-v1" },
        .{ "river", "river-window-management-v1" },
        .{ "river", "river-xkb-bindings-v1" },
    }) |wayland_protocol| {
        const wagon_run = b.addRunArtifact(wagon.artifact);
        wagon_run.addFileArg(b.path(b.fmt(
            "src/rhei/protocol/{s}/{s}.xml",
            .{ wayland_protocol[0], wayland_protocol[1] },
        )));
        const wagon_output = wagon_run.addOutputFileArg(
            wayland_protocol[1] ++ ".zig",
        );
        rhei.module.addImport(
            wayland_protocol[1],
            b.createModule(.{ .root_source_file = wagon_output }),
        );
    }

    // view
    _ = Project.init(b, all_tests, "view", .exe, .{
        .root_source_file = b.path("src/view.zig"),
        .target = target,
        .optimize = optimize,
    });

    // zwe
    const zwe = Project.init(b, all_tests, "zwe", .exe, .{
        .root_source_file = b.path("src/zwe.zig"),
        .target = target,
        .optimize = optimize,
    });

    // Reuse the compiled ZWE executable for configuration and Neovim files.
    inline for (.{
        .{ "--print-nvim-lua", "zwe.lua", "share/zwe/nvim/lua/zwe.lua" },
        .{ "--print-nvim-lsp", "zls.lua", "share/zwe/nvim/lsp/zls.lua" },
        .{ "--print-config", "config.zon", "share/zwe/config.zon" },
    }) |zwe_arg| {
        const zwe_run = b.addRunArtifact(zwe.artifact);
        zwe_run.addArg(zwe_arg[0]);
        const zwe_output = zwe_run.captureStdOut(.{
            .basename = zwe_arg[1],
        });
        b.getInstallStep().dependOn(
            &b.addInstallFile(zwe_output, zwe_arg[2]).step,
        );
    }

    // template
    _ = Project.init(b, all_tests, "template", .exe, .{
        .root_source_file = b.path("src/template.zig"),
        .target = target,
        .optimize = optimize,
    });

    // udeploy
    _ = Project.init(b, all_tests, "udeploy", .exe, .{
        .root_source_file = b.path("src/udeploy.zig"),
        .target = target,
        .optimize = optimize,
    });
}

// -----------------------------------------------------------------------------
// Project struct for executables and static libraries
// -----------------------------------------------------------------------------

const Project = struct {
    const Kind = enum { exe, lib, c_src_archive };

    b: *std.Build,
    name: []const u8, // executable, project, module, etc, name
    kind: Kind,

    test_step: ?*std.Build.Step, // zig build test-<project>; null for c archives
    module: *std.Build.Module,

    compile_step: *std.Build.Step, // zig build <project>
    artifact: *std.Build.Step.Compile,
    install_artifact: *std.Build.Step.InstallArtifact,

    run_step: ?*std.Build.Step = null, // zig build run-<project>; null for libraries
    runner: ?*std.Build.Step.Run = null, // null for libraries

    pub fn init(
        b: *std.Build,
        all_tests: *std.Build.Step,
        name: []const u8,
        kind: Kind,
        options: std.Build.Module.CreateOptions,
    ) Project {
        // 1. Module.
        const module = switch (kind) {
            .exe => b.createModule(options),
            .lib, .c_src_archive => b.addModule(name, options),
        };

        // 2. Tests.
        const compile_tests = b.addTest(.{
            .name = b.fmt("{s}_test", .{name}),
            .root_module = module,
        });

        const run_tests = b.addRunArtifact(compile_tests);

        switch (kind) {
            .exe => {
                run_tests.setCwd(b.path("."));
                run_tests.setEnvironmentVariable("ZIG_EXE", b.graph.zig_exe);
                run_tests.has_side_effects = true;
            },
            .lib => {},
        }

        const test_step = b.step(
            b.fmt("test-{s}", .{name}),
            b.fmt("Run {s} tests", .{name}),
        );
        test_step.dependOn(&run_tests.step);
        all_tests.dependOn(test_step);

        // 3. Compile.
        const artifact = switch (kind) {
            .exe => b.addExecutable(.{
                .name = name,
                .root_module = module,
            }),
            .lib => b.addLibrary(.{
                .name = name,
                .root_module = module,
                .linkage = .static,
            }),
        };

        artifact.step.dependOn(test_step);

        const compile_step = b.step(
            name,
            b.fmt("Compile {s}", .{name}),
        );
        compile_step.dependOn(&artifact.step);

        // 4. Install.
        const install_artifact = b.addInstallArtifact(artifact, .{});
        b.getInstallStep().dependOn(&install_artifact.step);

        // 5. Run.
        var run_step: ?*std.Build.Step = null;
        var runner: ?*std.Build.Step.Run = null;

        switch (kind) {
            .exe => {
                const run_exe = b.addRunArtifact(artifact);
                run_exe.setCwd(b.path("."));
                run_exe.addPassthruArgs();
                run_exe.step.dependOn(&install_artifact.step);

                const step = b.step(
                    b.fmt("run-{s}", .{name}),
                    b.fmt("Run {s} locally", .{name}),
                );
                step.dependOn(&run_exe.step);

                run_step = step;
                runner = run_exe;
            },
            .lib => {},
        }

        return .{
            .b = b,
            .name = name,
            .kind = kind,

            .test_step = test_step,
            .module = module,

            .compile_step = compile_step,
            .artifact = artifact,
            .install_artifact = install_artifact,

            .run_step = run_step,
            .runner = runner,
        };
    }

    // TODO: Move to Project.init with explicit Project.Kind.c_src_archive handling
    pub fn addCArchive(
        self: *const Project,
        archive_path: []const u8,
        archive_root: []const u8,
        source_file: []const u8,
    ) !std.Build.LazyPath {
        const b = self.b;
        const io = b.graph.io;
        const output_path = b.fmt("zig-out/lib/{s}-src", .{self.name});

        // Extraction modifies the filesystem during configuration
        b.graph.poisonCache();

        const root = try b.root.openDir(io, ".", .{});
        defer root.close(io);

        const archive = try root.openFile(io, archive_path, .{});
        defer archive.close(io);

        try root.deleteTree(io, output_path);
        const output = try root.createDirPathOpen(io, output_path, .{});
        defer output.close(io);

        var buffer: [64 * 1024]u8 = undefined;
        var reader = archive.reader(io, &buffer);
        try std.zip.extract(output, &reader, .{});

        const source_dir = b.path(b.fmt(
            "{s}/{s}",
            .{ output_path, archive_root },
        ));
        self.module.addCSourceFile(.{ .file = source_dir.path(b, source_file) });
        self.module.addIncludePath(source_dir);

        return source_dir;
    }
};
