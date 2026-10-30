local work_dirs = {
    "~/gl/refactor/sockmand-0",
    "~/gl/refactor/sockmann-control",
    "~/gl/refactor/sockmann-telemetry",
    "~/gl/refactor/sockmans-adsb",
    "~/gl/refactor/sockmans-database",
    "~/gl/refactor/sockmans-filewriter",
    "~/gl/refactor/sockmans-gpr",
    "~/gl/refactor/sockmans-mavlink",
    "~/gl/refactor/sockmans-mesh",
    "~/gl/refactor/sockmans-recordplayer",
    "~/gl/refactor/sockmans-rtsp",
    "~/gl/refactor/sockmans-vr",
}

return {
    concurrency = 4,
    max_output_bytes = 2 * 1024 * 1024,
    max_history = 20,
    batches = {
        init_work = {
            workspace = true,
            -- Commands execute in this order within each directory.
            commands = {
                {
                    exe = "git",
                    args = { "init", "-b", "master" },
                },
                {
                    exe = "sh",
                    args = {
                        "-c",
                        "printf '%s\\n' '.zig-cache/' 'zig-out/' 'zig-pkg/' > .gitignore",
                    },
                },
                {
                    exe = "zig",
                    args = { "init", "-m" },
                },
                {
                    exe = "zig",
                    args = { "fetch", "--save=shared", "../zag" },
                },
            },

            -- These directories run concurrently. No recursive discovery.
            dirs = work_dirs,
        },


        zig_build = {
            workspace = true,
            concurrency = 2,
            commands = {
                {
                    exe = "zig",
                    args = { "build" },
                },
            },

            dirs = {
                "~/gl/refactor/rayvn3dEngine",
                "~/gl/refactor/zag",
            },
        },
    },
}
