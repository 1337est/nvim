return {
    cmd          = { 'gopls' },
    filetypes    = { 'go', 'gomod', 'gowork' },
    root_markers = { 'go.work', 'go.mod', '.git' },
    settings     = {
        gopls = {
            usePlaceholders = true,
            analyses = { unusedparams = true, shadow = true },
            staticcheck = true,
        },
    }
}
