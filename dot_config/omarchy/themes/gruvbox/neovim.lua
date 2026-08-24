-- Override the shipped gruvbox spec: omarchy's gruvbox colors.toml is the
-- gruvbox-material palette (fg #d4be98, blue #7daea3), but the official theme
-- loads classic ellisonleao/gruvbox.nvim (fg #ebdbb2). sainnhe/gruvbox-material
-- with its defaults ('medium' background, 'material' foreground) matches
-- colors.toml exactly. Keep the LazyVim-shaped second entry: both stock omarchy
-- LazyVim setups and the AstroNvim shim read the colorscheme name from it.
return {
  {
    "sainnhe/gruvbox-material",
    priority = 1000,
  },
  {
    "LazyVim/LazyVim",
    opts = {
      colorscheme = "gruvbox-material",
    },
  },
}
