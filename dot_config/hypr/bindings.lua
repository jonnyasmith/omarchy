-- Keep only your personal keybinding overrides here. Add new bindings or
-- unbind defaults before replacing them.

-- See current bindings and descriptions:
--   omarchy menu keybindings --print

-- To disable every Omarchy default binding, set this in
-- ~/.config/hypr/hyprland.lua before require("default.hypr.omarchy"), then add
-- only the bindings you want below:
--   omarchy_default_bindings = false

-- To disable all preinstalled app/webapp bindings, set:
--   omarchy_preinstalled_bindings = false

-- Add a new binding.
-- o.bind("SUPER + SHIFT + R", "SSH", "alacritty -e ssh your-server")

-- Change an existing binding by unbinding it first, then binding the key again.
-- This example changes SUPER+SPACE from the launcher to the Omarchy root menu.
-- hl.unbind("SUPER + SPACE")
-- o.bind("SUPER + SPACE", "Omarchy menu", "omarchy-menu toggle root")

-- Disable a default binding without replacing it.
-- hl.unbind("SUPER + SHIFT + B")

-- Logitech MX Keys examples:
-- o.bind("SUPER + SHIFT + S", nil, "omarchy-capture-screenshot")
-- o.bind("SUPER + H", nil, "voxtype record toggle")
-- o.bind("SUPER + PERIOD", nil, "omarchy-shell shell toggle omarchy.emojis")

-- Dev ports: pick a listening local dev server and open it, keyboard only.
-- TUI.float is the app-id Omarchy's own window rules float
-- (default/hypr/apps/system.lua); the app-id omarchy-launch-tui would derive
-- from the script name is not in that list, so the terminal would tile.
-- The second argument is not a comment -- `omarchy menu keybindings` renders
-- it, and an undescribed bind is an invisible one.
o.bind(
  "SUPER + ALT + P",
  "Dev ports",
  "omarchy-launch-tui --app-id=TUI.float $HOME/.config/omarchy/plugins/jonny.ports/ports-tui.sh"
)
