---@type vim.lsp.Config
return {
    -- The chosen workspace determines both executables; a command-only :ZigExe override does not.
    cmd = function(dispatchers, config)
        local ws = require("workspace").for_root(config.root_dir or vim.fn.getcwd())
        return vim.lsp.rpc.start({ ws.zls_exe }, dispatchers, { cwd = ws.root })
    end,
    filetypes = { "zig", "zir" },
    root_dir = function(buf, on_dir) on_dir(require("workspace").get(buf).root) end,
    workspace_required = false,
    before_init = function(_, config)
        local ws = require("workspace").for_root(config.root_dir or vim.fn.getcwd())
        config.settings = config.settings or {}
        config.settings.zls = config.settings.zls or {}
        config.settings.zls.zig_exe_path = ws.zig_exe
        config._zwe_workspace_key = ws.key
    end,
}
