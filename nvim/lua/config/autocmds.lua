-- Autocmds are automatically loaded on the VeryLazy event
-- Default autocmds that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/autocmds.lua
--
-- Add any additional autocmds here
-- with `vim.api.nvim_create_autocmd`
--
-- Or remove existing autocmds by their group name (which is prefixed with `lazyvim_` for the defaults)
-- e.g. vim.api.nvim_del_augroup_by_name("lazyvim_wrap_spell")

-- Thesis repo: no format-on-save for Markdown (shared files, compact tables).
-- Format by hand with <leader>cf when wanted.
local thesis_root = vim.fn.expand("~/Documents/thesis/thesis-ai-toy-robot")
vim.api.nvim_create_autocmd("FileType", {
  group = vim.api.nvim_create_augroup("thesis_md_noformat", { clear = true }),
  pattern = "markdown",
  callback = function(ev)
    local path = vim.api.nvim_buf_get_name(ev.buf)
    if vim.startswith(path, thesis_root .. "/") then
      vim.b[ev.buf].autoformat = false
    end
  end,
})
