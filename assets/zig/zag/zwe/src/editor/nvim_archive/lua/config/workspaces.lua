-- Explicit user-controlled configuration. Nothing is loaded from project-local Lua.
return {
    defaults = { zig_exe = "zig", zls_exe = "zls", build_options = {} },
    -- Existing personal project roots. Remove any root you do not trust to execute build.zig.
    trusted_roots = { "~/mkit", "~/gl/refactor", vim.fn.stdpath("config") },
    projects = {
        -- ["~/mkit/example"] = {
        --     zig_exe = "/absolute/path/to/zig", zls_exe = "/absolute/path/to/zls",
        --     build_options = { "target=aarch64-linux", "optimize=safe" }, trusted = true,
        -- },
    },
}
