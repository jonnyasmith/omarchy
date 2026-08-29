# dotfiles

[chezmoi](https://www.chezmoi.io/) source directory. `sourceDir` is set to this
repo in `~/.config/chezmoi/chezmoi.toml`, so no `~/.local/share/chezmoi` clone
is involved and `chezmoi` works from any working directory.

```bash
chezmoi apply          # Apply everything
chezmoi diff           # Preview pending changes
chezmoi status         # What is out of sync
chezmoi cd             # Subshell in this repo
chezmoi doctor         # Sanity-check the install
```

Both `run_after_` scripts are unconditional by design, so `chezmoi status` used
to list `R omarchy-fingerprint-pam.sh` and `R omarchy-fingerprint-skill.sh` on
every run and `chezmoi diff` printed their whole bodies. `R` means "this script
runs on the next apply", not drift, and the two permanent lines buried real
changes. `.chezmoi.toml.tmpl` now sets `status.exclude` and `diff.exclude` to
`["scripts"]`, so both commands report files only; the scripts still run on
every apply. Pass `-x none` to see them again.

Because this repo *is* the source directory, a file dropped in its root is read
as a source entry and applied to `~`. `.chezmoiignore` lists the ones that are
repo-local: `AGENTS.md`, `README.md`, `mise.toml`, and `docs/`. The last two are
pre-emptive. `mise use <tool>` without `-g` writes a project-local `mise.toml`
into the current directory, and run from here that file becomes a source entry
targeting `~/mise.toml` — use `mise use -g` to reach the global set in
`dot_config/mise/config.toml`. `docs/` no longer exists, and the entry stays so
that re-adding a docs directory cannot silently create `~/docs`.

## Docs

Everything below this section is per-item: one heading per managed file, why it
is shaped that way, and what breaks.

Background about the desktop rather than about a file here is not kept in this
repo any more. It lives in the `omarchy-extensions` skill
(`~/dev/skills/skills/omarchy-extensions/`), which covers where functionality
can be added to an Omarchy desktop, ordered cheapest first, and the traps that
only show up once you build one. Read it before adding desktop functionality —
picking a surface too low is the expensive mistake, and it is the one this repo
has already made once.

What this repo is standing on:

| Surface | Here |
|---|---|
| Menu row | `dot_config/omarchy/extensions/omarchy-menu.jsonc` — a *Plugins* container holding *Audio output*, *Dev ports*, *USB drives* and *Skills* |
| Keybinding | `dot_config/hypr/bindings.lua` — `SUPER + ALT + A`, `SUPER + ALT + P`, `SUPER + ALT + U`, `SUPER + ALT + L`, plus `SUPER + hjkl` window focus |
| Hooks (`theme-set.d`) | starship and omp theme bridges |
| Themed templates | `dot_config/omarchy/themed/{starship.toml,omp.json,fzf.env,skills-sync.env}.tpl` |
| Floating TUI, no plugin | `dot_config/omarchy/plugins/{jonny.audio,jonny.ports,jonny.usb,jonny.skills}/` |
| Shared picker library | `dot_config/omarchy/plugins/jonny.lib/vim-fzf.sh` — modal fzf, sourced by the three fzf pickers |
| Shell command + editor keymap (no desktop surface) | `dot_config/omarchy/plugins/jonny.mdpreview/` with `dot_config/bash/mdpreview.sh` and `dot_config/nvim/lua/plugins/mdpreview.lua` |
| Themes (overlay) | `dot_config/omarchy/themes/gruvbox/neovim.lua` |
| Branding | `dot_config/omarchy/branding/` |
| Hyprland overrides | `dot_config/hypr/{input,bindings}.lua` |
| Whole-file copies (no override point) | `dot_config/tmux/tmux.conf`, `dot_config/foot/foot.ini` |

Four of the five tools sit on the same two rungs: a searchable menu row and a
`SUPER + ALT` chord, each handing a shell script to a floating terminal. None
needs a manifest or QML. Three of those four *are* that shell script; *Skills*
is a launcher for a Go TUI, which is the same rung with a different tenant.
The fifth, markdown preview, is on neither rung, and deliberately: it needs a
file path to do anything, and neither a menu row nor a chord can supply one. Its
reach is an `mdp` shell function and an nvim keymap — the two places a path is
already in hand.
`jonny.ports`
used to be a full shell plugin as well — the most expensive rung — for a bar
widget with a per-row click popup. The keyboard picker replaced it outright:
the popup was a second implementation of a list you only ever want at the
moment you go to open a port, and the glanceable half never earned its cost.
Deleting it took the plugin back down to two scripts.

## New Machine

Four commands, of which only the first runs before chezmoi exists:

```bash
sudo pacman -S chezmoi                    # Omarchy does not ship it
chezmoi init --source ~/dev/dotfiles      # writes ~/.config/chezmoi/chezmoi.toml
chezmoi diff                              # review; files only, see above
chezmoi apply
```

`sourceDir` is non-default, so name it explicitly on that first `init` instead
of letting it pick `~/.local/share/chezmoi`; the config it renders restates
`sourceDir`, so every command after that works from any directory with no flag.
`init` clones only when it finds no git repo in the source directory, so
pointing it at an existing clone of this repo is safe. On a machine without the
clone, pass the remote and let it do both:
`chezmoi init --source ~/dev/dotfiles --apply <git-remote-url>`.

`init` is also the only thing that asks the three questions in
`.chezmoi.toml.tmpl`. To answer them without a prompt — a container, or an
unattended re-image — populate them on the command line instead:

```bash
chezmoi init --source ~/dev/dotfiles \
  --promptBool work=false --promptString workOrgs=,workEmail=
```

If pacman is not an option (another distro, or no root), chezmoi installs
itself and hands straight over:

```bash
sh -c "$(curl -fsLS get.chezmoi.io)" -- -b ~/.local/bin \
  init --source ~/dev/dotfiles --apply
```

Run the apply from a **graphical** session. Every privileged step in this repo
goes through `pkexec`, which needs the polkit agent to prompt with; over ssh
with no agent reachable those steps fail and the apply stops.

### What the first apply installs

`chezmoi apply` used to land files whose programs did not exist — the ble.sh
guard in `dot_bashrc` fell through to plain bash, the mise tool list stayed
empty, and `run_after_sshd-tailnet.sh` exited at `command -v tailscale`,
leaving port 22 shut. Three scripts close that gap:

| Script | Runs | Does |
|---|---|---|
| `run_once_before_00-packages.sh` | once per machine, before any file | `tailscale` and `pipewire-zeroconf` from the repos, `tailscaled.service`, `blesh-git` from the AUR, adds you to the `docker` group |
| `run_once_after_fingerprint-tod.sh` | once per machine, gated on the reader's USB ID | builds `libfprint-tod` and the matching TOD blob — the executable form of the AUR block in the fingerprint skill guide |
| `run_onchange_after_mise.sh.tmpl` | when `dot_config/mise/config.toml` changes | `mise install` for the pinned tool set |

`before_` on the packages script is load-bearing: ble.sh and tailscale have to
exist before the files that reference them and before the `run_after_` scripts
that gate on them, in the same apply. The other two are `after_` — the mise one
because it reads a file this apply writes, the TOD one so a multi-minute
`makepkg` never delays the file tree.

`once_` is keyed on each script's contents, per machine, in chezmoi's state
database rather than in this repo. So a failed step is retried on the next
apply, an edit here re-runs it deliberately, and every step is written to be
idempotent and gated for exactly that reason. To force a re-run without
editing:

```bash
chezmoi state dump | jq '.scriptState'                  # what has run
chezmoi state delete-bucket --bucket=scriptState        # forget all of it
```

Privileged steps use `pkexec` rather than `omarchy pkg add` / `omarchy pkg aur
add`, the wrappers rule 6 would otherwise point at: both hard-code `sudo`,
which needs a terminal to type a password into. For yay that means
`--sudo /usr/bin/pkexec`, which routes only its pacman half through polkit and
still builds unprivileged.

### What no script can do

Four things need a human, and the packages script prints the ones still
outstanding at the end of every run rather than assuming they happened:

| Step | Why it cannot be scripted | Until then |
|---|---|---|
| `tailscale up` | browser SSO | nothing reaches port 22 |
| 1Password → Developer → *Use the SSH agent* | GUI-only toggle | ssh has no key; no private key is on disk |
| log out and back in | group membership only reaches a process at login | `docker info` fails, so `run_after_portainer.sh` keeps deferring |
| `fprintd-enroll -f right-index-finger` then `fprintd-verify` | touches on the sensor | `run_after_omarchy-fingerprint-pam.sh` wires nothing — an enrolled finger is its guard |

The last two want one more `chezmoi apply` afterwards, which is when Portainer
starts and the fingerprint PAM stacks land. The first `nvim` launch syncs
lazy.nvim against `create_lazy-lock.json` on its own.

`~/.config/dev-env/` is the one thing left entirely by hand: `denv.sh` reads its
per-repo templates from there and they are unmanaged on purpose, because an
`op://` reference names a client (rule 7).

## Bash line editor

`dot_bashrc` loads [ble.sh](https://github.com/akinomyoga/ble.sh) — the bash
replacement for zsh's `zsh-autosuggestions` + `fast-syntax-highlighting`. It
brings inline history suggestions in grey, command-line syntax highlighting,
and a completion menu.

It is not in the official repos and is not installed by anything here:

```bash
yay -S blesh-git    # 0.4.0-devel; the 0.3.4 stable release predates bash 5.3
ble-update          # later, to refresh it
```

Every reference to it is guarded, so a machine without the package gets plain
Omarchy bash rather than a broken shell.

Load order in `dot_bashrc` is load-bearing:

1. `source /usr/share/blesh/ble.sh --noattach` — **before** Omarchy's rc,
   because starship and mise install `PROMPT_COMMAND` hooks that ble.sh has to
   see being registered.
2. `source "$OMARCHY_PATH/default/bash/rc"`.
3. `~/.config/bash/*.sh` — personal aliases, sourced after Omarchy's so they
   win.
4. `ble-attach` — last, once every hook exists.

`dot_config/blesh/init.sh` is ble.sh's own config (it looks for
`$XDG_CONFIG_HOME/blesh/init.sh` itself; nothing sources it). It holds only
departures from ble.sh's defaults: grey ghost text instead of a highlighted
block, red-on-default instead of red-background for an unknown command,
`Alt+;` / `Ctrl+;` / `Ctrl+Space` to accept a suggestion, `Esc` to dismiss it,
`Shift+Enter` for a literal newline, and
`complete_auto_complete_opts=syntax-disabled`.

`Alt+;` is the one that works in every layer, because it is plain `ESC ;` on
the wire. `Ctrl+;` needs a terminal keyboard protocol to be distinguishable at
all: foot sends it as `\e[27;5;59~` once ble.sh asks for `modifyOtherKeys`, and
tmux re-encodes it as `\e[59;5u` because `dot_config/tmux/tmux.conf` sets
`extended-keys always`.

Herdr needs the Kitty keyboard protocol specifically. It answers DA2 as a
generic xterm, so ble.sh picks `modifyOtherKeys`, which herdr ignores — it
only re-encodes a modified punctuation key for a pane that pushed `\e[>1u`,
and `Ctrl+;` otherwise arrives as a bare `;`. `init.sh` therefore rewrites
ble.sh's terminal identity to `kitty:23` on the `term_DA2R` hook, because that
identity is the only input to the protocol choice and ble.sh exposes no
override. The hook then has to call `ble/term/modifyOtherKeys/reset` itself:
`ble/term/DA2/notify` resolves the protocol from the xterm identity *before*
invoking `term_DA2R`, so without the second reset the first prompt of every
new pane stayed on `modifyOtherKeys` and only the second one — after a command
had run and the leave/enter pair around it re-resolved the method — accepted
the key. That is what "`Ctrl+;` works sometimes" was.

`complete_auto_complete_opts=syntax-disabled` restricts inline suggestions to
shell history, matching zsh.
ble.sh's extra `syntax` source guesses filenames *inside option clusters* —
with it on, typing `echo -lR` next to a `README.md` ghosts `EADME.md` and
Right-arrow inserts `echo -lREADME.md`. TAB completion is unaffected.

`dot_config/bash/ble-integrations.sh` re-imports fzf and zoxide through
ble.sh's patched `contrib/integration/*` versions. Omarchy's rc sources fzf's
stock `completion.bash`, which registers `complete -F _fzf_path_completion` for
a long list of commands and assumes readline is driving; ble.sh calls those
compspecs while building suggestions. The `fzf-menu` import additionally routes
the TAB completion menu through fzf, which is the `fzf-tab` equivalent. All are
`ble-import -d`, i.e. loaded in idle time after the first prompt.

## Bash aliases

`dot_config/bash/aliases.sh` is the port of the previous zsh setup's
`~/.config/zsh/aliases.zsh` and `os.zsh.tmpl` — git shortcuts, docker, `ls`
variants, deep `cd ..` chains, `gac`, `fa`. The template's macOS and
apt/dnf/nala branches are gone; this machine is Arch only.

Three of them deliberately shadow Omarchy defaults, since the file is sourced
after Omarchy's rc:

| Alias | Omarchy | Here |
|---|---|---|
| `h` | `herdr` | `history` — run `herdr` by name |
| `gcm` | `git commit -m` | `git cm`, same thing via the git alias |
| `ls` | `eza -lh …` | `lsd`, but only if `lsd` is installed; it is not, so eza stays |

Two were not ported as-is. `ip` was `dig +short myip.opendns.com` on macOS;
shadowing iproute2's `ip` on Linux breaks every network command, so the lookup
is `myip` and `ips` is `ip -brief address`. `gac` is a function rather than an
alias because bash has no `noglob`, and `gac fix the *.ts import` would glob
before the alias saw it.

The one-letter git aliases these call (`git a`, `git s`, `git l`, `git d`, …)
came over into `dot_config/git/config` in the same pass. Neither half is much
use alone.

## Project secrets (`denv`)

`dot_config/bash/denv.sh` replaces the copy-a-`.env`-file-into-place habit with
one wrapper around [`op run`](https://developer.1password.com/docs/cli/reference/commands/run):

```
denv pnpm dev              # stage dev (the default)
denv -s prod pnpm build    # stage prod
denv -k                    # which key this repo resolves to
denv -l                    # list templates, marking this repo's
denv -e                    # edit this repo's template
denv-check [stage]         # resolve every reference in every template
```

`op run` resolves `op://` references and hands the values to a subprocess only,
masked in stdout/stderr, so no secret is written to disk and there is nothing to
git-ignore. `~/.config/bash/*.sh` is glob-sourced by `dot_bashrc`, so the file
needs no wiring.

### The templates live outside the repo

In `$DENV_DIR` (default `~/.config/dev-env/`), **not** in the project and not in
this repo:

| File | Role |
|---|---|
| `_shared.tpl` | loaded first for every repo (optional) |
| `<key>.tpl` | the repo's own (required) |
| `<key>.<stage>.tpl` | stage-specific overrides (optional) |

`--env-file` may be repeated and the last file wins, so the three layers
compose. A template holds pointers, never values:

```
PUBLIC_API_URL=op://Dev/myapp-$APP_ENV/api_url
```

`op` substitutes `$APP_ENV` from the environment, which is why one template
covers every stage and switching stage is an argument rather than a file copy.
`.env.development` / `.env.production` stop existing.

Two reasons they stay out of the project: the teams on those repos do not use
1Password, so a committed template is noise they cannot act on; and an `op://`
reference names a vault and an item, which on a work repo means it names the
client — the rule 7 problem, one layer up. The generic wrapper is safe to keep
here because it hard-codes no repo, vault, or item. The map is
`~/.config/dev-env/`, which is deliberately unmanaged. Back its bodies up as a
1Password Secure Note, not as a file in this repo.

### Why the key is not the directory name

A git worktree has a different basename from its main checkout, and these repos
are worked in worktrees, so a directory-keyed lookup misses. `_denv_key` reads
`remote.origin.url` and takes the last path segment, percent-decoded for Azure
DevOps. That is stable across every worktree and clone of one repo. Falling
back, in order: the main worktree's directory via `git rev-parse
--git-common-dir`, then `$PWD`, so a scratch directory outside git still
resolves.

The consequence is that identity follows the repo, not the folder: `~/dev/dotfiles`
keys as `omarchy`, because that is what its origin is called. `denv -k` exists
so a missing template is a two-second diagnosis instead of a mystery.

### The one trap

A leftover `.env` in the project root is still loaded by Vite's dotenv (and most
other loaders) and beats anything injected into the environment. `denv` warns
when it sees one. Delete the file rather than silencing the warning.

### Prerequisite

`op` must be signed in, which on this machine means *1Password → Settings →
Developer → Integrate with 1Password CLI* — then the unlock is biometric and no
token is stored. It is not enabled yet, so `op whoami` fails; `denv` detects
that on a non-zero exit and says so rather than letting a dev server boot with
unresolved variables.

## Herdr

`dot_config/herdr/config.toml` configures [herdr](https://herdr.dev), the
terminal workspace manager Omarchy ships as `h`. The file is a deliberate port
of Omarchy's own tmux config (`config/tmux/tmux.conf`) — workspace/tab/pane map
onto tmux's session/window/pane, the theme rides the terminal palette, and the
`[ui]` block turns off the chrome tmux never drew (pane gaps, outer borders,
scrollbars, close confirmations).

`ui.status_indicators` is deliberately absent, which leaves it at herdr's
default `"dots"` — the compact colour marks. It was briefly `"symbols"`, whose
static per-state glyphs read as a dot that never changes and hid the fact that
nothing was reporting state at all. See *Agent state* below.

The leader is `ctrl+space`, not herdr's default `ctrl+b`, matching the
`set -g prefix C-Space` in `tmux.conf`. Consequence: `ctrl+space` no longer
reaches readline (`set-mark`) or a nested tmux inside a herdr pane.

Workspace switching also answers `alt+j` / `alt+k` alongside `alt+down` /
`alt+up`, so the motion keys match the vim-direction pane focus keys added to
`tmux.conf`. Nothing else in the file binds bare `alt` with a letter — tabs are
`alt+left` / `alt+right` — so the pair is free.

Only `~/.config/herdr/config.toml` is managed. The sibling files herdr writes
there — `session.json`, `.plugins.lock`, `release-notes.json`, the two logs —
are runtime state and stay out of the repo.

```bash
herdr config check          # validate the file
herdr server reload-config  # apply it to the running server, no restart
```

### Agent state (`run_after_herdr-integrations.sh`)

The coloured dot beside a workspace, tab and pane in the sidebar is the agent's
state — idle, working, blocked, done — and herdr takes it from exactly one
authority per agent. For most agents that authority is a screen manifest
bundled in the binary: herdr matches the live bottom of the pane buffer against
rules, so state works with nothing installed. **OMP has no manifest.** Its only
authority is the lifecycle extension `herdr integration install omp` writes to
`~/.omp/agent/extensions/herdr-omp-agent-state.ts`, and without it every OMP
pane reports `idle` for its whole life — no colour change, ever, however busy
the agent is.

That is what `run_after_herdr-integrations.sh` installs. It checks
`herdr integration status` on every apply and installs when the entry is
missing or `--outdated-only` lists it, because the version that matters is
herdr's and `herdr update` bumps it outside any apply.

The extension is *not* a managed file next to `statusline.ts`, even though it
lands in the same directory. Herdr rewrites it on upgrade, so a tracked copy
would pin an old one and fight the installer.
`dot_omp/private_agent/extensions/` is not an `exact_` directory, so chezmoi
leaves the file alone.

Only OMP is in the script's list. `herdr integration install` writes into the
agent's own config tree; for claude, codex and opencode that tree is unmanaged
here and those agents already have a working manifest, so their hooks would buy
only native session restore in exchange for an unmanaged write. Add an agent to
the list when that trade changes, not because its CLI is on PATH.

The hook loads when the agent starts, so a pane that was already running keeps
reporting whatever it reported before. Diagnose with:

```bash
herdr integration status         # per-agent: not installed / current (vN)
herdr agent list                 # live state per pane
herdr agent explain <pane_id>    # which authority decided it
```

`explain` is the one that answers this: `manifest: none` with
`fallback_reason: default_known_agent_idle_fallback` means nothing is reporting,
while `screen_detection_skip_reason: full_lifecycle_hook_authority` means the
extension is live.

## Tmux

`dot_config/tmux/tmux.conf` is Omarchy's own `config/tmux/tmux.conf` with two
departures. Because Omarchy copies that file into `~/.config/` rather than
layering an override on top of it, the managed copy is the whole file and future
upstream edits to it have to be merged in by hand.

Pane focus is `Ctrl+Shift+h/j/k/l` instead of `Ctrl+Alt+<arrow>`, matching the
vim direction keys.

Making `Ctrl+Shift+<letter>` arrive at all is the second departure. A terminal
cannot distinguish `Ctrl+Shift+l` from `Ctrl+l` in the legacy encoding — both
are the byte `0x0c` — so the key needs `modifyOtherKeys` or the Kitty keyboard
protocol:

```tmux
set -s extended-keys always
set -s extended-keys-format csi-u
set -as terminal-features ",xterm*:extkeys"
set -as terminal-features ",foot*:extkeys"
```

Three things there are load-bearing:

- `extended-keys` is a **server** option, so `set -s`. Omarchy sets it with
  `set -g`.
- `always`, not `on`. With `on`, tmux only forces the protocol when the program
  in the pane asks for it, so whether `Ctrl+Shift+h` works depends on what is
  running — ble.sh asks, most things do not.
- `extkeys` has to name the terminal's `TERM`. Omarchy declares it for
  `xterm-kitty` only, but `~/.config/foot/foot.ini` sets `term=xterm-256color`,
  so tmux never believed the terminal could do it.

The protocol is negotiated when a client attaches. Sourcing the file into a
running server is not enough for clients that are already attached — detach and
reattach, or `tmux kill-server`.

## Foot terminal

`dot_config/foot/foot.ini` is Omarchy's own `config/foot/foot.ini` with one
addition, `alpha=0.9` for a translucent background. Omarchy installs that path
instead of layering an override, so — as with `tmux.conf` — the managed copy is
the whole file and upstream edits have to be merged by hand. `diff
/usr/share/omarchy/config/foot/foot.ini ~/.config/foot/foot.ini` should show
only the alpha block.

The section it lives in is `[colors-dark]`, not `[colors]`. foot 1.27 split
colors into `[colors-dark]` / `[colors-light]` and warns
`deprecated: foot: [colors]: use [colors-dark] instead` on every start while the
old name is used. `alpha` is a key of those sections, so it is per-theme: a
`[colors-light]` copy would be needed as well before using
`color-theme-toggle` or `initial-color-theme=light`.

Colors themselves come from the `include=` on line 2,
`~/.local/state/omarchy/current/theme/foot.ini`, which `omarchy theme set`
rewrites. It is included before the local section, so nothing here fights it.

`foot --check-config` parses the file and reports deprecations and bad values
without opening a window. Running terminals do not reload; `omarchy restart
terminal` or a new window picks changes up.

## Starship prompt

`dot_config/omarchy/themed/starship.toml.tpl` is the prompt Omarchy's bash rc
initialises, rendered per theme (see below). `format` is a single explicit
string — os, user@host, directory, git branch, git commit, git state, git
status, git metrics — so every module Starship enables by default (language
versions, cloud contexts, `$cmd_duration`, …) is excluded by omission rather
than disabled one by one. The `$schema` key is inert at runtime; it buys
completion and validation in any editor with a TOML language server.

`$line_break` before `$character` puts the `❯` on its own line, leaving the
full terminal width for the command regardless of how long the path and branch
get. `add_newline` is left at its `true` default: that is the blank line
*above* the prompt.

`[os.symbols] Linux` is set to the *Arch* glyph, which looks like a mistake and
is not. Omarchy 4 installs its own `/etc/os-release` with `ID=omarchy`, and
starship's `os` module hands detection to `os_info` 3.15.0, which matches `ID`
against a fixed list of literals (`os_info/src/linux/file_release.rs:92-172`).
`ID_LIKE=arch` is never read — the string does not appear anywhere in either
source tree — and neither is `/etc/arch-release`. An unrecognised `ID` therefore
falls through to `Type::Linux`, not `Type::Unknown`, and `[os.symbols]` is keyed
by that enum (`src/configs/os.rs:15`), so there is no `omarchy` key to set.
Overriding `Linux` is the only lever. The cost is that a genuinely unidentified
Linux would also show the Arch glyph, which does not arise on one machine.
Bind-mounting an `ID=arch` os-release over the real one makes the same binary
and config emit `U+F303` unchanged, which is how the cause was confirmed.

`$git_state` is what makes a rebase visible — without it a detached mid-rebase
HEAD renders like any other branch. `$git_metrics` needs `disabled = false`
and is the one module here that can be slow, since it diffs the working tree
for the `+n`/`-n` line counts.

`$status` sits at the end of the top line rather than next to `❯`, so the
cursor line stays clean. It renders nothing as configured: the `status` module
is disabled by default and no `[status]` section enables it. That is how the
layout has always been — add `[status] disabled = false` if the exit code is
wanted, because `✗` says only *that* a command failed, never *which* code.

`[directory] read_only` is set to a nerd-font glyph because the default is the
emoji `🔒`. `truncate_to_repo = false` is what keeps the path absolute-ish
inside a repo instead of collapsing to the repo root, with
`truncation_length = 3` and `…/` doing the shortening instead.

`right_format` (sudo, jobs, battery, time) only exists thanks to ble.sh. Bash
has no RPROMPT, and `starship init bash` emits the right prompt solely inside
`if [[ ${BLE_ATTACHED-} ]]`, as `bleopt prompt_rps1`. On a machine without the
ble.sh package it silently disappears. That same init prefixes the value with
one newline per newline in `PS1`, so with `$line_break` the right prompt lands
on the `❯` row. `sudo` and `time` are off by default and no section enables
them here either, so `$jobs` and `$battery` are all that render — the same
behaviour the old zsh config had.

No `command_timeout`, so the 500 ms default applies. The git modules are the
only ones that can reach it, on a large repo.

### Why the whole file is a theme template

Starship follows `omarchy theme set` the way Neovim and omp do, but it cannot
use their shape. Both of those keep a repo-managed base config that *loads* a
generated theme file — `require` for `theme.lua`, a themes directory for
`omarchy-system.json`. Starship has no `include`, and as of 1.26.0 a
colon-separated `STARSHIP_CONFIG` list is treated as one filename and falls back
to stock defaults (the multi-file PR is unmerged). So there is no overlay: the
whole config has to be the rendered artifact.

Hence `dot_config/omarchy/themed/starship.toml.tpl`, and **no
`~/.config/starship.toml` at all**. `omarchy-theme-set-templates` substitutes
the `colors.toml` tokens into every user `.tpl` and writes the result to
`~/.local/state/omarchy/current/theme/starship.toml`; `dot_bashrc` exports
`STARSHIP_CONFIG` pointing there, before Omarchy's rc runs `starship init bash`.

No reload step, unlike the omp bridge: starship is a fresh process per prompt, so
the next prompt reads the new file. The export is guarded with `[[ -r ]]` because
a theme without a `colors.toml` is never rendered, and `STARSHIP_CONFIG` aimed at
a missing file gives the stock prompt with no error.

Only `[username]` and `[hostname]` set a colour explicitly, so those are the
only tokens in the template: `bold dimmed {{ green }}` and `bold {{ yellow }}`
for root. Every other module keeps its stock ANSI-name style, which already
follows the theme through `foot.ini`'s palette include — templating those would
add tokens without changing a pixel. `accent` is available for a hue outside the
16 ANSI slots, which this layout does not use; the renderer's `mix` function is
not, for the reason the next section gives.
One stock quirk, unchanged by the port: starship's style parser drops `bold`
when `dimmed` follows it, so `user@host` renders as SGR `2` alone. It did the
same with the ANSI name.

### Why a theme-set hook renders it a second time

`dot_config/omarchy/hooks/theme-set.d/starship-theme.hook` exists because a theme
installed from a git repo may ship its own `starship.toml`, and one does:
one-dark-pro added one in its commit `913d60c`, which `omarchy update` pulled in.
`omarchy-theme-set` stages every colour file such a theme ships into `next-theme/`
— `starship.toml` is not in its `INSTALLED_THEME_DENIED` list, correctly, since it
is colour and runs no code — and `omarchy-theme-set-templates` then skips any
`.tpl` whose output already exists. A theme's prompt therefore replaces this one
wholesale, silently. Deleting the file from the theme clone fixes it until the next
`omarchy update` pulls it back.

The hook runs after both steps and renders the template over the staged file, so
the prompt is this repo's whatever a theme ships. It resolves plain `{{ key }}`
tokens from the staged `colors.toml` through `omarchy-theme-color --all`, the same
source the stock renderer parses, and does *not* reimplement that renderer's `mix`
and gradient functions. A leftover `{{` aborts the write and keeps the last good
file rather than handing starship a config with a token in it — so a template that
starts using `mix` needs this hook extended, and says so on stderr if it does not.

`run_onchange_after_omarchy-themed.sh.tmpl` is keyed on every template this repo
owns and both hooks, and runs `omarchy-theme-refresh`, which re-renders and
re-fires the hooks without changing the background. That is what converges a
fresh machine or an edited template; every theme switch after that is the hook's
own job. A new `themed/*.tpl` must be added to that key list, or nothing renders
it until an unrelated template changes.

## mise global tools

`dot_config/mise/config.toml` is the global [mise](https://mise.jdx.dev/) tool
set — the one mise reads for every directory that has no closer config, and the
only mise file tracked here. Omarchy's bash rc already runs `mise activate`, so
nothing in this repo wires it up; `chezmoi apply` then `mise install` is the
whole restore path on a new machine.

| Tool | Pin |
|---|---|
| `azure-cli`, `claude`, `cmake`, `codex`, `gh`, `glow`, `go`, `hunk`, `oh-my-pi`, `opencode`, `uv`, `zig` | `latest` |
| `bun` | `1` |
| `dotnet` | `10`, `8` |
| `node` | `26`, `24`, `22` |
| `pnpm` | `11`, `10` |
| `python` | `3.14`, `3.13` |
| `go:github.com/chrishrb/go-grip` | `v0.9.3-0.20260825095842-3f5b3c9ef5d7` |

Runtimes are pinned to a major and listed newest-first — mise installs every
version in the list and treats the first as the default, so a project
`mise.toml` asking for an older major finds it already on disk. The CLIs float,
since they are self-contained binaries that are only useful current. Two of them
are registry aliases for a backend that installs from release assets rather than
from a version-managed tool source: `oh-my-pi` for `github:can1357/oh-my-pi`,
and `hunk` for `aqua:modem-dev/hunk`. The short name is always the one to use.
Spelling the backend out declares the same tool under a second name, and mise
installs it twice — `mise ls hunk` listed `aqua:modem-dev/hunk` and `hunk` side
by side until the long form was dropped and the orphaned install uninstalled.
`mise registry <name>` prints the backend a short name resolves to.

`go-grip` is the one entry pinned to a commit rather than a version, and it is
the only tool here spelled with its backend, because there is no registry short
name for it. It renders the markdown preview (see *Markdown preview* below), and
the reason for the pin is that the feature it was chosen for is not in a release:
`internal/parser.go` gained `frontmatter.Extract` after `v0.9.2`, and 57% of the
markdown under `~/dev` carries YAML frontmatter. On `v0.9.2` that frontmatter
renders as an `<hr>` and a heading full of raw YAML; on this commit it is a
table, the way GitHub does it. The pin is an exact pseudo-version rather than
`@main` on purpose — a branch would re-resolve on every `mise up` and quietly
swap the renderer. Revisit it when `v0.9.3` ships and drop back to `latest`.

`[settings] minimum_release_age = "7d"` is the counterweight to all that
floating: a `latest` resolved the day it ships is a supply-chain window, so mise
ignores any release younger than a week. It applies to every tool here,
including the `github:` backend behind `oh-my-pi`. `omarchy update` overrides it
for one run —
`omarchy-update-mise` calls `MISE_MINIMUM_RELEASE_AGE=0 mise up`, which is what
the `mup` alias does by hand.

### Why nothing here duplicates a pacman package

Omarchy pacstraps its own CLI set in
`/usr/share/omarchy/install/omarchy-base.packages` — `bat`, `btop`,
`fastfetch`, `fzf`, `jq`, `lazygit`, `nvim`, `ripgrep`, `starship`, `tmux`,
`zoxide`, `herdr`, and `mise` itself. None of those belong in this file, because
PATH resolves them inconsistently:

- `default/bash/init` runs `eval "$(mise activate bash)"`, which **prepends**
  the install directory of every installed mise tool. Interactive shells get the
  mise build.
- `default/bash/env-bootstrap` appends `~/.local/share/mise/shims` **after**
  `/usr/bin`, commented "so system binaries keep precedence". SSH commands,
  `bash -lc`, and everything the uwsm session launches get the pacman build.

Declaring a tool in both places means the terminal and the desktop session run
different builds of it, while Omarchy's shipped configs — `btop.conf`,
`starship.toml`, `lazygit/config.yml`, `tmux.conf`, and the `bat`/`fzf`/`zoxide`
aliases in `default/bash/aliases` — were written against the pacman versions. So
pacman owns what Omarchy ships and mise owns what it does not: language runtimes
and dev CLIs.

Wanting a newer build than Arch ships means removing the pacman package too, not
stacking both, so the two PATH orders cannot disagree. Three of them cannot be
removed at all: `jq` is a hard dependency of `omarchy`, `neovim` of
`omarchy-nvim`, and `python` of some fifty packages including `gdb` and `meson`.
The base list is only read by the ISO installer, so a package removed by hand
does not return on `omarchy update` — though a future migration could re-add it.

`mise up` bumps the floating ones and rewrites this file in place — it is the
live file that changes, so `chezmoi re-add ~/.config/mise/config.toml`
afterwards. Per-project `mise.toml` files stay with their projects and are not
managed here; note that plain `mise use <tool>` writes one into the current
directory, so global changes need `mise use -g`.

## Oh My Pi agent config

`dot_omp/private_agent/private_config.yml` → `~/.omp/agent/config.yml`, the
settings file for the `oh-my-pi` CLI that the same-named mise
entry installs. It holds only the keys that differ from the defaults: the
`nerd` symbol preset with the `pi` composer shape, both theme slots pinned to
the Omarchy-derived theme below, `anthropic/claude-opus-5:medium` as the default
model role, thinking blocks hidden, the startup update check off, and the custom
status line below. `setupVersion` is written by the tool's own first-run setup
and marks it as already done.

`statusLine.preset: custom` replaces the stock bar with an explicit segment
list — `pi model mode collab path git pr context_pct quota` on the left,
`session_name` on the right, `powerline-thin` separators. The segment options
are the non-defaults only: thinking level beside the model, the path
abbreviated to 40 columns, and branch plus staged/unstaged/untracked in git.
The `nerd` symbol preset is load-bearing here — the powerline separators and
the segment icons are Nerd Font glyphs, and every terminal config in this repo
sets JetBrainsMono Nerd Font.

`dot_omp/private_agent/extensions/statusline.ts` → `~/.omp/agent/extensions/`,
auto-discovered from the agent directory (no `extensions:` key needed), is what
supplies the two segments the stock bar has no equivalent for:

- `quota` is new: the active provider's 5h and 7d subscription windows with
  their reset wall-clocks, polled every two minutes off `fetchUsageReports`.
  The built-in `usage` segment covers the same ground but renders nothing until
  its report lands and never shows a reset time. Because the bar only repaints
  on activity, a refresh that completes while the session is idle asks for one
  by deleting an unset hook-status key.
- `context_pct` overwrites the built-in under the same id — keeping the id is
  what makes the status line compute context usage at all, since it skips that
  work unless a configured segment is `context_pct` or `context_total`. It
  prints tokens used with the percentage beside it, instead of the percentage
  alone.

`private_agent` and `private_config.yml` are `private_`, i.e. 0700/0600. The
extension is plain 0644 — it is code, not state. Nothing secret is in either
file, but the rest of `~/.omp/` — sessions, auth state — is not managed here
and does not belong in a public repo, so the tighter mode is the safer default
for a tree chezmoi creates. Anything else the tool writes under `~/.omp/` stays
untracked.

### Omarchy theme

Omarchy themes every TUI it ships from one `colors.toml` per theme:
`omarchy theme set` renders every `*.tpl` in `/usr/share/omarchy/default/themed/`
into `~/.local/state/omarchy/current/theme/`, then per-app setters and the
`theme-set` hooks push each rendered file where its app looks. Three files hook
omp into that pipeline:

- `dot_config/omarchy/themed/omp.json.tpl` — the omp theme, named
  `omarchy-system`, with every colour derived from `colors.toml` placeholders
  and `{{ mix a b n% }}`. User templates in `~/.config/omarchy/themed/` are
  processed before the packaged ones and win, so this is an override-safe
  location — against `/usr/share/omarchy/default/themed/`, at least. A file a
  theme itself ships is staged earlier still and beats both, which is what the
  starship hook exists to undo.
- `dot_config/omarchy/hooks/theme-set.d/executable_omp-theme.hook` — copies the
  rendered `omp.json` to `~/.omp/agent/themes/omarchy-system.json` on every
  theme switch. `omarchy-hook` runs hooks through `bash`, so the exec bit is
  decoration, but the stock hooks beside it are 755.
- `run_onchange_after_omarchy-themed.sh.tmpl` — the template only renders
  inside a theme apply, so a fresh machine and an edited template both need one
  `omarchy-theme-refresh`. Keyed on the hashes of the two files above, the two
  starship files and the two hookless templates (`fzf.env.tpl`,
  `skills-sync.env.tpl`), since every bridge converges the same way.

Omarchy already ships `pi.json.tpl` and `omarchy-theme-set-pi`, but they target
upstream `pi`: `~/.pi/agent/themes/` plus a `settings.json` theme key. omp is
the `can1357` fork — different agent dir, `config.yml`, and a schema with 15
colour tokens upstream lacks (`pythonMode`, `statusLineBg`, and the 13
`statusLine*` segment colours). Feeding omp the stock `pi.json` fails
validation on exactly those keys and silently falls back to the built-in `dark`
theme, so this template is a superset rather than a symlink.

Two details are load-bearing:

- The hook `cp`s over the target instead of `mktemp` + `mv`. omp watches
  `~/.omp/agent/themes/<current-theme>.json` and debounce-reloads it, so writing
  through the same inode re-colours **running** sessions on a theme switch; a
  rename would swap the inode out from under the watcher.
- `theme.dark` and `theme.light` both name `omarchy-system`. Nothing at runtime
  edits `config.yml` — omp owns that file and rewrites it itself, so a hook
  editing it would race the tool — and pinning both slots means omp's auto
  dark/light detection cannot pick the wrong theme when a light Omarchy theme is
  applied. Every colour is a `mix` toward `foreground`, so the template works in
  both modes.

A theme with no `colors.toml` renders nothing; the hook then leaves the previous
file in place and omp keeps the theme it has loaded.

## Neovim

`dot_config/nvim/` is the entire config, not an overlay on Omarchy's. The
`omarchy-nvim` package installs its LazyVim starter into
`/etc/skel/.config/nvim/`, which is only copied when a user account is created,
so `omarchy update` never touches the live config and replacing it wholesale
costs nothing. What is tracked here is the [AstroNvim v6
template](https://github.com/AstroNvim/template) plus a bridge that keeps
Omarchy's theme switching working against AstroNvim instead of LazyVim.

Most of the tree is the template as it shipped. `lua/community.lua` and
`lua/plugins/{user,astrocore,astroui,astrolsp,mason,none-ls,treesitter}.lua`
all still open with `if true then return {} end`, and `dot_config/nvim/README.md`
is still the template's own readme. They are tracked verbatim so the commented
examples stay to hand; none of them affect a running nvim. Six files do the
work:

- `lua/plugins/symlink_theme.lua` is a chezmoi `symlink_` entry, so the live
  `lua/plugins/theme.lua` points at
  `~/.local/state/omarchy/current/theme/neovim.lua`. `omarchy theme set`
  rewrites that path, lazy's change detection notices the symlink target moved
  and fires `LazyReload`.
- `lua/plugins/omarchy.lua` adapts what Omarchy writes there. The spec is
  LazyVim-shaped — the theme's colorscheme plugin plus
  `{ "LazyVim/LazyVim", opts = { colorscheme = ... } }` — so this file disables
  the `LazyVim/LazyVim` entry, hands the colorscheme to AstroUI at startup, and
  reapplies it live from a `LazyReload` handler. The handler force-reloads the
  colorscheme plugin rather than trusting lazy's cache, because two themes can
  share one plugin (every generic Omarchy 4 theme sits on `aether.nvim`) and
  lazy will not rerun `setup()` with the new theme's opts otherwise.
- `lua/plugins/all-themes.lua` registers every theme's colorscheme plugin as
  `lazy = true`, so a theme switch never has to clone. Names and branches must
  match Omarchy's generated spec exactly; the file's comments record what
  mismatches cost.
- `plugin/after/transparency.lua` strips `bg` from a list of highlight groups so
  the terminal's own translucency shows through. Every theme apply re-sources
  it, since a colorscheme resets those groups.
- `lua/polish.lua` is the template's last-in hook, activated only to call
  `require("remote_clipboard").setup()`.
- `lua/remote_clipboard.lua` installs a `vim.g.clipboard` provider when the
  session's yanks may have to reach another machine — `$TMUX`, `$SSH_TTY` /
  `$SSH_CONNECTION`, or a `herdr` ancestor process. Copies go to the local
  Wayland clipboard when there is a display *and* out as OSC 52, which the
  multiplexer or terminal turns into a clipboard write on the machine being
  typed on. Paste reads `wl-paste` when a display exists, otherwise replays
  what this session last copied: herdr and most terminals refuse OSC 52
  *reads*, and asking costs a ten-second block and a warning. A plain local
  session installs nothing, leaving neovim's own wl-copy detection in charge.

A colorscheme is normally a name, but some themes (`azure-glow` here) put a
function on `opts.colorscheme` that sets highlight groups directly. LazyVim
calls such a function; AstroUI only accepts a name. `omarchy.lua` handles both:
a name goes to AstroUI, a function is called directly after a `highlight clear`,
at `VimEnter` on startup and in the `LazyReload` handler on a live switch.

`dot_config/omarchy/themes/gruvbox/neovim.lua` is the one per-theme override,
and it is Omarchy's own user-theme mechanism rather than anything nvim-specific.
Omarchy's `gruvbox` `colors.toml` is really the gruvbox-material palette
(fg `#d4be98`), but its shipped spec loads classic `ellisonleao/gruvbox.nvim`
(fg `#ebdbb2`), so every other TUI disagreed with nvim. The override swaps in
`sainnhe/gruvbox-material`, whose defaults match `colors.toml` exactly.

### The lock file is `create_`

`create_lazy-lock.json` uses that prefix deliberately. lazy.nvim rewrites
`lazy-lock.json` on every `:Lazy update`, so a plain managed file would give one
target two owners: every plugin update would report as drift, and `chezmoi
apply` would roll the installed plugins back to whatever commit this repo
pinned. `status.exclude` cannot suppress that — it selects entry types, not
paths.

`create_` inverts the authority. chezmoi writes the file only when the target is
absent and never diffs or overwrites an existing one, so a new machine still
lands on a plugin set known to work, the pin stays in git history for rollback,
and day-to-day updates are silent. The trade is that the baseline only moves on
a deliberate `chezmoi re-add`, so expect it to lag.

## Hyprland input

`dot_config/hypr/input.lua` is the user-side Hyprland input override, loaded
after Omarchy's defaults. It sets
`kb_options = "caps:swapescape,shift:both_capslock_cancel"`, swapping Caps Lock
and Escape. This drops Omarchy's default `compose:caps`, so Caps Lock is no
longer the Compose key. Use `caps:escape` instead if Escape should not become
Caps Lock.

Validate after `chezmoi apply` with `hyprctl reload && hyprctl configerrors`.

## Window focus on `hjkl`

`dot_config/hypr/bindings.lua` moves *Focus on left/below/above/right window*
onto the vim home row. Omarchy binds those four to `SUPER + arrows` in
`/usr/share/omarchy/default/hypr/bindings/tiling.lua:15-18`; user files load
after the defaults, so the override is three `hl.unbind` calls and four
`o.bind`s, and no package file is touched.

```lua
hl.unbind("SUPER + J")
hl.unbind("SUPER + K")
hl.unbind("SUPER + L")

o.bind("SUPER + H", "Focus on left window", hl.dsp.focus({ direction = "l" }))
```

**The unbinds are not optional.** Hyprland keeps both binds for a key and the
first one registered wins, so an `o.bind` without the matching `hl.unbind` is a
silent no-op. `SUPER + H` was the only one of the four already free; the three
it displaced were *Toggle window split* (`SUPER + J`), *Keybindings*
(`SUPER + K`) and *Toggle workspace layout* (`SUPER + L`). None was in use, so
none got a new chord — the keybindings menu is still on the Omarchy menu, and
the other two are one `hyprctl dispatch` away.

The arrows are deliberately **left bound**. They are Omarchy's defaults, they
cost nothing to keep, and two routes to one dispatcher is not a conflict.

`SUPER + SHIFT + hjkl` is deliberately still free. That is where *Swap window*
(`tiling.lua:39-42`) goes if the focus row earns a second row. Do not spend it
on a displaced default. The rows below it are **not** available: `SUPER + CTRL`
holds *Hardware menu* (`H`), *Herdr keybindings* (`K`) and *Lock system* (`L`),
and `SUPER + ALT` holds the *Skills* picker (`L`) and *Tmux keybindings* (`K`).

Verify with `hyprctl reload && hyprctl configerrors`, then
`omarchy menu keybindings --print | grep 'Focus on'` — four `SUPER + <letter>`
rows and four `SUPER + <arrow>` rows. Testing the actual keystroke needs a
human finger: injecting `SUPER + H` with `wtype` fires inconsistently here, and
it fails the same way on the untouched arrow binds, so it proves nothing either
way. To check the dispatcher rather than the key, run
`hyprctl dispatch 'hl.dsp.focus({ direction = "l" })'` with two tiled windows.

## Login session layout

`dot_config/hypr/autostart.lua` opens the two windows every session starts
with: Chromium on workspace 1, and a `foot` running
[herdr](https://herdr.dev) on workspace 2, which is left focused.

```lua
o.exec_on_start("[workspace 1 silent] " .. o.launch("chromium"))
o.exec_on_start("[workspace 2] " .. o.launch("foot herdr"))
```

`o.exec_on_start` is Omarchy's wrapper for `hl.on("hyprland.start", ...)`, so
these run once per Hyprland start, not on `hyprctl reload`.

The `[workspace N ...]` prefix is a Hyprland *exec rule*: the window the
launched pid maps to is placed on that workspace. It keeps working through the
`uwsm-app --` wrapper `o.launch()` adds, even though the app ends up in a
systemd scope — verified with
`hyprctl dispatch 'hl.dsp.exec_cmd("[workspace 9 silent] uwsm-app -- foot")'`.
Note the dispatch syntax: Hyprland's `hyprctl dispatch` takes Lua now, so the
old `hyprctl dispatch exec '[workspace 9] foot'` form is a parse error.

`silent` places the window without following it, so only the terminal — which
deliberately omits `silent` — decides where focus lands. Reverse the two lines
and focus would settle on workspace 1 instead.

A persistent `o.window({ class = "chromium" }, { "workspace 1" })` rule would
also place the browser, but it would pin *every* future Chromium window there.
The exec rule applies to this one launch only.

Nothing here is testable without logging out; to rehearse it, run the same two
strings through `hyprctl dispatch 'hl.dsp.exec_cmd("...")'` against a scratch
workspace.

## Stay awake

Omarchy already ships this, so nothing here is custom code. The `omarchy.idle`
shell service owns the flag at
`~/.local/state/omarchy/indicators/stay-awake`, `omarchy-toggle-idle` flips it,
the menu has a *Stay Awake* row, and `StayAwake` is one of the bar's built-in
indicators. "Awake" means only that the screensaver at `idle.screensaver` and
the lock at `idle.lock` are suppressed; there is no suspend-on-idle to
suppress, and lid close belongs to logind and ignores the flag entirely.

Nothing about it is configured here. `StayAwake` sits in the `omarchy.indicators`
cluster in the centre of the bar, where an inactive indicator stays hidden until
the cluster is hovered and an active one is always shown. There was a custom
`jonny.caffeine` widget and script here for timed sessions and a lid-close
inhibitor; both were dropped, because on and off is the whole requirement.

`dot_config/omarchy/shell.json` is managed anyway, because that is where the
bar layout and the `idle` timeouts live. Every widget listed in it is now
Omarchy's own — the one custom entry, `jonny.ports`, went with its widget — so
the only local content is the order. The shell rewrites this file itself
whenever the bar is reordered by dragging or by `omarchy bar move`, so expect
it to drift; re-`chezmoi add` after deliberate layout changes. There is no
`omarchy bar remove`: taking an entry out means editing the file, and the
widget only disappears once `omarchy restart shell` has run.

## Menu extensions

`dot_config/omarchy/extensions/omarchy-menu.jsonc` holds one container and one
row per personal tool:

```jsonc
"plugins":       {"icon":"\uf12e", "label":"Plugins"},          // no action ⇒ submenu
"plugins.ports": {"icon":"󰒍", "label":"Dev ports",  "action":"…"},
"plugins.usb":   {"icon":"\uf287", "label":"USB drives", "action":"…"},
"plugins.audio": {"icon":"\uf028", "label":"Audio output", "action":"…"},
```

- **The parent is inferred from the dotted id.** A row with no `action` is a
  submenu, so `plugins` is the whole container and every future tool is one
  `plugins.<name>` line with nothing else to wire.
- **Why not the root menu.** User rows are merged *after* Omarchy's, so each
  one lands at the bottom of a list that is Omarchy's own — fine for one, wrong
  by three. Nesting costs nothing typed: search reaches into submenus, so
  `SUPER + SPACE` then "port" still lands on the picker, and `aliases` keep
  `omarchy menu summon usb` working from the old flat id.
- **Glyphs are `\u` escapes**, not literal characters. Nerd Font glyphs are
  private-use codepoints and every hop — editor, clipboard, terminal — is a
  chance to drop one silently. `\uf12e` is the puzzle piece on the container.
- **It hot-reloads on save**; `omarchy menu summon plugins` is the fast check
  that a change parsed, and it opens the submenu without running anything.
  Summoning a *leaf* runs that row's action, which is a slower way to find out.

The chords in `dot_config/hypr/bindings.lua` bypass the menu entirely and run
the same command, so nothing depends on where a row sits.

## Modal fzf

`dot_config/omarchy/plugins/jonny.lib/vim-fzf.sh` — one `vfzf` function, sourced
by the three fzf pickers, that makes fzf behave like a vim buffer: **no input line
at all until you ask for one**. Bare `j`/`k` move, `l` opens, `h` goes back, and
`/` turns the list into a search box that `esc` closes again.

| Normal mode | | Search mode | |
|---|---|---|---|
| `j` / `k` | move | type | filter |
| `g` / `G` | first / last row | `ctrl-j` / `ctrl-k` | move |
| `ctrl-d` / `ctrl-u` | half page | `enter` | open |
| `l` or `enter` | open, or a level down | `esc` | back to normal mode |
| `h` | a level up | | |
| `/` | search | | |
| `q` or `esc` | quit | | |

The footer is the mode line: it lists the keys that work *now*, and changes
with the mode, so nothing has to be remembered or guessed. Each caller adds its
own fragment to it (`r rescan`, `alt-enter browser tab`) and says whether `h
back` is a lie at that level.

fzf has no notion of a mode, so this is five specific mechanisms:

- **`--no-input` is the whole trick.** It hides the input line *and* stops
  keystrokes reaching the query, which is what frees bare letters to be bound
  as commands; `show-input` brings it back for `/`. Without it, `j` types a `j`.
- **Bare keys are `unbind`-ed on entering search and `rebind`-ed on leaving
  it**, from a single list, so a key added to normal mode cannot be left typing
  itself into a search. Chords — `ctrl-j`, `ctrl-k`, `alt-enter` — stay bound in
  both modes, which is what makes movement possible *while* filtering.
- **`esc` has to mean two things**, so it is a `transform` that reads
  `FZF_INPUT_STATE`: `hidden` means normal mode, so quit; anything else means
  search mode, so return to normal.
- **`clear-query` must lead that chain, outside the transform.** An fzf action
  list that hides the input silently discards a query change emitted after it —
  in either order, tested on 0.74.3. Get this wrong and normal mode is still
  filtered by a pattern with no visible input line to explain why, which looks
  exactly like a list that has lost half its rows.
- **Going back is `print(sentinel)+accept`, not `--expect`.** `--expect`
  captures its key in *both* modes, so `--expect=h` would stop `h` ever being
  typed into a search. `print` needs `accept` rather than `abort`: abort throws
  the output queue away, so the sentinel never arrives. The tag is read back off
  stdout because a function at the far end of a pipe, inside a command
  substitution, cannot set a variable its caller will ever see.

Left alone deliberately: `ctrl-c` and `ctrl-g` still abort, because every
terminal user has that reflex; and Backspace is `0x7f` while `ctrl-h` is `0x08`,
so binding `h` never steals it from the query line.

`gg` is not a chord — fzf has no key sequences — but pressing `g` twice lands on
the first row anyway, so the muscle memory survives. `i` is not bound: there is
nothing to insert into a list.

## Audio outputs

`SUPER + ALT + A`, or *Audio output* under *Plugins*, opens one modal picker
for local PipeWire sinks, HomePods and Apple TVs:

| Path | What |
|---|---|
| `dot_config/pipewire/pipewire.conf.d/50-raop-discover.conf` | loads native AirPlay discovery with the required sink-creation rule |
| `run_after_airplay-firewall.sh` | admits RAOP control and timing replies on UDP 6001:6002 from the home LAN |
| `dot_config/omarchy/plugins/jonny.audio/executable_audio.sh` | joins PipeWire sinks to Avahi model/address metadata and prints TSV |
| `dot_config/omarchy/plugins/jonny.audio/executable_audio-tui.sh` | selects the default sink, moves streams already playing, tests and rescans |
| `dot_config/omarchy/plugins/jonny.lib/vim-fzf.sh` | the same modal keys as the other pickers |
| `dot_config/omarchy/extensions/omarchy-menu.jsonc` | the *Audio output* row, searchable as audio, AirPlay, HomePod or speakers |
| `dot_config/hypr/bindings.lua` | `SUPER + ALT + A` opens the picker |

`pipewire-zeroconf` supplies `libpipewire-module-raop-discover`; Avahi is already
running on Omarchy. Discovery must load as a native PipeWire module with an
explicit `create-stream` action. The PulseAudio compatibility module exposes
the same sink names, so the picker looks correct, but it does not create a
usable HomePod session: applications play and no sound leaves the machine.

`r` restarts `pipewire.service`, which reloads native discovery and rebuilds
every RAOP sink from Avahi's cache. PipeWire Pulse and WirePlumber reconnect to
PipeWire's systemd socket. The rebuild matters because `module-raop-sink`
destroys one receiver sink after an RTSP failure and discovery does not recreate
it while the same mDNS record remains present.

Enter sets the selected sink as default **and moves every existing sink input**.
Setting the default alone only affects applications that start playing later.
`alt-t` sends the freedesktop test sound directly to the highlighted sink. `r`
rebuilds every AirPlay sink from Avahi's cache.

### UDP replies must pass the firewall

RAOP's RTSP connection is outbound, but its UDP setup advertises this machine's
`control_port=6001` and `timing_port=6002`. HomePod sends setup traffic back to
those ports. With ufw's default incoming policy, `OPTIONS` and `ANNOUNCE` both
return 200, then `SETUP` hangs forever: the sink is selected and receives an
application stream, but no sound plays.

`run_after_airplay-firewall.sh` permits only UDP 6001:6002 from
`192.168.86.0/24`, this house's LAN. It does not expose them on other private
networks when the laptop travels. A working trace reaches `SETUP 200`,
`RECORD 200`, then one `POST /feedback` every two seconds.

### HomePod access is an Apple setting

The speakers can advertise `_raop._tcp` and appear in PipeWire while still
rejecting Linux. Current HomePod firmware returns `RTSP/1.0 403 Forbidden` to
the first `OPTIONS` request when Home access is restricted. PipeWire then
removes the sink, while `pw-play` still exits zero; a visible row is therefore
not proof that audio can play.

The picker probes that endpoint before changing the default. A rejection leaves
the working local output untouched and points to the setting:

**Apple Home → Home Settings → Speakers & TV → Anyone on the Same Network**,
with **Require Password** off.

That setting applies to every HomePod in the home. Linux cannot perform initial
HomePod setup, Bluetooth is not an audio route, and this is one receiver at a
time rather than AirPlay 2 multi-room grouping.

## Dev ports

A list of the local dev servers that are actually listening, labelled by the
project each one was started from, one keystroke from opening in the browser.
`SUPER + ALT + P`, or *Dev ports* under *Plugins*.

| Path | What |
|---|---|
| `dot_config/omarchy/plugins/jonny.ports/executable_ports.sh` | the whole scan; usable on its own |
| `dot_config/omarchy/plugins/jonny.ports/executable_ports-tui.sh` | the picker, an fzf front end on that scan |
| `dot_config/omarchy/plugins/jonny.lib/vim-fzf.sh` | the modal keys, shared with the USB picker |
| `dot_config/hypr/bindings.lua` | `SUPER + ALT + P` opens the picker |
| `dot_config/omarchy/extensions/omarchy-menu.jsonc` | the *Dev ports* row, under *Plugins* |

Those last two files are managed for one entry each; they are otherwise
Omarchy's own commented starter files. See *Menu extensions* above for why the
row is not on the root menu.

There was a bar widget too — a `manifest.json` and a `BarWidget.qml` making
this a full shell plugin, with a popup of per-row click targets. It is gone,
along with its `jonny.ports` entry in `shell.json`. Two front ends on one TSV
was one too many: the list is only interesting at the moment you go to open a
port, which is the moment you have already pressed the chord, and a glanceable
count of listening servers was never worth a QML component, a scan on a timer
and a second set of gestures to remember. Removing a widget is three steps —
delete the two files, delete the `shell.json` entry (there is no
`omarchy bar remove`), then `omarchy restart shell`, because the running shell
keeps a mounted widget alive through a plugin rescan.

```bash
~/.config/omarchy/plugins/jonny.ports/ports.sh          # 3000-9999
~/.config/omarchy/plugins/jonny.ports/ports.sh 1024 65535
```

It prints one TSV row per port — `port`, label, detail — and the picker only
draws that. Everything awkward lives in the script, where it can be run and
diffed on its own.

`ss -ltnpH` is the only source that sees every listener, container or not,
with no privilege and no Docker daemon. What it cannot do is name them: a Vite
server reports as `node-MainThread`, which tells you nothing when two projects
are up. So the label comes from the process's own
`/proc/<pid>/cwd` instead — the project directory is the thing you recognise —
with `/proc/<pid>/cmdline` as the detail line. That only works for processes we
own. A container's port belongs to root, so those names come from `docker ps`,
and only when `/run/docker.pid` already exists: `docker.service` here is
socket-activated and disabled, and listing ports is not a good enough reason to
wake it.

Three details that are easy to get wrong:

- **One port, two sockets.** IPv4 and IPv6 binds are separate `ss` rows. The
  first labelled row for a port wins and the rest are dropped, or portainer
  shows up twice.
- **Always `localhost`, never the bound address.** Vite binds `[::1]` only, so
  a URL built from the observed address as `127.0.0.1:5173` is a dead link.
- **A socket has no scheme.** `ss` cannot tell you that a port wants https, so
  ports that do are named in `https_ports` at the top of `ports-tui.sh`. That
  list, and the `3000`–`9999` default window that keeps `:53` and `:631` out,
  used to be read out of the widget's `shell.json` entry with `jq` so the two
  surfaces could not disagree. With one surface left they are plain variables
  in the script; the range is still overridable per run
  (`ports-tui.sh 1024 65535`).

The picker: `SUPER + ALT + P`, `j`/`k` to the row, `l`, and the terminal it ran
in closes behind it. It starts in normal mode — see *Modal fzf* above, which is
where the keys live — plus the two this list adds:

| Key | Action |
|---|---|
| `l` or `enter` | open as its own window (`omarchy-launch-or-focus-webapp`) |
| `alt-enter` | open as an ordinary browser tab (`omarchy-launch-browser`) |
| `r` | rescan |
| `/` | search across all three columns — project, port, command line |

`alt-enter` is bound here rather than in the library because it is a chord: it
works in both modes, and it comes back as a tag on stdout by the same route
`h` does.

It is deliberately not a second implementation of the scan: `ports.sh` still
owns that, and the picker only draws its TSV. `fzf` is in Omarchy's own package
set, so there is nothing to install.

Seven things that are the way they are for a reason:

- **`--app-id=TUI.float` is not cosmetic.** `omarchy-launch-tui` derives the
  app-id from the command name when you do not pass one, and Omarchy floats a
  *closed list* of app-ids (`default/hypr/apps/system.lua`) — `TUI.float`,
  `org.omarchy.btop`, and a handful more. `org.omarchy.ports-tui` is not among
  them, so without the flag the picker opens as a tiled window in the current
  workspace. Both the keybind and the menu row pass it.
- **`omarchy-launch-tui`, not `omarchy-launch-or-focus-tui`.** The latter
  focuses an existing window matching the app-id, and `TUI.float` is shared by
  every floating TUI, so it would raise `btop` instead. Nothing is lost:
  the picker exits on the first keystroke that means anything.
- **Hyprland does the launching, not the picker.** This is the one that bit.
  The picker is exiting at the moment it opens a port, and the terminal closes
  with it — and chromium's `--app=` request is made by a short-lived child that
  hands the URL to the already-running browser, so that child dies with the
  terminal's scope before a window ever appears. `enter` looked like it did
  nothing at all, while `alt-enter` worked, because `omarchy-launch-browser`
  starts the browser as a transient unit's *own main process* and nothing is
  left to kill. `exec`, `setsid --fork` and `systemd-run` (both `--service`
  and `--scope`) all fail identically: the fix is not detachment, it is that
  the spawning process must not be exiting. So the picker hands the command to
  Hyprland — `hyprctl dispatch 'hl.dsp.exec_cmd("…")'` — which is the one
  long-lived process a script can reach. Note the dispatcher name:
  `hyprctl dispatch exec`
  is no longer parsed by this Hyprland and returns a Lua syntax error with
  rc=7.
- **The colours come from the theme.** `dot_config/omarchy/themed/fzf.env.tpl`
  renders the active theme's `colors.toml` into
  `~/.local/state/omarchy/current/theme/fzf.env`, and the picker sources it at
  launch, so the prompt, pointer, selected row, header and the accent on each
  `:port` follow `omarchy theme set`. Without it the picker is fzf's stock
  16-colour default in the middle of a themed desktop, because Omarchy themes
  every TUI it ships and fzf is not one of them. Three details. `bg` and
  `gutter` are `-1` (inherit) rather than the theme background, or the pane
  would be painted opaque and `foot`'s `alpha=0.9` would be lost. The
  per-`:port` accent and the dim on the command column are truecolor escapes
  built in the script, because fzf colours whole lines and only the fuzzy-match
  highlight is finer than that. And anything that is *text to be read* —
  the header legend, the counter, the command column — is
  `mix background foreground 60%`, never the theme's `muted`: each theme
  defines `muted` as furniture, and under Nord it is `#4c566a`, which through a
  0.9-alpha terminal made the keybinding legend invisible. A fixed mix is
  legible in every theme because it is defined against that theme's own
  background. No `theme-set.d` hook: nothing needs copying or signalling when
  the consumer reads the state dir itself.
- **The empty list is a notification, not a line of stdout.** A terminal that
  opens and closes faster than you can read it is no way to deliver "nothing is
  listening", so on a desktop that message goes to
  `omarchy-notification-send`. Run from a shell with no Hyprland instance in
  the environment, it still prints.
- **All three columns are visible, so all three are searchable.** Project
  directory, `:port`, and the process's own command line, one match space:
  typing `http.server 3222` crosses the argv and the port and narrows 3 rows to
  1. The command line used to be a preview pane at the foot of the window,
  which showed it for the selected row only and kept it out of the query — the
  wrong trade, because the argv is the one thing that separates two checkouts
  of the same repo, both of which label themselves `acme-web`. Only the project
  column is truncated (22 chars); fzf matches the whole string and lets the
  terminal cut the display, so a long argv stays searchable without widening
  every row.
- **`--rows` is the script calling itself.** fzf's `reload` binding needs a
  command string, and pointing it back at this script beats embedding the awk
  program in something that has to survive both bash and `sh` quoting. The
  columns are padded there too, rather than left to fzf's `--with-nth`, which
  prints the raw tabs and lets them move with every label length. The port is
  repeated as a hidden trailing field because the visible one carries ANSI
  escapes, so it can no longer be parsed.

`SUPER + ALT + P` was free; `SUPER + SHIFT + P` is Google Photos and
`SUPER + P` is *Pseudo window*. Check with `omarchy menu keybindings --print`
before taking a chord, and note that the description argument to `o.bind` is
what that list renders — an undescribed bind is an invisible one.

## USB drives

Pick an attached removable drive, then power it off for safe removal, reformat
it, or write a bootable ISO to it. `SUPER + ALT + U`, or *USB drives* from the
root menu.

| Path | What |
|---|---|
| `dot_config/omarchy/plugins/jonny.usb/executable_usb.sh` | the whole scan; usable on its own |
| `dot_config/omarchy/plugins/jonny.usb/executable_usb-tui.sh` | the picker and the three actions |
| `dot_config/omarchy/plugins/jonny.lib/vim-fzf.sh` | the modal keys, shared with the dev-ports picker |
| `dot_config/hypr/bindings.lua` | `SUPER + ALT + U` opens it |
| `dot_config/omarchy/extensions/omarchy-menu.jsonc` | the *USB drives* row, under *Plugins* |
| `dot_config/omarchy/themed/fzf.env.tpl` | `FZF_THEME_RED`, added for the line that says a drive is about to be erased |

Rungs 2 and 3 of the extension ladder — a menu row and a chord, both handing a
shell script to a floating terminal — and nothing lower, which is now also true
of `jonny.ports`. There is no bar widget: a stick is worth looking at in the
moment you act on it and never in between, and the same turned out to be true
of a list of ports. The directory sits under `plugins/` for the namespace alone
and deliberately has **no `manifest.json`**; the shell's manifest scan skips a
directory without one (`[[ -f "$sub/manifest.json" ]] || continue` in
`PluginRegistry.qml`), so the two scripts cost the shell nothing.

```bash
~/.config/omarchy/plugins/jonny.usb/usb.sh              # one TSV row per drive
~/.config/omarchy/plugins/jonny.usb/usb-tui.sh          # pick a drive, then an action
~/.config/omarchy/plugins/jonny.usb/usb-tui.sh /dev/sdb # skip the picker
```

`usb.sh` prints `device`, label, detail and owns every awkward part of deciding
what a removable drive is; the picker only draws that TSV, exactly as
`ports.sh` and the dev-ports front ends split the work.

### Walking the tree

Three levels — drive, then action, then filesystem, image or a power-off
confirmation — and every level is the same modal fzf with the same keys,
described once under *Modal fzf* above. `l` or `enter` goes down, `h` comes
back up, `r` rescans the drive list. Going *down* is a keypress on a list
rather than a chord on the drive list: a chord that erases a drive is a chord
pressed by accident.

Three things the tree itself had to get right:

- **One wrapper, three outcomes.** `vfzf` returns 0 with the row, 2 for back,
  1 for quit; the drive list folds 2 into 1 because there is nothing above it,
  and a submenu folds 2 into "return to the action menu".
- **A cancelled submenu must not pause.** Every action that *ran* ends with
  "press any key", because `dd` output is the whole point of running it. A
  submenu backed out of has nothing to read, and pausing there swallowed the
  next keystroke — which is usually the next `h`. Hence the distinct return
  code rather than a bare `|| return 0`.
- **Every action needs a third level, power off included.** Format and write
  got one for free — the filesystem list and the image list — so on the action
  menu those two are two keypresses from happening and *Power off* was one.
  Cutting power to a drive destroys no data, so there is no drive name to type
  either, which left the most easily mispressed row as the least guarded one.
  It now opens a list of its own whose *first*, selected row is "Keep it
  attached", so a stray `l l` lands on the harmless half and backing out is the
  same non-event as backing out of the filesystem list.

A drive unplugged between the scan and the keypress sends the picker round to
rescan, with a notification, rather than exiting: that is a stale row, not a
broken script. A device named on the command line is different — it is a typo
worth an error, and that mode drops `h back` from the footer and quits instead,
because the picker never ran and there is no level to go back to.

### What counts as a removable drive

Whole disks only — you mount a partition, but format, image-write and power-off
all act on the drive — and three tests, because no one of them is enough:

- `rm`, the kernel's removable-media bit. A USB SSD in a bridge enclosure
  reports `0`.
- `tran == "usb"`, which catches those, and misses a card reader behind some
  controllers.
- **and then a veto:** any drive carrying `/`, `/boot`, `/home`, `/var/…` or
  swap anywhere in its tree is dropped, however removable it claims to be.
  Every entry in this menu destroys data, so a misreported internal disk must
  not be able to reach it. `zram0` fails the first two tests and loop devices
  are `type: loop`, so neither needs naming.

### Privilege: udisks for three things, sudo for one

Unmount, format and power-off go over D-Bus to **udisks**, whose polkit actions
are `implicit active: yes` for a local logged-in session
(`pkaction --verbose --action-id org.freedesktop.udisks2.modify-device`), so
the everyday path asks for no password at all. `udisksctl` has verbs for
unmount and power-off; formatting does not exist there, so the script calls
`Block.Format` and `PartitionTable.CreatePartitionAndFormat` directly with
`gdbus` — the same pair GNOME Disks uses, which means udisks does the partition
alignment, the MBR type byte and the ext4 ownership fixup rather than a hand-
rolled `wipefs`/`sfdisk`/`mkfs` pipeline.

Writing an image is the exception: `sudo dd`. The only unprivileged route into
a raw block device is a file descriptor handed back over D-Bus
(`Block.OpenForRestore`), and a shell cannot receive one. The floating terminal
is visible, which is exactly when the omarchy skill says to use `sudo` rather
than `pkexec` — and on this machine the prompt is the fingerprint reader first,
password second, because of the PAM stack `run_after_omarchy-fingerprint-pam.sh`
restores.

### The three actions

| Action | What happens |
|---|---|
| Power off | a *Keep it attached* / *Power off* list first, then unmount every partition, `udisksctl power-off -b`, and a notification saying it is safe to unplug |
| Format | one partition filling the drive, `vfat`, `exfat` or `ext4`, labelled, mounted when it is done |
| Write image | `sudo dd … bs=4M oflag=direct conv=fsync`, then a read-back comparison, then an offer to power the drive off |

Format writes MBR below 2 TiB and GPT above it: MBR is the table a camera, a
car stereo and an old Windows box can all read, and above 2 TiB it cannot
address the sectors. `update-partition-type` sets the type byte from the
filesystem (`0x0c` FAT32 LBA, `0x07` exFAT, `0x83` Linux) and `take-ownership`
chowns a fresh ext4 root to you, which is the difference between a usable stick
and a read-only one. Label limits are checked *before* anything is written —
11 characters for vfat, 15 for exfat, 16 for ext4 — because udisks validates on
the second call, by which point the partition table has been rewritten and the
drive is empty. Labels are also restricted to letters, digits, space, dot, dash
and underscore, which is both what all three filesystems accept and what is
safe to interpolate into a GVariant dictionary.

The image picker lists `*.iso` and `*.img` two deep in `~/Downloads`,
`~/Desktop`, `~/Documents`, `~/iso`, `~/isos` and `~/Images`, newest first,
with a *type a path instead…* row for anything elsewhere. It refuses an image
larger than the drive before touching it, and a hybrid ISO is written raw,
which is what those ISOs are built for.

### Why the write is read back

`conv=fsync` makes `dd`'s exit status mean the bytes reached the device, not
the page cache — but "reached the device" is the drive's own word for it. A
dying stick, or a counterfeit one lying about its capacity, acknowledges a
write and stores something else; the next thing anyone learns about it is a
kernel panic partway through an install. So after `sync` the script reads the
written region back off the drive and `cmp`s it against the image, and a
mismatch says *do not boot from this* and refuses to offer the power-off.

The cost is a second full read of the image's length, so a 1 GB ISO roughly
doubles the wall time — paid on a progress line, on the one operation a person
is already sitting and watching.

Two flags do the work, and neither is the obvious one:

- **`blockdev --flushbufs`, not `iflag=direct`, on the read.** O_DIRECT needs
  every read length sector-aligned and the final partial block is not, so the
  read that matters is the one that fails. Dropping the device's buffer cache
  instead reaches the platters just as well. Without *either*, the comparison
  is satisfied from the copy still in RAM and verifies nothing at all.
- **`iflag=count_bytes`,** so `count=$size` is the image's exact byte count
  rather than a block count rounded up to the next 4M — which would leave
  `cmp` comparing trailing drive contents against end-of-file and failing every
  time.

On a mismatch `dd` also prints `error writing 'standard output': Broken pipe`,
because `cmp` stopped reading at the first differing byte. That line is normal
and comes from the comparison working. Its stderr is *not* redirected away,
because the other thing that appears there is a read error — a drive that
cannot be read back is exactly the drive this check exists to catch.

### Seven things that are the way they are for a reason

- **The window stays open, so this is not a `--expect` picker.** `dd` prints
  progress for minutes and every destructive action asks to be confirmed, so
  the actions are a second fzf list rather than keys on the first one: a chord
  that erases a drive is a chord pressed by accident. The dev-ports rule about
  a dying process being unable to spawn therefore does not apply here — nothing
  is exiting — but `--app-id=TUI.float` still is passed from both surfaces, or
  the terminal opens tiled. `omarchy-launch-tui`, not `or focus`: `TUI.float`
  is shared by every floating TUI, so `or focus` raises whichever one is
  already open.
- **The confirmation is the drive's own name, typed.** `sdb`, not `y`. It is
  the moment "the second one down" becomes a device node in the reader's head,
  and it is the last thing standing between a menu row and someone's photos.
- **`udiskie --automount` is running, and it re-mounts a partition the second
  it appears.** So every destructive path unmounts and then *checks*, up to
  three times, and aborts if anything is still mounted: udisks refuses to wipe
  a busy device, and finding that out halfway through leaves a drive with a
  partition table and no filesystem.
- **`lsblk -l` and `-r` cannot be combined.** `lsblk -lnro MOUNTPOINTS` exits
  with an error, which a `grep -q` swallowed into "nothing is mounted" — the
  mount check passed, the format then failed with `Device or resource busy`,
  and the cause was two flags. It is `-lnpo MOUNTPOINTS` plus a
  `[^[:space:]]` test, because that column is space-padded.
- **Nerd Font glyphs are written as escapes.** `$'\uf287'` in bash and
  `"\uf287"` in the JSONC row, not the characters themselves: they are
  private-use codepoints, and every hop between an editor, a clipboard and a
  file is a chance to drop one silently and leave a blank icon column.
- **A failed write says so in full.** A non-zero `dd` covers both sudo
  refusing the password, where nothing was written, and `dd` stopping part way,
  where the drive holds neither its old filesystem nor a bootable image. The
  message names that state rather than printing an error code, because the
  wrong thing to read at that point is "it is fine". The read-back failing is
  the third state and the nastiest, because everything printed above it looked
  like success: that message says *do not boot from it* and blames the drive,
  which is what a stick that acknowledges writes and stores something else has
  earned.

`SUPER + ALT + U` was free — check with `omarchy menu keybindings --print`
before taking a chord — and the description argument to `o.bind` is what that
list renders.

## Agent skills

Copy agent skills out of the skills repos I follow and into the one I own, one
reviewed diff at a time. `SUPER + ALT + L`, or *Skills* under *Plugins*.

| Path | What |
|---|---|
| `dot_config/omarchy/plugins/jonny.skills/executable_skills.sh` | the launcher: palette, missing-binary notice, the pause |
| `dot_config/omarchy/themed/skills-sync.env.tpl` | the palette, rendered per theme |
| `run_after_skills-sync.sh` | builds the `skills-sync` binary if it is missing |
| `dot_config/omarchy/extensions/omarchy-menu.jsonc` | the *Skills* row, under *Plugins* |
| `dot_config/hypr/bindings.lua` | `SUPER + ALT + L` opens it |

Everything visible belongs to `skills-sync` (`~/dev/skills-sync`, private, and
not in the table above because it is not managed from here). It is a Bubble Tea
panel TUI: repo membership on the left, the skills that differ top right, the
diff of the row under the cursor below it.

| Key | |
|---|---|
| `j` / `k` | move |
| `space` | tick a skill |
| `a` · `n` · `d` | tick all · every `new` one · every `diverged` one |
| `←` / `→` | filter to one source repo |
| `1`–`4` · `tab` | focus a panel |
| `s` · `t` | add a source repo · set the target |
| `r` | rescan |
| `ctrl+s` | sync what is ticked |
| `q` or `esc` | quit, having written nothing |

`ctrl+s` closes the TUI and prints the plan — every file it would add, replace
or delete — then asks once before copying anything.

### There was an fzf picker here, for one evening

The three tools above are bash and fzf, so the reflex was to make this one
match: a `-tsv` flag on the binary for the rows, `-diff REF` for the preview
pane, and `vfzf` for the keys. It worked. It was still the wrong shape, and the
reasons are worth keeping, because the next tool with an existing UI will make
the same offer:

- **It was a subset, not a skin.** A single fzf list cannot hold two panes of
  repo membership, a diff beside the row it belongs to, or a directory browser
  for adding a repo, so those stayed behind in the Go TUI — which meant the
  answer to "where do I add a source repo?" became "not in the thing you just
  opened".
- **It added a contract to keep.** `ref ⇥ name ⇥ status ⇥ source ⇥ category ⇥
  summary`, parsed on the other side of a pipe, plus a test in the Go repo to
  stop a column moving. That is a real maintenance cost, paid for a redraw of
  data that already had a drawer.
- **The keys were already right.** `j`/`k`, `space`, `g`/`G`, `q`, a footer that
  lists what works now — the Bubble Tea UI landed on the same conventions
  `vfzf` did, because both were written for the same hands. `h`/`l` differ
  (source tabs rather than back/accept), which is what a screen with no
  levels needs.

What the fzf version genuinely had was Omarchy's colours, and that turned out
to be the cheap half.

### Theming somebody else's TUI without teaching it about Omarchy

`skills-sync` reads six environment variables and knows nothing else:

```
SKILLS_SYNC_ACCENT    cursor, ticks, focused border, live tab
SKILLS_SYNC_ADDED     `new`, and an inserted diff line
SKILLS_SYNC_CHANGED   `diverged`
SKILLS_SYNC_REMOVED   deletions and errors
SKILLS_SYNC_META      diff hunk headers
SKILLS_SYNC_DIM       idle borders, idle tabs, the footer
```

`skills-sync.env.tpl` renders them from the active theme on every
`omarchy theme set` — same rung as `fzf.env.tpl`, same lack of a hook, because
the launcher reads the state directory itself. It sources the file with `set -a`
so the six become environment rather than shell variables, and the binary picks
them up.

Three deliberate choices there:

- **Six roles, not fifteen styles.** The Go side collapsed its fifteen
  `lipgloss` styles onto six names in `theme.go`; the template speaks roles,
  and nothing outside that file knows what a role is painted with.
- **Every variable is optional, and the fallback is the old ANSI index.** Run
  the binary in a terminal with no Omarchy anywhere and it looks exactly as it
  did before it could be themed. That is what keeps the desktop's palette out
  of a repo that has no business knowing about it.
- **No background is ever set.** Same rule as `fzf.env.tpl`'s `bg:-1`: the
  panels inherit the terminal's, so foot's `alpha=0.9` still shows through.
  `SKILLS_SYNC_DIM` is `{{ mix background foreground 60% }}` rather than
  `muted`, for the same reason the fzf header is — the footer is the only place
  the keys are written down.

### Four things learned building it

- **A floating terminal closes mid-sentence.** The plan, the `Proceed?` answer
  and the "synced …" lines are all printed *after* the TUI restores the screen,
  and the window is gone the instant the process exits. Hence the `read -rsn1`
  at the end of the launcher. It is unconditional on purpose: nothing separates
  "aborted, nothing to read" from "synced four skills" — both exit 0 — and
  inferring it from the wording of a message would make the launcher a parser
  of the other program's prose.
- **`CI=true` strips colour, and an agent shell exports it.** Two screenshots of
  a perfectly themed TUI came back monochrome — not the 16-colour fallback,
  *no* colour — because `omarchy-launch-tui` inherits the environment of
  whatever ran it, and the palette detection behind Bubble Tea treats `CI` the
  way it treats `NO_COLOR`. When checking colours by hand from a tool session,
  launch with `env -u CI -u NO_COLOR`, and confirm from pixels
  (`magick shot.png txt:- | grep srgb`) rather than by eye through a
  screenshot's compression.
- **A first run has nothing remembered.** `skills-sync` with no config asks for
  `-target DIR`; the launcher turns a missing *binary* into a notification for
  the same reason — a window that closes cannot carry an error message. The
  config it writes (`~/.config/skills-sync/config.json`) names repo paths, so it
  is runtime state and stays unmanaged. See rule 7.
- **`SUPER + ALT + S` was taken** by Omarchy's *Move window to scratchpad*, and
  `K` and `A` were gone too, so the chord is `L` for "learn". `hyprctl binds`
  lists what is taken by modmask; `omarchy menu keybindings --print` only shows
  bindings that carry a description.

## Markdown preview

Read a markdown file, mermaid diagrams included, in a Chromium app window
Hyprland tiles beside the terminal. `mdp` from a shell, `<Leader>mp` from
Neovim.

| Path | Job |
|---|---|
| `dot_config/omarchy/plugins/jonny.mdpreview/mdpreview.sh` | the whole implementation: find or start a server, open or focus the window |
| `dot_config/bash/mdpreview.sh` | the `mdp` function and its completion |
| `dot_config/nvim/lua/plugins/mdpreview.lua` | `<Leader>mp`, which writes the buffer and calls the same script |
| `dot_config/mise/config.toml` | the pinned `go-grip` that does the rendering |

```
mdp             preview ./README.md
mdp <file.md>   preview a file, or focus its window if it is already open
mdp --stop      stop every preview server
```

### Why this is not in the terminal

It was meant to be. The stack makes it impossible, and the reason is worth
writing down because it is not obvious and it is not fixable by configuration:

- **foot 1.27 speaks sixel and not the kitty graphics protocol.** Its source has
  `sixel.c`; every `kitty` symbol in it is the *keyboard* protocol.
- **herdr 0.8.2 composites every pane into a character grid.** Its only image
  option is `experimental.kitty_graphics`, default off, and there is no sixel
  option at any setting.

Those two facts do not overlap, so no image protocol survives from a herdr pane
to the screen. `snacks.nvim` is already installed and has a complete `image`
module, and it cannot help: it emits kitty APC only — `grep -i sixel` across the
plugin returns nothing — inline placement needs kitty Unicode placeholders
(`0x10EEEE`) foot does not implement, and AstroNvim sets `image.doc.enabled =
false` anyway. `image.nvim` *does* have a sixel backend that works in foot, but
only with foot talking to nvim directly, which means giving up herdr.

The browser-free alternative was `mermaid-ascii`, the one Mermaid renderer that
needs no headless Chromium. A census of the 136 mermaid blocks under `~/dev`
ruled it out: 30 use `subgraph` and 25 use `{diamond}`, neither of which it
supports, and 22 are in diagram types it cannot parse at all.

### Why go-grip and not a Neovim plugin

The corpus decided it. 2268 markdown files under `~/dev`:

| Files | Share | Feature |
|---|---|---|
| 1302 | 57.4% | YAML frontmatter |
| 637 | 28.1% | tables |
| 52 | 2.3% | task lists |
| 48 | 2.1% | math |
| 44 | 1.9% | mermaid |
| 4 | 0.2% | footnotes |

Frontmatter is in the majority, because every `SKILL.md` in the skills repos has
it. That single column eliminated the alternatives:

- **`iamcco/markdown-preview.nvim`** — the obvious choice, and unmaintained:
  master HEAD 2023-10-17, sole release `v0.0.10` from **2022-05-13**, 228 open
  issues. It vendors its own `mermaid.min.js`, and the install route most people
  use downloads the release binary, whose bundle is **Mermaid 8.13.8**. Even the
  `yarn` build only reaches 10.2.3, which cannot parse `architecture-beta`
  (needs 11.1), `block-beta`, `sankey`, `xychart`, `radar` or `treemap`.
- **`brianhuster/live-preview.nvim`** — genuinely well built, actively
  maintained, zero external dependencies, renders *as you type*, and has scroll
  sync. Its client loads only `injectLinenumbers`, `emoji` and `katex`: no
  frontmatter handling, not configurable, so 1302 files would each open with two
  horizontal rules and a block of raw YAML at the top.
- **`go-grip`** — a single static Go binary that extracts frontmatter into a
  table, and ships **Mermaid 11.13.0**, the newest of anything surveyed. All 11
  diagram types in the census render from it with no errors, `architecture-beta`
  included.

The cost of that choice is the reload trigger. go-grip watches the file's
directory with fsnotify and does a full page reload, so **the preview updates on
`:w`, not on keystroke**, and scroll position resets when it does. That was the
deliberate trade against `live-preview.nvim`: correct frontmatter on 57% of files
beats keystroke latency on all of them, and a reload that fires when you save
rather than mid-sentence is calmer to work next to. It is also why the nvim
keymap writes the buffer before it calls the script — previewing unsaved bytes
would just show stale output.

### Chromium does the window, and derives its own app_id

There is no `--user-data-dir` and no `--class` here, and both absences were
measured rather than assumed.

`--app=<url>` handed to the *already running* Chromium — the one
`autostart.lua` puts on workspace 1 — makes a proper app window in that same
process. No second browser, no second profile. The launcher process exits
immediately, which looks like failure and is not.

Its Wayland app_id is Chromium's to choose, not ours: for an app window it takes
the `GetXdgAppIdForWebApp` branch, which is
`chrome-<host>__<url path>-<profile>`, and **ignores `--class` completely** on
that path. So `http://localhost:6419/README.md` becomes
`chrome-localhost__README.md-Default`. The script rebuilds that string and hands
it to `omarchy-launch-or-focus-webapp`, which is what makes a second `mdp` on the
same file focus the open window instead of stacking another one. Because the
URL path is in the app_id, this is per-file for free — and it is why a window
rule matching previews needs a regex (`^chrome-localhost__.*-Default$`), not a
literal.

There is no window rule at present. App windows tile in dwindle without help,
and adding one would mean bringing `hyprland.lua` under management purely to
carry a `require` line.

### Four things that are the way they are for a reason

- **`uwsm-app` does not return until the unit it started exits.** Every other
  caller in Omarchy `exec`s it as the last thing they do, which hides this. Used
  plainly it hung the script for the life of the server and the window never
  opened. It is backgrounded here, and only the waiter is: go-grip is in its own
  transient scope by then, so losing the waiter costs nothing while the server
  still survives the terminal that started it.
- **One server per directory, and the port is discovered, not fixed.** go-grip
  serves `dirname <file>`, so a file in a second directory needs a second
  server. Ports are found by reading `/proc/*/cmdline` for running go-grips and
  matching their served directory. Hashing the directory to a port was the first
  attempt and is worse than it looks: a collision silently previews the wrong
  file. `/proc` is read rather than `pgrep -a` parsed because a filename with a
  space in it makes a pgrep line ambiguous and `cmdline` is already
  NUL-delimited.
- **`-b=false` is not optional.** `internal/open.go` hard-codes `xdg-open` with
  no flag to override it, so go-grip's own browser opening has to be refused and
  the window opened here.
- **It binds every interface.** `ListenAndServe(":port")`; `-H` only changes the
  URL it prints. The handler is a plain file server over the served directory, so
  the only thing keeping a preview off the tailnet is ufw — default-deny incoming,
  plus the port-22-only rule in `run_after_sshd-tailnet.sh`. Widening that rule
  publishes every directory anyone has previewed.

### Verifying a change

`mdp --stop`, then `mdp` some file with frontmatter and a mermaid fence, and
check three things on the real window: the frontmatter is a table and not raw
YAML, the diagram is an SVG and not an error box, and a `:w` in the editor
updates the page. `hyprctl clients -j | jq -r '.[].class'` should show exactly
one `chrome-localhost__<file>-Default` per previewed file, and running `mdp`
again on the same file should focus it rather than add a second.

## Omarchy agent skill: fingerprint guide

`.chezmoitemplates/omarchy/fingerprint.md` is the canonical copy of the
fingerprint topic guide for the packaged omarchy agent skill, documenting the
Goodix `27c6:533c` reader on this machine and the proprietary libfprint TOD
driver it needs.

It is installed to `/usr/share/omarchy/default/agents/skills/omarchy/` — a
package-owned tree, so `omarchy update` wipes it along with the link to it in
that skill's `SKILL.md`. To restore both:

```bash
chezmoi apply          # Prompts for a password via pkexec only when drift exists
```

`run_after_omarchy-fingerprint-skill.sh.tmpl` does the work. It runs on every
apply rather than as a `run_onchange_` script, because the script's own hash
does not change when the *destination* is wiped. It compares the staged content
against the installed file and only escalates through `pkexec` when the guide is
missing, stale, or unlinked from `SKILL.md`.

Edit the guide in `.chezmoitemplates/omarchy/fingerprint.md`, never in
`/usr/share/omarchy/`, then run `chezmoi apply`.

## Fingerprint PAM configuration

`run_after_omarchy-fingerprint-pam.sh` restores what
`omarchy-setup-security-fingerprint` writes into `/etc/pam.d/`:

| File | Contents | Package owner |
|---|---|---|
| `sudo` | clamshell gate + `auth sufficient pam_fprintd.so`, prepended | `sudo` (a pacman `backup` file, so upgrades leave it and drop a `.pacnew`) |
| `polkit-1` | same two lines, or the whole stack if absent | none |
| `omarchy-lock-fingerprint` | fingerprint-only stack for the lock screen | none |

The gate must stay immediately above `pam_fprintd.so`; the script enforces that
adjacency rather than assuming it.

It refuses to touch anything unless `pam_fprintd.so`, `pam_exec.so`,
`omarchy-hw-laptop-closed` and `fprintd-list` are all present **and** a finger
is actually enrolled — an enrolled print is the only proof the driver drives the
sensor. Before installing an edited stack it checks the staged file gained
exactly the expected lines and kept the gate adjacent to `pam_fprintd`, and it
keeps a timestamped `.bak` of the original.

Every edit fails open by construction: the gate is
`[success=1 default=ignore]` and `pam_fprintd` is `sufficient`, so a missing
reader or a dead driver costs a password prompt, never access. Verify with
`sudo -k; sudo id -u`, which should print `0` after a touch.

## Portainer

`run_after_portainer.sh` is the one script here that runs a container rather
than configuring the machine. It writes `/opt/portainer/docker-compose.yml` —
outside `$HOME`, hence a script and not a target file — and brings the stack up
on <http://localhost:9000>.

Omarchy enables `docker.socket` and leaves `docker.service` disabled, so
`dockerd` starts only when a client first connects to the socket. Nothing does
that at boot, and a container with `restart: always` is restored by the daemon
as it starts — so Portainer stayed down after every reboot until the next
`docker` command run by hand appeared to fix it. The script enables
`docker.service`, guarded on `systemctl is-enabled` so a converged machine
raises no polkit prompt. `containerd` needs no enable of its own:
`docker.service` pulls it in through `Wants`.

Docker itself is not installed by this repo; the script is a no-op without it.
`docker info` is the gate and doubles as the group-membership probe: on the
apply that adds this account to `docker` the socket exists and the shell still
cannot read it, so the script defers to the next apply instead of failing. The
compose file is staged in a tempdir and compared before it is installed, so an
apply with nothing to do raises no polkit prompt, and `docker compose up -d`
runs only when the file changed or nothing answers to the name `portainer` —
`up -d` talks to the registry, which is not worth doing on every apply.

`pkexec install`, not `sudo`, per rule 5 in `AGENTS.md`: an apply can be driven
by an agent with no terminal to type a password into. A declined prompt, an
unreachable daemon or a registry outage all exit 0.

Portainer's first-run admin account is created at <http://localhost:9000> and
the window times out if it is left sitting; `docker restart portainer` reopens
it.

## Desktops never sleep

`run_after_never-sleep.sh` masks `sleep.target`, `suspend.target`,
`hibernate.target`, `hybrid-sleep.target` and `suspend-then-hibernate.target`,
and sets Omarchy's `suspend-off` toggle so the *Suspend* row leaves the system
menu. It is gated on the DMI chassis type, and the list is an allowlist of
desktop-class values (3, 4, 5, 6, 7, 15, 16, 17, 23, 35) rather than a denylist
of laptop ones: `minisforum` reports 35, Mini PC, and every other machine —
the XPS 15, which is a Notebook, or anything whose firmware reports something
unexpected — exits 0 before the first `pkexec` and keeps suspending normally.

The point is remote access. A suspended box looks exactly like a dead one from
the office: sshd is enabled, tailscaled is enabled, and the packets go nowhere.
There is no way back in, either — this host is on Wi-Fi (`enp195s0`/`enp196s0`
are unpopulated), and Wake-on-LAN needs a magic packet originating on the same
L2 segment, which is the one thing being elsewhere rules out.

Nothing here suppresses an idle-suspend, because Omarchy has none: the
`omarchy.idle` service only runs the screensaver and the lock (see *Stay awake*),
and logind's `IdleAction` is left at its `ignore` default. Locking is orthogonal
and stays on — sshd does not care whether the session is locked. What the script
closes is the manual path: the menu row, `systemctl suspend` from a shell, the
power key, and any future Omarchy default that starts setting `IdleAction`.

Masking is the enforcement layer and the toggle is only cosmetic. logind reaches
every sleep path by queueing a job for `sleep.target`, so a masked unit fails
the job — `Unit suspend.target is masked` — whatever the config above it says.
The toggle exists so the UI stops offering an action that would now error.

Two things this cannot do, both firmware:

- **Power loss.** Set *Restore on AC Power Loss* (Minisforum BIOS: Chipset →
  State After G3) to *Power On*, or a five-second cut leaves the machine off
  until someone presses the button.
- **Never a clean poweroff.** `omarchy system shutdown` still works and is still
  unrecoverable remotely. Reboot is fine; the machine comes back.

Verify after an apply:

```bash
systemctl is-enabled sleep.target suspend.target hibernate.target \
  hybrid-sleep.target suspend-then-hibernate.target   # five × masked
systemctl suspend                                     # must fail, masked
```

## Thermal and GPU power (XPS 15 9500)

`run_after_xps15-thermal.sh` fixes two places where Omarchy's defaults meet
five-year-old laptop cooling. It is gated on `product_name == "XPS 15 9500"`
and does nothing on any other machine.

**Package power.** Dell's firmware advertises PL1 68 W in both the MSR and the
MMIO RAPL domain — 23 W above the i9-10885H's 45 W spec — with a 56 s window
and PL2 135 W. This chassis cannot move that much heat. A `cpu-power-cap`
oneshot unit writes 45 W / 28 s / 60 W to both domains, and is wanted by
`multi-user.target` plus the four sleep targets because resume restores the
firmware values.

Measured on an all-core load, before: 62 W and a package parked at 100 C.
After: a 58 W burst peaking at 91 C, pulled to 41 W and 74 C inside 20 s, then
63 C steady. No Tjmax, no fan-max plateau.

**Discrete GPU.** `install/hardware/nvidia.sh` writes `nvidia_drm modeset=1`
plus early KMS for any NVIDIA GPU, with no hybrid-laptop branch. Aquamarine
then renders the desktop on the Intel iGPU (`card1` is not a KMS device) while
the 1650 Ti sits in D0 at 3 W and 57 C for the whole uptime, because nothing
ever sets `power/control` and the kernel therefore never offers D3. The script
installs `/etc/udev/rules.d/80-nvidia-pm.rules` (the rule `nvidia-utils`
stopped shipping) and asks for fine-grained RTD3 explicitly with
`NVreg_DynamicPowerManagement=0x02` in its own `/etc/modprobe.d` file, kept
separate from the `nvidia.conf` Omarchy's installer rewrites wholesale.

That file only matters if it reaches the module, and the nvidia modules load
from the boot image, not from `/etc`. This machine boots a UKI —
`/boot/EFI/Linux/omarchy_linux.efi`, built by `kernel-install` with an empty
`/etc/mkinitcpio.d`, so `mkinitcpio -P` is a no-op here — so the script asks
`lsinitcpio` whether the image already carries
`etc/modprobe.d/nvidia-power-management.conf` and rebuilds through
`limine-mkinitcpio` when it does not. Checking the image rather than the file
means an interrupted rebuild or a later kernel upgrade is self-correcting, and
a boot layout it cannot inspect prints a warning instead of passing silently.

It also enables `nvidia-suspend`, `nvidia-resume` and `nvidia-hibernate`.
`PreserveVideoMemoryAllocations` is already 1 on this system, and without those
units nothing saves or restores that memory across a suspend.

`/proc/driver/nvidia/gpus/0000:01:00.0/power` reports `Runtime D3 status:
Disabled by default` until that parameter arrives. After a reboot it must read
`Enabled (fine-grained)`:

```bash
systemctl is-active cpu-power-cap.service
grep 'Runtime D3' /proc/driver/nvidia/gpus/0000:01:00.0/power
grep -H . /sys/bus/pci/devices/0000:01:00.0/power/{control,runtime_status,runtime_suspended_time}
```

`runtime_suspended_time` must start climbing. If it stays at 0 the remaining
holder is the compositor: `libEGL` enumerates the NVIDIA device at session
start, and Hyprland keeps `/dev/nvidia0` open for the session. The only lever
left then is blacklisting the driver, which costs CUDA and any dGPU use.

What this script does **not** touch: the fan curve. `pwm1_enable` on this
machine always reads 1 and `pwm1` always reads 255, which `sensors` renders as
`MANUAL CONTROL` at 128%. That is a `dell_smm` reporting artifact, not a
setting — the EC never returns the magic auto value from `I8K_SMM_GET_FAN`, so
the driver reports manual, and writing `2` back is rejected with `EINVAL`
because this firmware refuses the SMM set-fan call. Fan speed follows package
temperature and nothing else; the fans idle near 4600 RPM whenever the package
stays above roughly 65 C.

## Inbound SSH over Tailscale

`run_after_sshd-tailnet.sh` makes this box reachable by `ssh` from the tailnet
and from nowhere else. Arch ships `openssh` installed but `sshd.service`
disabled, and Tailscale's netfilter rules (`NetfilterMode=2`) sit *in front* of
ufw, so tailnet packets reached a closed port 22 and got a RST — `ssh minisforum`
failed with `Connection refused` rather than timing out.

Three pieces, only one of which chezmoi can own as a file:

| Where | What |
|---|---|
| `private_dot_ssh/private_authorized_keys` | the personal 1Password-agent Ed25519 public key, the only thing that can log in |
| `/etc/ssh/sshd_config.d/10-tailnet-only.conf` | `AuthenticationMethods publickey`, no passwords, no root |
| `ufw allow in on tailscale0 to any port 22` | the only rule that admits port 22 at all |

`10-` beats Arch's `99-archlinux.conf`: sshd is first-value-wins per keyword and
reads the drop-in directory in lexical order.

Reachability is a firewall rule, not `ListenAddress`. Binding to `100.91.240.96`
would make sshd depend on tailscaled having claimed the address before it
starts, and a boot-order race that leaves sshd dead on a headless box is worse
than a packet filter. ufw's default policy is deny (incoming), so the single
`tailscale0` rule is what admits the tailnet while the LAN and the WAN see a
drop.

No private key and no password is involved: the authorized key is the same
1Password agent identity described in the next section, which every machine in
this tailnet already carries, so logging in here is a biometric approval on the
machine you are sitting at.

### Why not Tailscale SSH

`tailscale set --ssh` is the shorter answer — tailnet-identity auth, no
`authorized_keys`, nothing listening on the host at all — and the tailnet's ACL
already permits it (`tailscale debug netmap` shows an `SSHPolicy` accepting the
other two nodes for any user). It was tried first and rejected for one reason:
it cannot be verified from the box being configured. Tailscale does not
intercept traffic to a node's own tailnet address, so a self-dial is refused
however healthy the server is, and neither peer had a way in to loop back
through. A login path that cannot be tested before you rely on it is not worth
the saved `authorized_keys` line.

### macmini

The third tailnet node is a Mac mini, and nothing in this repo configures it.
`~/.ssh/config` pins the same personal Ed25519 identity for it as for the two
Linux boxes, so outbound `ssh macmini` offers one key instead of three, but the
server half is macOS Remote Login and has to be done on the box by hand:

1. **System Settings → General → Sharing → Remote Login: on**, with *Allow
   access for* set to the one account rather than *All users*.
2. Authorize the key, once, from a Linux box:
   `ssh-copy-id -i ~/.ssh/1password/github-personal.pub macmini`. It is the
   public stub, so this copies a public key and nothing else; the password
   prompt is the last time one is needed.
3. Turn password auth off afterwards, in
   `/etc/ssh/sshd_config.d/10-tailnet-only.conf` on the Mac —
   `PasswordAuthentication no`, `KbdInteractiveAuthentication no`,
   `PermitRootLogin no`. Do this only after step 2 is verified, or the only way
   back in is the keyboard.

   The `10-` prefix matters for the same first-value-wins reason it does on
   Arch, against a different file: macOS ships its own `100-macos.conf` there,
   and `10-` sorts ahead of `100-` because `-` precedes `0`. A higher number
   would be read second and silently ignored.

   No restart is needed. macOS sshd is launchd socket-activated and spawned per
   connection, so the next login reads the new config; the session you are
   sitting in is unaffected, which is what makes it safe to verify from a second
   terminal before closing the first.

What cannot be reproduced from the Linux side is the ufw half. macOS has no
`ufw`, and its sshd is launchd socket-activated, so `ListenAddress` is ignored
and port 22 is offered on every interface including the LAN. Scoping it to the
tailnet needs a `pf` anchor or the Application Firewall, so until that is done
`macmini` is key-only but not tailnet-only — a weaker posture than the two Linux
hosts, and the reason this is documented rather than scripted.

## System locale

`run_after_locale.sh` sets `LANG=en_GB.UTF-8` in the two places a locale has to
be set, because on Arch neither one covers the other.

Omarchy's installer asks for the keyboard layout but hardcodes the locale, so
both machines came out of `omarchy-install` mismatched — `VC Keymap: uk`,
`X11 Layout: gb`, `LANG=en_US.UTF-8` — with `en_GB.UTF-8` commented out in
`/etc/locale.gen` and absent from `locale -a`. Order matters when fixing that:
`localectl set-locale` on an ungenerated locale writes a `locale.conf` nothing
can load, which is worse than the wrong locale, so the script runs `locale-gen`
first and only then `localectl`.

The second file is the one that is easy to miss. `/etc/locale.conf` is read by
**systemd**, which exports `LANG` into the user manager's environment; a
graphical session inherits it from there. An `sshd` session does not — the shell
is a child of `sshd`, not of the user manager, and the only locale channel PAM
offers is `pam_env`, which reads `/etc/environment` and nothing else. Arch ships
that file with comments only, so before this script every ssh login here landed
in the C locale with `LANG` empty.

That stayed invisible until something read `LANG`. `herdr --remote minisforum`
runs `ssh minisforum herdr server`, so the remote Herdr server inherited the
empty value and passed it to every pane it spawned, and ble.sh opened each one
with:

```
ble.sh: suspicious environment: $LANG is empty.
```

ble.sh was right and merely first; anything else in those panes was in the C
locale too, which is what makes this worth fixing at `/etc/environment` rather
than silencing in `dot_bashrc`. A shell-level default would also be too late —
`dot_bashrc` sources ble.sh at line 14, well before the `dot_config/bash/*.sh`
glob — and would leave every non-bash program in the pane unfixed.

`LC_COLLATE` is deliberately not set. en_GB dictionary ordering changes `ls` and
`sort` output against the byte ordering the aliases and scripts here were
written on; only `LANG` is set, so collation follows it and can be pinned back
to `C` in the same two files if that ever bites.

Both hosts need this, and an already-correct host exits before its first
`pkexec`, so the script is silent on every apply after the first. Local sessions
pick the change up on next login. A remote Herdr session needs
`herdr server stop` and a re-attach, because the running server holds the old
environment.

## SSH and the 1Password agent

Ported from the previous multi-OS dotfiles, minus its macOS/Windows/WSL
branches — this repo has no template data, so every file here is plain.

| Target | Purpose |
|---|---|
| `~/.ssh/config` | one identity per host, `IdentitiesOnly yes` |
| `~/.ssh/1password/*.pub` | public-key stubs naming which agent key a host uses |
| `~/.ssh/1password/refresh` | regenerates those stubs from `ssh-add -L` |
| `~/.config/1Password/ssh/agent.toml` | which vault items the agent offers, in order |

No private key is ever on disk. The stubs only tell ssh *which* agent key to
use; 1Password holds the private halves and serves them over
`~/.1password/agent.sock`, which `Host *` pins as `IdentityAgent`.

Two details are load-bearing:

- Every host block is `Match originalhost`, not `Host`. The `github-work` alias
  sets `HostName github.com`, so a `Host github.com` block would match it too —
  both identities load, agent order picks the account, and work repos silently
  authenticate as the personal one. That is exactly what `IdentitiesOnly` is
  there to prevent.
- The stubs are `private_*.pub` in the source, so chezmoi writes them 0600.
  OpenSSH 10.5 rejects a 0644 `IdentityFile` outright ("Permissions 0644 … are
  too open") even when the file holds nothing but a public key.

The agent has to be turned on by hand — 1Password → Settings → Developer → *Use
the SSH agent*. There is no headless path:
`~/.config/1Password/settings/settings.json` is HMAC-authenticated
(`authTags`), so the app ignores an edit made from outside. Before it is on,
`ssh -T git@github.com` gets as far as offering the right key and then fails
with `ssh_get_authentication_socket: No such file or directory`. After, it
greets you as `jonnyasmith`, and `git@github-work` as the work account.

Enabling it also makes 1Password **append its own block to `~/.ssh/config`**:

```
Host *
	IdentityAgent ~/.1password/agent.sock
```

Which is what the tracked config already says, so it is a duplicate rather than
a conflict — `ssh_config` is first-value-wins and the tracked `Host *` comes
first. It still shows up as `MM .ssh/config`; take the tracked file back with
`chezmoi apply --force ~/.ssh/config`. Expect this again after a 1Password
reinstall or a toggle off/on.

A running 1Password is the other precondition, and losing it looks like a key
problem rather than a missing app. `~/.1password/agent.sock` is left behind when
the app goes away, so the path still exists with nothing listening, and
`IdentitiesOnly yes` leaves the `.pub` stub as the only candidate:

```
Load key "/home/jonny/.ssh/1password/github-personal.pub": invalid format
git@github.com: Permission denied (publickey).
```

Identical message, identical cause, and the same one the forwarded socket
produces below — a dead agent, not a bad stub. `ssh-add -l` is the quick
discriminator: `Error connecting to agent: Connection refused` means the socket
is stale. Fixed by starting the app again (`/opt/1Password/1password --silent`,
which is what the XDG autostart entry runs at login).

What makes this worth naming is that it happens without anyone quitting
1Password. It watches its own binary and exits when it moves, so a package
upgrade of `1password` — including one pulled in by `omarchy update` — kills a
running app mid-session:

```
WARN [1P:app/op-app/src/app.rs:1064] Application binary and/or it's directory
was moved or replaced, exiting.
```

in `~/.config/1Password/logs/1Password_r*.log`, timestamped to the `upgraded
1password` line in `/var/log/pacman.log`. Nothing restarts it, so the next
`git push` is where you find out.

`~/.ssh/1password/refresh` regenerates the stubs from `ssh-add -L` **into this
source directory**, not straight into `~` — a rotated key is a change to the
desired state, so it belongs in a commit. Review with `chezmoi diff`, then
apply. It resolves one source path per file rather than joining a directory: on
`~/.ssh/1password` alone, `chezmoi source-path` returns the directory without
the per-file `private_` prefix, and writing `$dir/$name.pub` creates a second
0644 source entry per stub, which chezmoi then reports as `inconsistent state`.

### Agent forwarding for `herdr --remote`

Git inside a `herdr --remote` pane used to hang with no output. The cause was
geography, not credentials: the pane's ssh read `Host * IdentityAgent
~/.1password/agent.sock` from *the remote machine's* copy of this same file, so
the approval dialog opened on that box's physical Wayland session — a screen
nobody was looking at — and ssh waited on it forever.

Attach through the `-herdr` alias, and that connection — only that connection —
forwards the agent of the machine being sat at:

```bash
herdr --remote minisforum-herdr
```

```
Host minisforum-herdr
  HostName minisforum

Match originalhost *-herdr
  RemoteForward /home/jonny/.ssh/1password-forwarded.sock /home/jonny/.1password/agent.sock
```

`RemoteForward` and not `ForwardAgent`, because of how Herdr is built.
`ForwardAgent` advertises a random per-connection socket path in
`$SSH_AUTH_SOCK`, while the Herdr server outlives any single ssh connection and
its panes inherit the environment it started with — so by the second attach that
variable is either absent or pointing at a closed connection's socket. A
constant path has no environment to go stale.

The alias exists because a constant path has the opposite hazard. Every
connection carrying that option rebinds the same socket, and sshd does not unlink
it on close, so a one-shot `ssh minisforum some-command` would take the path from
a live session and leave a dead socket behind on exit — after which git in every
pane fails with `Error connecting to agent: Connection refused`. Keeping the
forward on the attach alias means only the long-lived connection that needs it
ever binds it, and plain `ssh minisforum` is harmless.

Four pieces have to agree, and each one is inert without the others:

| Where | What | Why |
|---|---|---|
| `~/.ssh/config`, `Host <host>-herdr` | `HostName <host>` | an alias only the attach uses |
| `~/.ssh/config`, `Match originalhost *-herdr` | `RemoteForward <fixed path> ~/.1password/agent.sock` | sends this machine's agent over |
| `~/.ssh/config`, above `Host *` | `Match exec "test -n \"$SSH_CONNECTION\" && test -S <fixed path>"` → `IdentityAgent <fixed path>` | makes the far end prefer it |
| remote `sshd` | `StreamLocalBindUnlink yes` | lets attach #2 rebind the path |

That `Match exec` is what makes the forward do anything at all: `ssh_config` is
first-value-wins, so without a match ahead of `Host *` the far end goes back to
asking its own local 1Password. Both halves of the test are load-bearing. Both
machines share this file and forward to the same path, so existence of the socket
says nothing about direction: a session the other way, or a socket sshd left
behind, puts that file on the machine being sat at too, and `test -S` alone then
sends *local* git to the other box's 1Password — the original bug, mirrored.
`$SSH_CONNECTION` is set by sshd only on the remote end, and a Herdr pane
inherits it from the server, so together they match exactly the sessions the
forward was made for. Neither side needs `ForwardAgent`.

`StreamLocalBindUnlink yes` (set by `run_after_sshd-tailnet.sh`) is not optional.
sshd does not remove a forwarded socket when the connection closes, so without it
the next attach reports

```
Warning: remote port forwarding failed for listen path /home/jonny/.ssh/1password-forwarded.sock
```

and every git operation in the pane then fails, because the file is still there
with nothing listening on it. What that looks like depends on who asks:
`ssh-add -l` says `Error connecting to agent: Connection refused`, while git and
ssh give up on the dead agent, fall back to the `IdentityFile`, and report

```
Load key "/home/jonny/.ssh/1password/github-personal.pub": invalid format
git@github.com: Permission denied (publickey).
```

which names the stub rather than the agent and reads like a key problem. It is
not. `IdentitiesOnly yes` leaves that public-key stub as the only candidate once
the agent is gone, and a stub is not a usable key on its own.

The same message appears, for the same reason, whenever no attach is live at all:
the socket file outlives the connection that bound it, so the path exists, the
`Match exec` test passes, and the agent behind it is gone. Fixed by attaching —
`herdr --remote minisforum-herdr` rebinds the path. This is only reachable when
nobody is attached, which is also when nobody is there to care; a fast, ugly
error beats the alternative of falling through to the far end's own 1Password and
hanging on a dialog on an unattended screen.

Verify from a pane on the remote box:

```bash
SSH_AUTH_SOCK=~/.ssh/1password-forwarded.sock ssh-add -l   # lists the local machine's keys
ssh -T git@github.com                                      # greets you as jonnyasmith
```

The exposure this accepts: while attached, anything running as this user — or as
root — on the remote machine can send signing requests to 1Password here. Every
request still needs approval on this side, so the worst case is an unexpected
prompt to decline, not silent use of a key. That trade is only acceptable because
the far end is a personal tailnet host.

### Which key a repo gets

ssh sees a hostname, never a repo, so the host in the remote URL is what selects
the key. Git rewrites that host for work orgs and switches the commit email off
the same URL. Below, `ORG` is a work GitHub org named at `chezmoi init` — the
repo itself holds no org name and no work address:

| Remote as cloned | Pushes to | Key | Commit email |
|---|---|---|---|
| `git@github.com:ORG/x.git` | `git@github-work:ORG/x.git` | work | work |
| `ssh://git@github.com/ORG/x.git` | `git@github-work:ORG/x.git` | work | work |
| `git@github-work:ORG/x.git` | unchanged | work | work |
| `git@ssh.dev.azure.com:v3/…` | unchanged | `azure-work` (RSA) | work |
| anything else on `github.com` | unchanged | personal | `jonny.asmith@gmail.com` |

So a work repo clones with its ordinary GitHub URL and still authenticates as
the work account. Two pieces do it, both generated into
`~/.config/git/config.local` and keyed off the org prefix:

- `[url "git@github-work:ORG/"]` with two `insteadOf` values — scp-style and
  `ssh://`. This is what makes ssh reach for the work key.
- `[includeIf "hasconfig:remote.*.url:…"] path = config.work`, which sets only
  the email. Three URL forms are listed because `hasconfig` matches the URL **as
  stored**, before the rewrite, and a repo may also have been cloned straight
  from the alias. The trailing `/` before `**` is required — `**` is only
  wildcard-magic directly after a slash, so `ORG**` matches nothing while
  failing silently.

`workOrgs` is a list of **remote owners**, not specifically of organisations —
whatever sits between `github.com:` and the repo name. A work repo owned by a
personal-style account rather than by the org needs its own entry; the org slug
does not cover it. Adding one needs nothing in `~/.ssh`: one alias serves every
owner on the same account, and `config.local.tmpl` ranges over the list.

Because `promptStringOnce` only asks when the key is absent, re-running
`chezmoi init` will **not** revise an existing answer. Edit `workOrgs` in
`~/.config/chezmoi/chezmoi.toml` and `chezmoi apply`.

A missing owner fails in a way that points at the wrong thing. The bottom row of
the table takes over: no rewrite, so ssh offers the personal key, and GitHub
answers `ERROR: Repository not found` — it masks "no access" as "no such repo",
so the URL looks wrong when the identity is. The `includeIf` blocks miss on the
same prefix, so commits are authored with the personal address and nothing warns.
Confirm with `ssh -T git@github.com` (greets you as the personal account),
`git ls-remote --get-url origin` (shows whether the rewrite fired) and
`git whoami`. Fix `workOrgs`; do not hand-edit the remote to `github-work`,
which corrects the key and leaves the email wrong.

For what a URL cannot express — a personal fork of a work repo, a client repo
outside the org — `git work` and `git personal` set `user.email` in the current
repo only, and `git whoami` prints the effective one. `git work` comes from
`config.local`, so it exists only on a work machine.

### Keeping the employer name out of the repo

This repo is public and work scans public repos for the company name, so no
file here contains it. `.chezmoi.toml.tmpl` asks three questions the first time
`chezmoi init` runs and writes the answers to `~/.config/chezmoi/chezmoi.toml`,
outside the repo:

| Prompt | Data key |
|---|---|
| Work machine (adds a second git identity) | `work` |
| Work GitHub org(s), comma-separated | `workOrgs` |
| Work git email | `workEmail` |

`promptBoolOnce`/`promptStringOnce` only ask when the key is absent, so a later
`chezmoi init` is silent. To change an answer, edit
`~/.config/chezmoi/chezmoi.toml` and re-run `chezmoi init` — that file is
rendered by `init` alone, never by `apply`. It restates `sourceDir`, because the
template owns the whole file and `init` would otherwise drop it and start
looking in `~/.local/share/chezmoi`.

Only two targets consume the answers, and both are generated:
`dot_config/git/config.local.tmpl` (the rewrites) and
`dot_config/git/config.work.tmpl` (the email). Answer `false` to the work prompt
and both render to zero bytes; chezmoi deletes an empty target, so
`~/.config/git/config` is left with two `[include]`s pointing at files that do
not exist, which git ignores silently. Nothing else in the repo is a template
for this reason — keep it that way, and put anything employer-shaped behind
these keys.

`.chezmoidata` cannot do this job: chezmoi reads those files verbatim rather
than as templates, and they would be tracked here anyway.
