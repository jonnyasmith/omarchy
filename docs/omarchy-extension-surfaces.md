# Extending Omarchy

Where user functionality can be added to this desktop, cheapest first, and
which of those surfaces this repo already uses.

This is background, not per-item detail: for what is actually managed here, see
[`../README.md`](../README.md). For the operational rules — never write to
`/usr/share/omarchy/`, verify on the live surface before `chezmoi add` — read
`skill://omarchy` and [`../AGENTS.md`](../AGENTS.md) first.

Everything below was read out of `/usr/share/omarchy/` on Omarchy 4.0.x.
Paths and behaviours are cited from there rather than from the docs website,
and two places where the shipped comments overstate what is extensible are
called out at the end.

## The ethos

Omarchy ships defaults in package-owned `/usr/share/omarchy/` and loads
`~/.config/` **after** them. Four consequences shape every extension:

1. **Additive overrides, never forks.** You supply only the keys you change.
   Where an override is impossible, the sanctioned move is a *clone*:
   `omarchy plugin clone omarchy.clock` copies a built-in into
   `~/.config/omarchy/plugins/<user>.clock/` and rebinds callers and IPC to the
   clone, so cloning does not mean editing every caller.
2. **Declarative first, code as escape hatch.** JSONC for menu rows, JSON for
   bar layout, Lua for Hyprland, plain shell scripts for hooks. QML only when
   none of those can express it.
3. **The unit of extension is a shell command.** Every surface below ultimately
   hands a string to bash. That is why one script gets into the menu, the bar, a
   keybinding and a hook with no glue code between them.
4. **One process, hot reload.** The bar, notifications, menu, OSD, lock screen
   and polkit agent all run as plugins inside a single long-lived Quickshell
   (`omarchy-shell`). Summoning a panel is IPC into a warm process, not a cold
   `quickshell -p` start, and `shell.json` is re-read on save.

## The ladder

Descend a rung only when the one above cannot express the thing. Each rung
costs more to write and much more to maintain across an `omarchy update`.

| # | Rung | Reach for it when |
|---|---|---|
| 1 | Desktop launcher (`omarchy tui install`, `omarchy webapp install`) | the thing is an app you want to start |
| 2 | Menu row (`omarchy-menu.jsonc`) | it is a command you want to *find* by name |
| 3 | Keybinding (`~/.config/hypr/bindings.lua`) | it is a command you want on a chord |
| 4 | Bar command module (`type: "command"`) | it is a command whose *output* belongs on screen |
| 5 | Hook (`hooks/<event>.d/`) | it should run when the system changes, not when you ask |
| 6 | Themed template (`themed/*.tpl`) | an app needs to follow `omarchy theme set` |
| 7 | Bar QML module (`bar/modules/<id>.qml`) | the output needs interaction the bar cannot express |
| 8 | Full shell plugin (`plugins/<id>/manifest.json`) | it needs a popup, a panel, a service, or a whole bar |

This repo sits on rungs 5, 6 and 8 — `theme-set.d/` hooks, the starship and omp
`*.tpl` bridges, and `jonny.ports`. `jonny.ports` is at the bottom rung
legitimately: it needs a popup with per-row click targets. A dev-ports *count*
with no popup would have been rung 4 and about twenty lines of shell.

## The surfaces

### 1. Menu rows — `~/.config/omarchy/extensions/omarchy-menu.jsonc`

The single surface behind `SUPER + SPACE`. `SUPER + ALT + SPACE` is not a second
place: both run `omarchy-menu toggle`, the second with the `apps` route
(`/usr/share/omarchy/default/hypr/bindings/utilities.lua`).

Rows are object keys and the parent is inferred from the dotted id, so
`personal.notes` lands under a `personal` submenu and `personal` lands on the
root. Reusing an existing id overrides or extends that row, keeping the fields
you do not mention — which is how you replace a stock action without a fork.

