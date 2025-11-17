return {
    cmd          = { 'rust-analyzer' },
    root_markers = { 'Cargo.toml', 'rust-project.json', '.git' },
    filetypes    = { 'rust' },
    settings     = {
        ['rust-analyzer'] = { cargo = { allFeatures = true }, check = { command = 'clippy' }, },
    }
}
