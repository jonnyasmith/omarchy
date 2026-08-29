# AGENTS.md

## What this repo is

The [chezmoi](https://www.chezmoi.io/) **source directory** for this machine —
not a plain symlink farm. `sourceDir = "~/dev/dotfiles"` in
`~/.config/chezmoi/chezmoi.toml`, so there is no `~/.local/share/chezmoi` clone
and `chezmoi` works from any cwd.

Editing a file here does **not** change the live system. `chezmoi apply` does.
Editing the live file under `~/.config/` does not change this repo either;
`chezmoi add <path>` restages it.

Naming: `dot_config/hypr/input.lua` → `~/.config/hypr/input.lua`.
`run_after_*` scripts execute on every apply. `.chezmoitemplates/` holds content
included by templates, never applied on its own.

`origin` is <https://github.com/jonnyasmith/omarchy.git> — public, hence rule 7.

## Docs

`README.md` is the per-item reference: one section per managed file, why it is
shaped that way, and the traps. Read the matching section before designing a
change; do not re-derive it. Its *Docs* heading also lists which extension
surface each managed file is standing on.

Background about the desktop rather than about a file here lives in the
`omarchy-extensions` skill, not in this repo — every place user functionality
can be added (menu rows, launchers, keybindings, bar modules, shell plugins,
indicators, hooks, themed templates, notifications, shell IPC), ordered cheapest
first, and the traps found by building them. See rule 1.

`.chezmoiignore` still lists `docs/`, which no longer exists: without an entry,
re-adding a docs directory would silently create `~/docs`.

## The machines

Two hosts share this source dir. Everything host-specific self-gates, so one
`chezmoi apply` is correct on both — read the gate before assuming a script ran.

| | `dell-xps` | `minisforum` |
|---|---|---|
| Chassis | Dell XPS 15 9500 laptop | Minisforum desktop, Ryzen AI 9 HX 370 |
| Distro layer | [Omarchy](https://omarchy.org/) 4.0.0-1 | Omarchy 4.0.1 |
| Fingerprint | Goodix `27c6:533c`, libfprint TOD driver | none — both fingerprint scripts exit 0 |
| Thermal/GPU | `run_after_xps15-thermal.sh` applies | DMI gate fails, no-op |
| Sleep | suspends normally (lid close) | `run_after_never-sleep.sh` masks every sleep target |

Common to both: Hyprland configured in **Lua** under `~/.config/hypr/`, the
Omarchy shell (Quickshell) driven by `~/.config/omarchy/shell.json`, and Arch.

Omarchy is an opinionated Arch + Hyprland distribution. It ships defaults in
`/usr/share/omarchy/` and loads user overrides from `~/.config/` **after** them,
so overrides are additive and only need the keys they change.

## Rules

1. **Read `skill://omarchy` before touching any desktop config** —
   `~/.config/hypr/`, `~/.config/omarchy/`, terminal configs, themes, hooks.
   It documents the `omarchy` CLI and the per-area topic guides. When the change
   *adds* functionality rather than adjusting existing config, read
   `skill://omarchy-extensions` first and say which rung you picked and why.
2. **Never write to `/usr/share/omarchy/`** by hand. It is package-owned and
   `omarchy update` wipes it. Reading it is encouraged — that is where the
   defaults you are overriding live. The one thing that *does* install there,
   the fingerprint skill guide, goes through
   `run_after_omarchy-fingerprint-skill.sh.tmpl` for exactly this reason.
3. **Two-step for desktop changes:** edit the live file, verify it works, then
   `chezmoi add` it. Verification on the real surface beats a staged diff.
4. **After any Hyprland Lua change:** `hyprctl reload && hyprctl configerrors`,
   and check the option actually took with `hyprctl getoption <path>`.
5. **Privilege escalation:** `pkexec` for agent-run commands (no terminal to
   type a password into), `sudo` only when a human is at an interactive shell.
6. Prefer an `omarchy` subcommand over hand-editing when one exists
   (`omarchy commands`, `omarchy <group> --help`).
7. **This repo will be public and work scans public repos for the company
   name.** No employer name, work email, work GitHub account, or client name
   may appear in any tracked file, comment, or commit message — not even in an
   example. They live in `~/.config/chezmoi/chezmoi.toml` as `workOrgs` /
   `workEmail`, reached only through `dot_config/git/config.local.tmpl` and
   `config.work.tmpl`. Write `ORG` in docs. Both templates render to zero bytes
   when `work = false`, and chezmoi deletes an empty target, so a personal
   machine ends up with `[include]`s pointing at nothing — which git ignores.
   Before committing: `git grep -i <company>` and check the diff.

## Reading `chezmoi status`

`status.exclude`/`diff.exclude` are `["scripts"]` in `~/.config/chezmoi/chezmoi.toml`,
so `chezmoi status` and `chezmoi diff` report files only. Without that, the two
unconditional `run_after_` scripts show as a permanent `R` (= "runs on next
apply", by design, not drift) and `diff` dumps their full bodies. `-x none`
restores them. Judge state by `chezmoi apply`, which is silent when there is
nothing to do.

First status column = actual vs. last state chezmoi wrote (drift on disk, fix
with `re-add`); second = actual vs. target (what `apply` will do). A file added
to this repo's root without a `.chezmoiignore` entry shows as ` A` — chezmoi is
about to create it in `~`.

## What is currently managed

See `README.md` for the per-item detail. Summary:

- `dot_config/hypr/input.lua` — Hyprland input overrides (Caps Lock ⇄ Escape).
- `dot_config/hypr/bindings.lua` — Omarchy's commented starter plus four
  bindings: `SUPER + ALT + A` opens the audio-output picker,
  `SUPER + ALT + P` the dev-ports picker, `SUPER + ALT + U` the USB-drive
  picker and `SUPER + ALT + L` the skills TUI (`S`, `K` and `A` were all
  taken; `L` is for "learn"). The description argument is what
  `omarchy menu keybindings` renders, so never omit it. It also moves window
  focus onto `SUPER + hjkl`, which needs `hl.unbind` on `J`/`K`/`L` first —
  their defaults (*Toggle window split*, *Keybindings*, *Toggle workspace
  layout*) were unused and got no new chord. The arrows stay bound as well, and
  `SUPER + SHIFT + hjkl` is left free for *Swap window*. See README.
- `dot_config/hypr/autostart.lua` — the login session layout: Chromium on
  workspace 1, `foot herdr` on workspace 2, focus left there. Placement is a
  per-launch `[workspace N silent]` exec rule, which survives the `uwsm-app`
  wrapper; only the terminal omits `silent`, so it wins focus.
- `dot_config/omarchy/extensions/omarchy-menu.jsonc` — the starter plus a
  *Plugins* container (a row with no `action` is a submenu; the parent comes
  from the dotted id) holding *Audio output*, *Dev ports*, *USB drives* and
  *Skills*. Every new personal tool is one `plugins.<name>` line; nothing goes
  on the root menu, which is Omarchy's and appends user rows to the bottom.
  Search and `aliases` still reach the children, so nesting costs nothing
  typed. Hot-reloads on save; `omarchy menu summon plugins` checks a change
  parsed without running a row.
  Glyphs are `\u` escapes: they are private-use codepoints and a literal one is
  easy to lose in transit.
- `dot_config/omarchy/shell.json` — the bar layout and the `idle` screensaver
  and lock timeouts. Every widget in it is now Omarchy's own; the one custom
  entry, `jonny.ports`, went when its bar widget was deleted, so the only local
  content is the widget order. There is no `omarchy bar remove`: dropping an
  entry means editing the file, then `omarchy restart shell`, which is also
  what any bar widget QML edit needs — a save alone is not enough.
- `dot_config/omarchy/plugins/jonny.audio/` +
  `dot_config/pipewire/pipewire.conf.d/50-raop-discover.conf` +
  `run_after_airplay-firewall.sh` — audio outputs: local PipeWire sinks and the
  HomePods and Apple TVs found over AirPlay, in one floating picker. `audio.sh`
  joins `pactl` sinks to Avahi model/address metadata; `audio-tui.sh` changes
  the default and moves streams already playing. `alt-t` tests one receiver;
  `r` restarts PipeWire to rebuild native discovery after an RTSP error. The
  native `create-stream` rule is load-bearing: Pulse compatibility discovery
  exposes selectable sinks but sends no sound. UDP 6001:6002 from the home
  `/24` is also load-bearing: ufw otherwise lets OPTIONS and ANNOUNCE pass, then
  SETUP hangs waiting for control/timing replies. A direct RTSP OPTIONS probe
  blocks a receiver returning 403 before it can strand the default on a dead
  sink; Apple Home must allow speakers to *Anyone on the Same Network* with no
  password. `pipewire-zeroconf` is installed by the packages script. See README
  before changing the discovery route, firewall rule or access probe.
- `dot_config/omarchy/plugins/jonny.ports/` — dev ports: which local servers
  are listening, labelled from `/proc/<pid>/cwd` rather than the useless
  process name. `ports.sh` does the scanning and runs standalone; `ports-tui.sh`
  (fzf, in a floating terminal that closes on selection) draws its TSV. No
  `manifest.json` and no QML: there was a `BarWidget.qml` drawing the same TSV
  for the mouse, and it was deleted as redundant, which took the port range and
  `https_ports` out of the `shell.json` entry and into the top of the picker.
  Container ports are named from `docker ps`, but only when `/run/docker.pid`
  already exists, so listing ports never wakes a sleeping daemon. Two hard-won
  rules for the picker: a custom TUI needs `--app-id=TUI.float` to float at
  all, and it must hand the browser launch to Hyprland (`hl.dsp.exec_cmd`)
  rather than run it, because a process that is about to exit cannot spawn one
  — see README.
- `dot_config/omarchy/plugins/jonny.usb/` — USB drives: format one, write a
  bootable ISO to one, or power one off for safe removal. `usb.sh` decides what
  a removable drive is (removable bit *or* USB transport, minus anything
  carrying a system mount) and prints TSV; `usb-tui.sh` is the fzf picker plus
  the three actions. No `manifest.json` — this is not a shell plugin, and the
  shell's scan skips a directory without one. Unmount, format and power-off go
  through udisks over D-Bus, which needs no password for a local session; only
  the image write and its read-back are `sudo dd`, because no unprivileged
  route into a raw block device exists from a shell. An image write is always
  verified by reading it back and `cmp`-ing it against the file, because
  `conv=fsync` only proves the drive *accepted* the bytes. Every destructive
  action is confirmed by typing the device name, and re-checks that nothing is
  mounted because `udiskie --automount` will have remounted it. Power-off has
  nothing to type, so it gets the extra list level format and write get from
  their filesystem and image menus, defaulting to *Keep it attached* — see
  README.
- `dot_config/omarchy/plugins/jonny.skills/` +
  `dot_config/omarchy/themed/skills-sync.env.tpl` + `run_after_skills-sync.sh`
  — agent skills: copy them out of the skills repos I follow into the one I own.
  Unlike the three above this is not a picker and holds no UI: everything
  visible is `skills-sync` (Go, `~/dev/skills-sync`, private), a Bubble Tea
  panel TUI that finds the skills tree in repos disagreeing about layout,
  classifies each skill `new`/`diverged`/`same`, shows the diff, and copies
  through a staging directory behind its own `Proceed?`. `skills.sh` is a
  launcher for the three things that binary must not know: this theme's palette
  (six `SKILLS_SYNC_*` variables, rendered by the template, sourced with
  `set -a`; every one optional, falling back to the ANSI indices the TUI had
  before), a missing binary (a notification, because a window that closes
  cannot carry an error), and the window closing on exit (the pause, which is
  unconditional because nothing distinguishes an abort from a sync). There was
  an fzf front end here for one evening, drawing a `-tsv` flag added for it; it
  was a subset of the Go TUI plus a parsing contract, and both are gone. Adding
  or forgetting a repo happens in the TUI's own left-hand panels. `run_after_`
  because the build is skipped by a `command -v` on every machine that has it,
  and `once_` state would never retry a failed build; it never clones, it
  prints the command. The binary's config (`~/.config/skills-sync/config.json`)
  names repo paths, so it stays unmanaged — rule 7. See README before changing
  the palette contract or the pause.
- `dot_config/omarchy/plugins/jonny.mdpreview/mdpreview.sh` +
  `dot_config/bash/mdpreview.sh` + `dot_config/nvim/lua/plugins/mdpreview.lua` —
  markdown preview: read a file, mermaid included, in a Chromium app window
  Hyprland tiles beside the terminal. `mdp` from a shell, `<Leader>mp` from
  Neovim, both calling the one script, so a document cannot look different
  depending on which side opened it. Alone among these tools it sits on no
  Omarchy rung: it needs a file path, and neither a menu row nor a chord can
  supply one. It is in the terminal nowhere because it cannot be — foot speaks
  sixel, herdr composites panes to a character grid with no sixel path, and the
  two do not overlap, so no image protocol reaches the screen from a pane.
  Rendering is `go-grip`, pinned in `dot_config/mise/config.toml` to a commit
  rather than a release because `frontmatter.Extract` landed after `v0.9.2` and
  57% of the markdown under `~/dev` is frontmatter-headed. Four load-bearing
  details: `uwsm-app` blocks until its unit exits so the server launch is
  backgrounded; one server per directory with the port discovered from
  `/proc/*/cmdline`, never hashed; `-b=false` because go-grip's own opener is a
  hard-coded `xdg-open`; and Chromium derives the app window's app_id itself
  (`chrome-<host>__<path>-<profile>`, ignoring `--class`), which is what makes a
  repeat `mdp` focus instead of duplicate. Reload is on `:w`, not on keystroke.
  See README before changing the port discovery, the pin or the app_id.
- `dot_config/omarchy/plugins/jonny.lib/vim-fzf.sh` — `vfzf`, the modal fzf the
  three fzf pickers source, so their keys cannot drift: normal mode by default,
  no input line at all, `j`/`k` move, `l` or enter opens, `h` goes back, `/`
  opens a search box, esc closes it. The footer is the mode line and changes
  with the mode. Sourced, not run, so no `executable_` prefix. Four things to
  know before editing it: `--no-input` is what frees bare letters to be keys;
  bare keys are unbound on entering search and rebound on leaving, from one
  list; esc is a `transform` on `$FZF_INPUT_STATE` because it means two
  different things; and `clear-query` must lead that chain from *outside* the
  transform, because an action list that hides the input discards a query
  change emitted after it — which leaves normal mode filtered with no visible
  input line. Back is `print(sentinel)+accept`, never `--expect` (which would
  capture the key in search mode too) and never `+abort` (which drops the
  output queue). Read the README section before changing any of it.
- `dot_config/omarchy/themed/fzf.env.tpl` — the fzf palette, rendered per
  theme and sourced by the three fzf pickers at launch, `FZF_THEME_RED`
  included for the USB picker's erase warning. No `theme-set.d` hook: the
  consumer reads the state dir directly. `skills-sync.env.tpl` beside it is the
  same rung for the Go TUI.
- `dot_bashrc` + `dot_config/blesh/init.sh` + `dot_config/bash/` — ble.sh (the
  zsh-autosuggestions equivalent), its settings, its fzf/zoxide integrations,
  and the aliases ported from the old zsh setup. Requires `yay -S blesh-git`;
  every reference is guarded. `dot_config/bash/*.sh` is glob-sourced, so a new
  file there needs no wiring. One of them, `denv.sh`, injects project secrets
  from 1Password with `op run` instead of a copy-pasted `.env`; it keys off the
  git remote so worktrees agree, and its per-repo templates live unmanaged in
  `~/.config/dev-env/` because an `op://` reference names the client (rule 7).
- `dot_config/herdr/config.toml` + `run_after_herdr-integrations.sh` — herdr,
  the terminal workspace manager, configured as a port of Omarchy's tmux config
  (`ctrl+space` leader included) plus the script that installs herdr's OMP
  lifecycle extension. OMP is the one agent herdr has no screen manifest for, so
  without that extension every OMP pane reports `idle` for its whole life and
  the sidebar's state dot never changes colour. The extension is herdr's file,
  not a managed one — it lands in `dot_omp/private_agent/extensions/`'s target
  directory, which is not `exact_`, so chezmoi leaves it alone. Diagnose with
  `herdr agent explain <pane_id>`. Only `config.toml` is managed under
  `~/.config/herdr/`; the session, lock, release-notes and log files there are
  runtime state. Read the README before adding an agent to the script's list.
- `dot_config/tmux/tmux.conf` — Omarchy's tmux config plus vim-direction pane
  focus keys (`Ctrl+Shift+h/j/k/l`) and the `extended-keys always` / `extkeys`
  settings those keys need to reach tmux at all. A whole-file copy, because
  Omarchy installs that path rather than layering an override, so upstream
  changes need merging by hand.
- `dot_config/foot/foot.ini` — Omarchy's foot config plus `alpha=0.9` in
  `[colors-dark]` (foot 1.27 deprecated plain `[colors]`). Also a whole-file
  copy, for the same reason as `tmux.conf`.
- `dot_config/omarchy/themed/starship.toml.tpl` +
  `dot_config/omarchy/hooks/theme-set.d/executable_starship-theme.hook` — the
  starship prompt. There is no `~/.config/starship.toml`: starship has no
  `include` and ignores a multi-path `STARSHIP_CONFIG` (1.26.0), so unlike the
  nvim and omp bridges the whole config must be the theme-rendered artifact.
  `omarchy theme set` renders it to
  `~/.local/state/omarchy/current/theme/starship.toml` and `dot_bashrc` exports
  `STARSHIP_CONFIG` at that path. No reload step: starship re-reads the file
  every prompt. The hook then renders the template a second time, because a
  theme installed from a git repo may ship its own `starship.toml`, which is
  staged first and makes the stock renderer skip the template entirely.
- `dot_config/nvim/` — the whole Neovim config: the AstroNvim v6 template, most
  of it still the shipped `if true then return {} end` stubs, plus the Omarchy
  theme bridge (`lua/plugins/omarchy.lua`, `all-themes.lua`, the `symlink_`
  entry pointing `theme.lua` at the current Omarchy theme, and
  `plugin/after/transparency.lua`), and `lua/remote_clipboard.lua`, loaded from
  `polish.lua`, which routes yanks over OSC 52 in tmux/ssh/herdr sessions so a
  copy lands on the machine being typed on. Omarchy's own starter installs to
  `/etc/skel/`, so this replaces it outright and `omarchy update` cannot clash.
  `dot_config/omarchy/themes/gruvbox/neovim.lua` overrides one theme's spec to
  match its `colors.toml`. The lock file is `create_lazy-lock.json` on purpose:
  lazy.nvim owns that file, so chezmoi seeds it only when absent and must never
  be allowed to overwrite it — do not drop the `create_` prefix.
- `dot_config/git/config` + `config.local.tmpl` + `config.work.tmpl` — git
  config, the one-letter aliases the bash `g*` aliases call, and the
  work-account routing: `insteadOf` rewrites the `github.com` remotes of every
  owner listed in `workOrgs` onto the `github-work` ssh alias, and `includeIf
  hasconfig` swaps in the work email. `workOrgs` holds owners, orgs or user
  accounts alike; an owner missing from it silently gets the personal key and
  the personal commit email. Renaming that alias means editing `~/.ssh/config`
  too.
- `dot_omp/private_agent/` + `dot_config/omarchy/themed/omp.json.tpl` +
  `dot_config/omarchy/hooks/theme-set.d/` +
  `run_onchange_after_omarchy-themed.sh.tmpl` —
  the Oh My Pi agent config, the custom status line and its `quota`/`context_pct`
  extension, and the Omarchy theme bridge: the template renders `colors.toml`
  into an omp theme on every `omarchy theme set` and the hook copies it into
  `~/.omp/agent/themes/`, which live-reloads running sessions. Never let
  anything but omp write `config.yml`.
- `.chezmoi.toml.tmpl` — the only prompts in the repo: `work`, `workOrgs`,
  `workEmail`, answered once at `chezmoi init` and stored in
  `~/.config/chezmoi/chezmoi.toml`. See rule 7.
- `private_dot_ssh/` + `dot_config/private_1Password/ssh/agent.toml` — ssh
  config with one 1Password-agent identity per host, the `private_*.pub` stubs
  it pins (0600 is load-bearing under OpenSSH 10), and the agent's own item
  list. No private key touches disk; the agent toggle is GUI-only.
  `private_authorized_keys` is the inbound half: the personal Ed25519 public key,
  the only credential that can ssh *into* either machine. `herdr --remote` uses
  the `<host>-herdr` alias, the only connection that `RemoteForward`s this
  machine's agent socket to a fixed path on the far end, so git in a pane prompts
  here rather than on a screen nobody is looking at. Plain `ssh minisforum`
  deliberately does not forward — it would steal that path and leave a dead
  socket. The `Match exec` block above `Host *` is what makes the far end use it,
  and both halves of its test matter. Read the README before touching any of it.
- `run_after_sshd-tailnet.sh` — enables `sshd` with a key-only drop-in and one
  `ufw allow in on tailscale0` rule, which is the only thing making port 22
  reachable. Reachability is deliberately ufw's job, not `ListenAddress`; read
  the README before changing that. Also sets `StreamLocalBindUnlink yes`, which
  the agent forward below needs to survive a re-attach.
- `run_after_locale.sh` — sets `LANG=en_GB.UTF-8` in both `/etc/locale.conf`
  (systemd, hence local sessions) and `/etc/environment` (pam_env, hence ssh
  and `herdr --remote` panes), generating `en_GB.UTF-8` first because Omarchy's
  installer ships a UK keymap on a US locale. Only `LANG`; read the README
  before adding `LC_COLLATE`.
- `.chezmoitemplates/omarchy/fingerprint.md` + its `run_after_` script — the
  canonical fingerprint topic guide, reinstalled into the package-owned agent
  skill tree after every `omarchy update` wipes it.
- `run_after_omarchy-fingerprint-pam.sh` — restores the fingerprint PAM stacks
  in `/etc/pam.d/`. Fails open by construction; read the README before editing.
- `run_after_portainer.sh` — writes `/opt/portainer/docker-compose.yml` and runs
  the Portainer container on http://localhost:9000. Gated on `docker info`, so
  it defers rather than fails before the `docker` group re-login.
- `run_after_never-sleep.sh` — masks the five sleep targets and drops *Suspend*
  from the system menu, so this box stays reachable over the tailnet from
  elsewhere. Gated on an allowlist of desktop DMI chassis types, so the XPS —
  and any machine whose firmware reports something unexpected — still suspends
  on lid close. Does not cover power loss (BIOS *Restore on AC Power Loss*) or
  a deliberate shutdown; read the README before editing.
- `run_after_xps15-thermal.sh` — caps RAPL package power to what this chassis
  can cool (PL1 45 W / 28 s, PL2 60 W, both domains, re-applied after resume)
  and enables PCIe runtime D3 plus the nvidia sleep units for the dGPU. Gated
  on the DMI product name; read the README before editing.
- `run_once_before_00-packages.sh` + `run_once_after_fingerprint-tod.sh` +
  `run_onchange_after_mise.sh.tmpl` — the bootstrap the repo used to leave as
  README prose: tailscale, `blesh-git` from the AUR and the `docker` group
  before any file lands, the TOD fingerprint driver for a reader stock libfprint
  cannot bind (gated on its USB ID, and the executable twin of the AUR block in
  `.chezmoitemplates/omarchy/fingerprint.md` — keep the two in step), and
  `mise install` for the pinned tool set. `once_` state is per machine in
  chezmoi's own database, so editing one re-runs it; every step is gated and
  idempotent because of that. Everything left needs a human present and is
  printed at the end of a run, never assumed — see README *New Machine*.