| Field | Effect |
|---|---|
| `icon` | Nerd Font glyph in the icon column |
| `label` | row title |
| `action` | shell command; omit it and the row becomes a submenu |
| `target` | id of an existing submenu to open — links and aliases |
| `provider` | runtime row generator; **closed set**, see the traps below |
| `aliases` | extra `omarchy menu summon <name>` routes, also searchable |
| `description` | subtitle and extra search text |
| `when` | shell condition; row is hidden when it fails |
| `checked` | shell condition; appends ✓ when it succeeds |

Hot-reloads on save. `when` and `checked` are the reason a menu row often beats
a keybinding: the row can hide or tick itself, a chord cannot.

### 2. App launchers — `omarchy tui install` / `omarchy webapp install`

The zero-code rung, and the one most people miss because the output is a plain
`.desktop` file rather than anything Omarchy-shaped.

```bash
omarchy tui install "Lazydocker" lazydocker float lazydocker
omarchy webapp install                 # interactive: name, url, icon
```

`omarchy-tui-install` writes `~/.local/share/applications/<name>.desktop` with
`Exec=xdg-terminal-exec --app-id=TUI.float -e <command>`, and drops the icon in
`~/.local/share/icons/hicolor/256x256/apps/`. The `float`/`tile` answer only
picks between the app-ids `TUI.float` and `TUI.tile`; the actual float comes
from Omarchy's own window rules matching that class in
`default/hypr/apps/system.lua`. Hence a TUI in a floating terminal is not a
distinct extension surface — it is a `.desktop` file plus a naming convention.

At runtime the same effect is available to any other surface:

```bash
omarchy launch tui btop                        # new floating terminal
omarchy launch or focus tui btop               # or raise the existing one
omarchy launch floating terminal with presentation <cmd>
```

`omarchy launch or focus tui` is the one worth remembering — it makes a menu row
or keybinding idempotent instead of spawning a fifth copy.

### 3. Keybindings — `~/.config/hypr/bindings.lua`

```lua
o.bind("SUPER + SHIFT + P", "Dev ports", "omarchy-shell shell toggle jonny.ports")
```

The second argument is not a comment: `omarchy menu keybindings` reads those
descriptions and renders the searchable cheat sheet, so an undescribed bind is
an invisible one. Rebinding a key Omarchy already uses needs `hl.unbind` first.
This repo manages only `dot_config/hypr/input.lua`; there is no `bindings.lua`
here yet.

### 4 & 7. Bar modules without a plugin

`bar.layout.<section>` in `shell.json` accepts arbitrary ids alongside the
built-in `omarchy.*` ones. `BarModel.js` infers which kind you meant from the
keys present — `exec` means a command module, `source` means QML — so `type` is
documentation rather than a switch.

```jsonc
{ "id": "vpn", "type": "command", "exec": "~/.config/omarchy/bar/scripts/vpn",
  "interval": 5, "tooltip": "VPN", "onClick": "nm-connection-editor" }
```

The command may print plain text or Waybar-style JSON
(`{"text":…,"tooltip":…,"class":…}`), which makes every existing Waybar module
on the internet a candidate. It is run as `bash -lc`, so a login shell's PATH
applies.

For QML, `{ "id": "gpu", "type": "qml" }` loads
`~/.config/omarchy/bar/modules/gpu.qml`, or `source` points elsewhere. The
module is an `Item` with `implicitWidth`/`implicitHeight`, and receives `bar`,
`moduleName` and `settings` injected after load. `bar` exposes the live theme
colours, `bar.fontFamily`, `bar.position`/`bar.vertical`/`bar.barSize`,
`bar.run(command)`, the shared tooltip, and the one-popup-at-a-time coordinator.

A loose QML module is a worse deal than it looks: no manifest means no settings
schema, no entry in `omarchy plugin list`, and no `omarchy bar move`. Once a
widget is worth keeping, promote it to rung 8.

### 8. Full shell plugins — `~/.config/omarchy/plugins/<id>/`

