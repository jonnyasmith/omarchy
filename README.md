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
repo-local: `AGENTS.md`, `README.md`, and `mise.toml`. That last entry is
pre-emptive — `mise use <tool>` without `-g` writes a project-local `mise.toml`
into the current directory, and run from here that file becomes a source entry
targeting `~/mise.toml`. Use `mise use -g` to reach the global set in
`dot_config/mise/config.toml`.

## New Machine

`sourceDir` is non-default, so name it explicitly instead of letting `init`
pick `~/.local/share/chezmoi`:

```bash
chezmoi init --source ~/dev/dotfiles --apply <git-remote-url>
```

No remote is configured yet; add one with
`git remote add origin <url> && git push -u origin master`.

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
`extended-keys always`. Herdr drops the `Ctrl` off punctuation keys, so inside
`h` only `Alt+;` accepts.

That last one restricts inline suggestions to shell history, matching zsh.
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

The leader is `ctrl+a`, not herdr's default `ctrl+space`. Consequence: `ctrl+a`
no longer reaches readline (`beginning-of-line`) or a nested tmux inside a
herdr pane.

Only `~/.config/herdr/config.toml` is managed. The sibling files herdr writes
there — `session.json`, `.plugins.lock`, `release-notes.json`, the two logs —
are runtime state and stay out of the repo.

```bash
herdr config check          # validate the file
herdr server reload-config  # apply it to the running server, no restart
```

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

`run_onchange_after_omarchy-themed.sh.tmpl` is keyed on both templates and both
hooks and runs `omarchy-theme-refresh`, which re-renders and re-fires the hooks
without changing the background. That is what converges a fresh machine or an
edited template; every theme switch after that is the hook's own job.

## mise global tools

`dot_config/mise/config.toml` is the global [mise](https://mise.jdx.dev/) tool
set — the one mise reads for every directory that has no closer config, and the
only mise file tracked here. Omarchy's bash rc already runs `mise activate`, so
nothing in this repo wires it up; `chezmoi apply` then `mise install` is the
whole restore path on a new machine.

| Tool | Pin |
|---|---|
| `azure-cli`, `claude`, `cmake`, `codex`, `gh`, `go`, `oh-my-pi`, `uv`, `zig` | `latest` |
| `bun` | `1` |
| `dotnet` | `10`, `8` |
| `node` | `26`, `24`, `22` |
| `pnpm` | `11`, `10` |
| `python` | `3.14`, `3.13` |

Runtimes are pinned to a major and listed newest-first — mise installs every
version in the list and treats the first as the default, so a project
`mise.toml` asking for an older major finds it already on disk. The CLIs float,
since they are self-contained binaries that are only useful current. `oh-my-pi`
is a registry alias for the `github:can1357/oh-my-pi` backend, which installs
from release assets rather than from a version-managed tool source; the short
name is the one to use, since spelling the backend out declares the same tool
under a second name and mise installs it twice.

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
  `omarchy-theme-refresh`. Keyed on the hashes of the two files above and of the
  two starship files, since both bridges converge the same way.

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

Most of the tree is the template as it shipped. `lua/community.lua`,
`lua/polish.lua`, and `lua/plugins/{user,astrocore,astroui,astrolsp,mason,none-ls,treesitter}.lua`
all still open with `if true then return {} end`, and `dot_config/nvim/README.md`
is still the template's own readme. They are tracked verbatim so the commented
examples stay to hand; none of them affect a running nvim. Four files do the
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

Two things to know when editing any bar widget:

- **Bar widget QML changes need `omarchy restart shell`.** Saving under
  `~/.config/omarchy/plugins/` logs `Local plugin changed, reloading` and
  `omarchy-shell shell rescanPlugins` returns cleanly, but neither
  re-instantiates an already-mounted bar widget. The old component keeps
  running and the edit looks like it did nothing.
- **`dot_config/omarchy/shell.json` is managed**, because that is where the bar
  layout lives and a widget has to be listed there to appear at all. The
  shell rewrites this file itself whenever the bar is reordered by dragging or
  by `omarchy bar move`, so expect it to drift; re-`chezmoi add` after
  deliberate layout changes.

## Dev ports

A list of the local dev servers that are actually listening, labelled by the
project each one was started from, one click from opening in the browser.

| Path | What |
|---|---|
| `dot_config/omarchy/plugins/jonny.ports/executable_ports.sh` | the whole scan; usable on its own |
| `dot_config/omarchy/plugins/jonny.ports/` | the bar widget (`manifest.json` + `BarWidget.qml`) |

```bash
~/.config/omarchy/plugins/jonny.ports/ports.sh          # 3000-9999
~/.config/omarchy/plugins/jonny.ports/ports.sh 1024 65535
```

It prints one TSV row per port — `port`, label, detail — and the widget only
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
socket-activated and disabled, and waking it to draw a bar widget would defeat
the point of that.

Four details that are easy to get wrong:

- **One port, two sockets.** IPv4 and IPv6 binds are separate `ss` rows. The
  first labelled row for a port wins and the rest are dropped, or portainer
  shows up twice.
- **Always `localhost`, never the bound address.** Vite binds `[::1]` only, so
  a URL built from the observed address as `127.0.0.1:5173` is a dead link.
- **A socket has no scheme.** `ss` cannot tell you that a port wants https, so
  ports that do are listed in `httpsPorts` on the `shell.json` entry.
- **`shellQuote` is not on the bar.** Omarchy's bar README lists
  `bar.shellQuote(value)` beside `bar.run(command)`, but only `run` exists;
  quoting lives on the `qs.Commons` `Util` singleton, as `Util.shellQuote`.
  Calling the documented one throws out of the click handler with nothing in
  the journal, so the row just looks dead.

Settings, all optional, inline on the `bar.layout` entry:

| Key | Default | What |
|---|---|---|
| `minPort` / `maxPort` | `3000` / `9999` | port window, which is what keeps `:53` and `:631` out |
| `interval` | `10` | seconds between scans while collapsed |
| `openInterval` | `2` | seconds between scans while the popup is open |
| `httpsPorts` | `[]` | ports whose URL should be `https://` |

Widget gestures:

| Gesture | Action |
|---|---|
| left | popup: one row per port |
| left on a row | open it as its own window |
| left on a row's  | open it as a tab in the default browser |
| middle | rescan now |

The popup is also summonable, so it can take a keybind:
`omarchy-shell shell toggle jonny.ports`.

The widget hides itself when nothing is listening, so it costs no bar space on
a machine that is not serving anything. It does still scan on the collapsed
interval to know that — the count has to come from somewhere — but the scan is
one `ss` call and a `readlink` per port, and it does not run per second.

Each row opens two ways, because neither one is right for every server. The row
itself runs `omarchy-launch-or-focus-webapp`, which gives the port a dedicated
window with no tab strip and no address bar — right for a dashboard, wrong when
you want devtools, and easily mistaken for a headless browser the first time it
appears. The  button on the row runs `omarchy-launch-browser` instead, which
is whatever `xdg-settings` calls the default browser, so the URL lands as an
ordinary tab in the session you already have open.

Two implementation notes. The row's full-width mouse area is declared *before*
the button, because QML delivers a click to the last overlapping sibling, so the
reverse order silently eats every button press. And the row highlight follows
either area, since hovering the button leaves the row's own.

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

A second org needs nothing in `~/.ssh` — one alias serves every org on the same
account. Add it to `workOrgs` and re-run `chezmoi init`; `config.local.tmpl`
ranges over the list.

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
