-- Demote LazyVim's <leader>w "windows" group (a proxy for <C-w>) to a plain
-- mapping, so the popup shows "Save" instead of a group that no longer has
-- any children. See lua/config/keymaps.lua for the keymap itself.
return {
  "folke/which-key.nvim",
  opts = {
    spec = {
      { "<leader>w", desc = "Save", group = false, proxy = false, expand = false },
    },
  },
}