A directory with a `manifest.json` and the QML its `entryPoints` name. `kinds`
decides what the shell does with it:

| Kind | What it is |
|---|---|
| `bar-widget` | a component the active bar drops into a section |
| `panel` | a summoned or persistent floating window (OSD, audio popup) |
| `overlay` | a fullscreen overlay (the background switcher) |
| `menu` | a summoned menu surface |
| `service` | a headless singleton, no UI — timers, watchers, state |
| `bar` | a replacement for the whole built-in bar; one active at a time |

`service` is the quiet one. A plugin with no UI at all, loaded once per session
inside a process that is already running, is strictly better than a user systemd
unit for anything that needs to talk to the shell.

Distribution is git: a plugin is a repo with `manifest.json` at its root.

```bash
omarchy plugin add https://github.com/acme/omarchy-weather.git --enable --yes
omarchy plugin update acme.weather      # fetch, show a diff, fast-forward
omarchy plugin list --json
omarchy plugin validate <folder>
```

Plugins land disabled so the code can be read first, and updates show a diff
before touching anything — because **plugins run unsandboxed inside
`omarchy-shell`**. By hand: drop the directory in place, then
`omarchy-shell shell rescanPlugins` and `omarchy plugin enable <id>`.

Two things this repo learned the hard way, both documented against `jonny.ports`
in [`../README.md`](../README.md):

- **Editing widget QML needs `omarchy restart shell`.** Upstream says saving
  under `~/.config/omarchy/plugins/` hot-reloads, and the log line appears, but
  an already-mounted bar widget is not re-instantiated. The edit looks like it
  did nothing.
- **`bar.shellQuote()` does not exist**, despite being listed beside `bar.run()`
  in the bar README. Quoting is `Util.shellQuote` on the `qs.Commons` singleton.
  Calling the documented one throws out of the click handler with nothing in the
  journal.

### Indicators — the `omarchy.indicators` cluster

The small state glyphs that stay hidden until the cluster is hovered:
`Dictation`, `ScreenRecording`, `Reminder`, `NightLight`, `Dnd`, `StayAwake`
(`shell/plugins/bar/indicators/`). Per-instance settings are `items` (a subset,
empty means all) and `alwaysShow`.

The *Dictation* glyph is one of these — voxtype status, installed with
`omarchy voxtype install`. Clicking it is not a TUI-launch surface; TUI
launching is the delivery mechanism from rung 2.

See the traps below before trying to add one.

### 5. Hooks — `~/.config/omarchy/hooks/<event>.d/`

One directory per event, any number of independent scripts, installed with
`omarchy hook install <event> <script>` (copies it in and marks it executable).
A flat `hooks/<event>` file, if present, runs first.

| Event | Fires | `$1` |
|---|---|---|
| `theme-set.d` | after `omarchy theme set` | theme slug |
| `font-set.d` | after a font change | font name |
| `post-boot.d` | after the desktop starts | — |
| `post-update.d` | during `omarchy update`, after packages and migrations | — |
| `pre-refresh-pacman.d` | before `omarchy refresh pacman` re-syncs | — |
| `battery-low.d` | on the low-battery warning | percentage |

This repo uses `theme-set.d/` twice, for the starship and omp theme bridges.

### 6. Themed templates — `~/.config/omarchy/themed/*.tpl`

The mechanism for making an app that knows nothing about Omarchy follow
`omarchy theme set`. Every `*.tpl` in that directory is rendered from the
theme's `colors.toml` into `~/.local/state/omarchy/current/theme/`, and the
`theme-set.d` hooks then run, which is where a rendered artefact gets copied or
signalled to wherever the app actually reads it.

The load-bearing detail: **a template is only rendered inside a theme
operation**. Editing a `.tpl` does nothing until `omarchy theme set` or
`omarchy-theme-refresh` runs — which is exactly what
`run_onchange_after_omarchy-themed.sh.tmpl` exists to do after a
`chezmoi apply` changes one.

