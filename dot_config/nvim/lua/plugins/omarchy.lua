-- Omarchy theme integration for AstroNvim.
--
-- lua/plugins/theme.lua is a symlink to ~/.local/state/omarchy/current/theme/neovim.lua,
-- rewritten by omarchy-theme-set (rendered from default/themed/neovim.lua.tpl, or shipped
-- per-theme on Omarchy 3.8). Omarchy emits a LazyVim-shaped spec: the theme's colorscheme
-- plugin plus { "LazyVim/LazyVim", opts = { colorscheme = ... } }.
--
-- lazy_setup.lua imports that file with the rest of this directory, which registers the
-- colorscheme plugin (including omarchy's generated opts.colors) as-is. This file adapts
-- the LazyVim half: LazyVim itself is never installed, the colorscheme is routed through
-- AstroUI at startup, and a LazyReload handler re-applies it live when omarchy switches
-- themes (lazy's change detection sees the symlink target change and fires LazyReload).

local transparency_file = vim.fn.stdpath "config" .. "/plugin/after/transparency.lua"

local function theme_spec()
  package.loaded["plugins.theme"] = nil
  local ok, spec = pcall(require, "plugins.theme")
  if ok and type(spec) == "table" then return spec end
  return {}
end

-- Omarchy carries the colorscheme name on the LazyVim spec entry; that entry is
-- disabled below, so read the name straight from the file.
local function theme_colorscheme(spec)
  for _, entry in ipairs(spec) do
    if entry[1] == "LazyVim/LazyVim" and entry.opts and entry.opts.colorscheme then return entry.opts.colorscheme end
  end
end

local function theme_plugin_name(spec)
  for _, entry in ipairs(spec) do
    if entry[1] and entry[1] ~= "LazyVim/LazyVim" then return entry.name or entry[1] end
  end
end

---@type LazySpec
return {
  -- Omarchy's generated theme spec targets LazyVim; keep it out of this install.
  { "LazyVim/LazyVim", enabled = false },

  {
    "AstroNvim/astroui",
    opts = function(_, opts)
      local colorscheme = theme_colorscheme(theme_spec())
      if colorscheme then opts.colorscheme = colorscheme end
    end,
  },

  {
    name = "omarchy-theme-hotreload",
    dir = vim.fn.stdpath "config",
    lazy = false,
    priority = 1000,
    config = function()
      vim.api.nvim_create_autocmd("User", {
        pattern = "LazyReload",
        callback = function()
          vim.schedule(function()
            local spec = theme_spec()
            local colorscheme = theme_colorscheme(spec)
            if not colorscheme then return end
            local plugin_name = theme_plugin_name(spec)

            -- Clear all highlight groups before applying the new theme
            vim.cmd "highlight clear"
            if vim.fn.exists "syntax_on" then vim.cmd "syntax reset" end

            -- Reset background so the colorscheme can set it (light themes set light)
            vim.o.background = "dark"

            -- Unload the theme plugin's modules to force a full reload
            local plugin = plugin_name and require("lazy.core.config").plugins[plugin_name]
            if plugin then
              require("lazy.core.util").walkmods(plugin.dir .. "/lua", function(modname)
                package.loaded[modname] = nil
                package.preload[modname] = nil
              end)
            end

            -- Load the colorscheme plugin. If it's already loaded (old and new theme
            -- sharing the same plugin, e.g. generic themes on aether.nvim), lazy won't
            -- rerun setup() on a spec reload and keeps the old resolved opts in the
            -- plugin's property cache, so fully reload it to reapply setup() with the
            -- new theme's opts.
            if plugin and plugin._.loaded then
              require("lazy.core.loader").reload(plugin)
            else
              require("lazy.core.loader").colorscheme(colorscheme)
            end

            vim.defer_fn(function()
              pcall(vim.cmd.colorscheme, colorscheme)
              vim.cmd "redraw!"

              -- Reapply transparency and let UI plugins (heirline etc.) resync
              if vim.fn.filereadable(transparency_file) == 1 then
                vim.defer_fn(function()
                  vim.cmd.source(transparency_file)
                  vim.api.nvim_exec_autocmds("ColorScheme", { modeline = false })
                  vim.cmd "redraw!"
                end, 5)
              end
            end, 5)
          end)
        end,
      })
    end,
  },
}
