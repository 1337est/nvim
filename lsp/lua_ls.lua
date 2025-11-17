return {
    cmd          = { 'lua-language-server' },
    filetypes    = { 'lua' },
    root_markers = { '.luarc.json', '.luarc.jsonc', '.git' },
    settings     = {
        Lua = {
            diagnostics = { globals = { 'vim' }, disable = { 'missing-fields' } },
            completion  = { callSnippet = 'Replace' },
            format      = {
                enable = true,
                defaultConfig = {
                    indent_style = 'space',
                    indent_size = '4',
                    tab_width = '4',
                    quote_style = 'none',
                    continuation_indent = '4',
                    max_line_length = '200',
                    align_function_params = 'false',
                    align_continuous_inline_comment = 'false',
                    align_array_table = 'false',
                    break_all_list_when_line_exceed = 'false',
                    auto_collapse_lines = 'false',
                    break_before_braces = 'false',
                },
            },
        },
    }
}
