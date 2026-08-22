-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here

-- AstroNvim-style save on <leader>w.
--
-- LazyVim leaves <leader>w unmapped and uses it as a which-key proxy for <C-w>,
-- with two real maps underneath: <leader>wd (delete window) and <leader>wm
-- (zoom). Both are removed here so <leader>w resolves immediately instead of
-- waiting out timeoutlen (300ms) to disambiguate the longer sequences.
--
-- Nothing is actually lost:
--   * every window command is still on <C-w> (wd == <C-w>c)
--   * which-key's window hydra is still on <C-w><Space>
--   * zoom is still on <leader>uZ, which LazyVim maps alongside <leader>wm
for _, lhs in ipairs({ "<leader>wd", "<leader>wm" }) do
  pcall(vim.keymap.del, "n", lhs)
end

vim.keymap.set("n", "<leader>w", "<cmd>w<cr>", { desc = "Save" })
