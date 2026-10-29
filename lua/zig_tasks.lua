return {
    -- Search your own project trees. Paths are expanded when a task is invoked.
    roots = { "~/mkit" },
    zig = "zig", -- Zig 0.17.0 for manifest parsing and the default task executable.
    exclude = { ".git", ".zig-cache", "zig-cache", "zig-out", "zig-pkg", "node_modules" },

    tasks = {
        build = { argv = { "build" } },
        test = { argv = { "build", "test" } },

        -- Uncomment this task and supply the URL you want every consumer to use.
        -- The dependency is its existing key in build.zig.zon, including aliases.
        -- update_zag = {
        --     dependency = "zag",
        --     argv = { "fetch", "--save=zag", "<YOUR_PACKAGE_URL>" },
        -- },

        -- A selector also works for other commands, including local dependencies.
        -- test_zag_users = {
        --     dependency = "zag",
        --     argv = { "build", "test" },
        --     zig = "/absolute/path/to/another/zig",
        -- },
    },
}
