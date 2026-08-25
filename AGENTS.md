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

No git remote is configured. Commits are local.

## The machine

| | |
|---|---|
| Host | `dell-xps`, Arch Linux |
| Distro layer | [Omarchy](https://omarchy.org/) 4.0.0-1 |
| Compositor | Hyprland, configured in **Lua** under `~/.config/hypr/` |
| Shell/bar | Omarchy shell (Quickshell), `~/.config/omarchy/shell.json` |
| Fingerprint | Goodix `27c6:533c`, proprietary libfprint TOD driver |

Omarchy is an opinionated Arch + Hyprland distribution. It ships defaults in
`/usr/share/omarchy/` and loads user overrides from `~/.config/` **after** them,
so overrides are additive and only need the keys they change.

## Rules

1. **Read `skill://omarchy` before touching any desktop config** —
   `~/.config/hypr/`, `~/.config/omarchy/`, terminal configs, themes, hooks.
   It documents the `omarchy` CLI and the per-area topic guides.
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
- `dot_config/omarchy/shell.json` — the bar layout and the `idle` screensaver
  and lock timeouts. Stock apart from the widget order and the `jonny.ports`
  entry. Bar widget QML edits need `omarchy restart shell`, not just a save.
- `dot_config/omarchy/plugins/jonny.ports/` — the dev-ports widget: which local
  servers are listening, labelled from `/proc/<pid>/cwd` rather than the useless
  process name, click a row to open it. `ports.sh` does the scanning and runs
  standalone; the QML only draws its TSV. Container ports are named from
  `docker ps`, but only when `/run/docker.pid` already exists, so drawing the
  bar never wakes a sleeping daemon.
- `dot_bashrc` + `dot_config/blesh/init.sh` + `dot_config/bash/` — ble.sh (the
  zsh-autosuggestions equivalent), its settings, its fzf/zoxide integrations,
  and the aliases ported from the old zsh setup. Requires `yay -S blesh-git`;
  every reference is guarded. `dot_config/bash/*.sh` is glob-sourced, so a new
  file there needs no wiring. One of them, `denv.sh`, injects project secrets
  from 1Password with `op run` instead of a copy-pasted `.env`; it keys off the
  git remote so worktrees agree, and its per-repo templates live unmanaged in
  `~/.config/dev-env/` because an `op://` reference names the client (rule 7).
- `dot_config/tmux/tmux.conf` — Omarchy's tmux config plus vim-direction pane
  focus keys (`Ctrl+Shift+h/j/k/l`) and the `extended-keys always` / `extkeys`
  settings those keys need to reach tmux at all. A whole-file copy, because
  Omarchy installs that path rather than layering an override, so upstream
  changes need merging by hand.
- `dot_config/foot/foot.ini` — Omarchy's foot config plus `alpha=0.9` in
  `[colors-dark]` (foot 1.27 deprecated plain `[colors]`). Also a whole-file
  copy, for the same reason as `tmux.conf`.
- `dot_config/omarchy/themed/starship.toml.tpl` — the starship prompt. There is
  no `~/.config/starship.toml`: starship has no `include` and ignores a
  multi-path `STARSHIP_CONFIG` (1.26.0), so unlike the nvim and omp bridges the
  whole config must be the theme-rendered artifact. `omarchy theme set` renders
  it to `~/.local/state/omarchy/current/theme/starship.toml` and `dot_bashrc`
  exports `STARSHIP_CONFIG` at that path. No hook: starship re-reads the file
  every prompt.
- `dot_config/nvim/` — the whole Neovim config: the AstroNvim v6 template, most
  of it still the shipped `if true then return {} end` stubs, plus the Omarchy
  theme bridge (`lua/plugins/omarchy.lua`, `all-themes.lua`, the `symlink_`
  entry pointing `theme.lua` at the current Omarchy theme, and
  `plugin/after/transparency.lua`). Omarchy's own starter installs to
  `/etc/skel/`, so this replaces it outright and `omarchy update` cannot clash.
  `dot_config/omarchy/themes/gruvbox/neovim.lua` overrides one theme's spec to
  match its `colors.toml`. The lock file is `create_lazy-lock.json` on purpose:
  lazy.nvim owns that file, so chezmoi seeds it only when absent and must never
  be allowed to overwrite it — do not drop the `create_` prefix.
- `dot_config/git/config` + `config.local.tmpl` + `config.work.tmpl` — git
  config, the one-letter aliases the bash `g*` aliases call, and the
  work-account routing: `insteadOf` rewrites a work org's `github.com` remotes
  onto the `github-work` ssh alias, and `includeIf hasconfig` swaps in the work
  email. Renaming that alias means editing `~/.ssh/config` too.
- `dot_omp/private_agent/` + `dot_config/omarchy/themed/omp.json.tpl` +
  `dot_config/omarchy/hooks/theme-set.d/` + its `run_onchange_after_` script —
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
- `.chezmoitemplates/omarchy/fingerprint.md` + its `run_after_` script — the
  canonical fingerprint topic guide, reinstalled into the package-owned agent
  skill tree after every `omarchy update` wipes it.
- `run_after_omarchy-fingerprint-pam.sh` — restores the fingerprint PAM stacks
  in `/etc/pam.d/`. Fails open by construction; read the README before editing.
- `run_after_portainer.sh` — writes `/opt/portainer/docker-compose.yml` and runs
  the Portainer container on http://localhost:9000. Gated on `docker info`, so
  it defers rather than fails before the `docker` group re-login.
- `run_after_xps15-thermal.sh` — caps RAPL package power to what this chassis
  can cool (PL1 45 W / 28 s, PL2 60 W, both domains, re-applied after resume)
  and enables PCIe runtime D3 plus the nvidia sleep units for the dGPU. Gated
  on the DMI product name; read the README before editing.
