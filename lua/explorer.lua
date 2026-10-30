-- Explorer TODO: Replace netrw with Neovim's native directory explorer in 0.13.x.

local M = {}

function M.setup()
    vim.cmd("packadd! netrw")
    vim.keymap.set("n", "<leader>e", function()
        if vim.w.netrw_rexlocal ~= nil then
            vim.cmd("Rexplore")
        else
            vim.cmd("Explore")
        end
    end, {
        silent = true,
        desc = "Explorer",
    })

    local group = vim.api.nvim_create_augroup("Explorer", { clear = true })
    vim.api.nvim_create_autocmd("FileType", {
        group = group,
        pattern = "netrw",
        callback = function(args)
            vim.schedule(function()
                if not vim.api.nvim_buf_is_valid(args.buf) or vim.bo[args.buf].filetype ~= "netrw" then
                    return
                end

                local function map(key, rhs, description)
                    vim.keymap.set("n", key, rhs, {
                        buffer = args.buf,
                        remap = true,
                        silent = true,
                        desc = "Explorer: " .. description,
                    })
                end

                map("<leader>e", "-", "go up dir")
                map("<leader>gh", "gh", "toggle .files")
                map("<leader>%", "%", "create file")
                map("<leader>d", "d", "create directory")
                map("<leader>R", "R", "rename file/directory")
                map("<leader>D", "D", "delete file/directory")
            end)
        end,
    })
end

return M