Two shapes are possible. Keep a repo-managed base config that *loads* the
rendered artefact (nvim, omp), or make the whole config the artefact (starship,
which has no include directive). README's *Starship prompt* section covers why
that choice is forced rather than chosen.

### Themes — `~/.config/omarchy/themes/<name>/`

Either a whole new theme, or an overlay: drop one edited file (typically
`colors.toml`, or a single app's spec such as
`themes/gruvbox/neovim.lua` here) into a directory named after a stock theme and
re-apply. The user directory is read after the packaged one.

### Output surfaces — notifications and the OSD

Any script can render in the desktop's own visual language instead of inventing
a window:

```bash
omarchy notification send -g <glyph> -u critical "Build failed" "3 tests" \
  --exec foot -e less /tmp/build.log
omarchy osd -i <icon> -m "Recording" -p 60 -d 1500
```

`--exec` is what makes a notification an interactive surface rather than a
message — the notification becomes the button.

### Shell IPC — driving the running shell from outside

```bash
omarchy-shell shell ping
omarchy-shell shell toggle jonny.ports
omarchy-shell shell summon omarchy.menu '{"menu":"root"}'
omarchy-shell shell call <id> <method> <arg>
omarchy-shell shell listPlugins
omarchy-shell shell rescanPlugins
```

This is the seam that lets rungs 2 and 3 reach into rung 8: a plugin's popup
becomes summonable from a menu row or a keybind without the plugin knowing.
`omarchy-shell` only forwards to a running shell; it never starts one.

### Branding — `~/.config/omarchy/branding/`

`about.txt` and `screensaver.txt`, managed here. `omarchy branding about` and
`omarchy branding screensaver` edit, set or reset them.

## Two things that look extensible and are not

**Menu `provider` is a closed set.** The shipped `omarchy-menu.jsonc` comment
says a provider works when "a `provider_name` function or command named `name`
returns JSON rows", which reads like a plugin point. It is not. `Menu.qml`
holds a hard-coded `providers` map — `fonts` and `power-profiles`, each a bash
one-liner emitting `label\tvalue\tcurrent`, plus a QML-native `apps` — and
`startProviderForMenu` does `if (!spec) return` on anything else. An unknown
provider name is a silent no-op, not an error. Generate rows with `when` on
static rows, or with a `service`/`panel` plugin.

**Adding an indicator means owning the cluster.** `omarchy plugin clone
omarchy.indicators` does work, and works better than expected: the manifest's
`omarchy.clonePaths` copies the sibling `../indicators/` directory into the
clone and rewrites the relative path inside the copied QML. But the set of
indicators is the `defaultIndicatorEntries` array literal in `Indicators.qml`,
and the settings picker is a closed `options` list in the manifest, so a new
indicator means editing both — and then merging upstream's changes to the
cluster by hand forever. That is the same whole-file-copy tax this repo already
pays on `tmux.conf` and `foot.ini`. A one-glyph `type: "command"` bar module
next to the cluster costs nothing and survives updates.

## What this repo uses

| Surface | Here |
|---|---|
| Shell plugin (`bar-widget`) | `dot_config/omarchy/plugins/jonny.ports/` |
| Bar layout + idle | `dot_config/omarchy/shell.json` |
| Hooks (`theme-set.d`) | starship and omp theme bridges |
| Themed templates | `dot_config/omarchy/themed/{starship.toml,omp.json}.tpl` |
| Themes (overlay) | `dot_config/omarchy/themes/gruvbox/neovim.lua` |
| Branding | `dot_config/omarchy/branding/` |
| Hyprland override | `dot_config/hypr/input.lua` |
| Whole-file copies (no override point) | `dot_config/tmux/tmux.conf`, `dot_config/foot/foot.ini` |

Unused so far: menu rows, keybindings, command bar modules, `service` plugins,
`omarchy tui install` / `omarchy webapp install`.
