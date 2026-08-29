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

-- Audio outputs: switch current and future streams between local speakers,
-- HomePods and Apple TVs. Same floating-TUI route as the pickers below.
o.bind(
  "SUPER + ALT + A",
  "Audio output",
  "omarchy-launch-tui --app-id=TUI.float $HOME/.config/omarchy/plugins/jonny.audio/audio-tui.sh"
)

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

-- USB drives: format, write a bootable image, or power one off for removal.
-- Same TUI.float reasoning as above. This picker deliberately stays open --
-- dd prints progress for minutes -- so it is a plain `launch tui` rather than
-- `launch or focus tui`, whose app-id match would raise whichever floating
-- TUI happened to be open already.
o.bind(
  "SUPER + ALT + U",
  "USB drives",
  "omarchy-launch-tui --app-id=TUI.float $HOME/.config/omarchy/plugins/jonny.usb/usb-tui.sh"
)

-- Skills: copy agent skills out of the repos I follow into the one I own.
-- L for "learn", because the letters this picker wanted are all taken: S is
-- Omarchy's "Move window to scratchpad", K and A are gone too (A is the audio
-- picker above). Check with `hyprctl binds` before adding the next one.
-- Same TUI.float reasoning as above, but unlike the three pickers this one is
-- not a picker: it opens the `skills-sync` TUI, which stays until quit, and
-- prints the plan and its confirmation after that.
o.bind(
  "SUPER + ALT + L",
  "Skills",
  "omarchy-launch-tui --app-id=TUI.float $HOME/.config/omarchy/plugins/jonny.skills/skills.sh"
)

-- Vim home-row window focus, replacing SUPER + arrows as the keys my hands
-- reach for. The arrows stay bound to the same dispatchers by
-- default/hypr/bindings/tiling.lua, so this adds a second route rather than
-- retraining anything; nothing here unbinds them.
-- Three defaults had to go to free the row -- none of them was in use:
--   SUPER + J  Toggle window split      (tiling.lua)
--   SUPER + K  Keybindings              (utilities.lua)
--   SUPER + L  Toggle workspace layout  (tiling.lua)
-- The keybindings menu is still reachable from the Omarchy menu (Learn ->
-- Keybindings), so it did not need a new chord. SUPER + H was already free.
-- SUPER + SHIFT + hjkl is deliberately left unbound: it is where "swap window"
-- goes if the focus row proves itself.
hl.unbind("SUPER + J")
hl.unbind("SUPER + K")
hl.unbind("SUPER + L")

o.bind("SUPER + H", "Focus on left window", hl.dsp.focus({ direction = "l" }))
o.bind("SUPER + J", "Focus on below window", hl.dsp.focus({ direction = "d" }))
o.bind("SUPER + K", "Focus on above window", hl.dsp.focus({ direction = "u" }))
o.bind("SUPER + L", "Focus on right window", hl.dsp.focus({ direction = "r" }))
