-- C / C++ / ObjC (clangd)
--- @type vim.lsp.Config
return {
    cmd          = { 'clangd', '--background-index', '--clang-tidy' },
    filetypes    = { 'c', 'cpp', 'objc', 'objcpp', 'cuda' },
    root_markers = {
        '.clangd',
        '.clang-tidy',
        '.clang-format',
        'compile_commands.json',
        'compile_flags.txt',
        'configure.ac', -- AutoTools
        '.git'
    },
}
