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

`chezmoi status` always lists `R omarchy-fingerprint-skill.sh`. `R` means "this
script runs on the next apply", which is by design (see below) — it is not
drift. Judge state by `chezmoi apply` output, which is silent when there is
nothing to do.

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
`Ctrl+Space` to accept a suggestion, `Esc` to dismiss it, `Shift+Enter` for a
literal newline, and `complete_auto_complete_opts=syntax-disabled`.

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

## Starship prompt

`dot_config/starship.toml` is the prompt Omarchy's bash rc initialises. `format`
is a single explicit string — directory, git branch, git state, git status,
exit status — so every module Starship enables by default (language versions,
cloud contexts, `$cmd_duration`, …) is excluded by omission rather than disabled
one by one. The `$schema` key is inert at runtime; it buys completion and
validation in any editor with a TOML language server.

`$line_break` before `$character` puts the `❯` on its own line, leaving the
full terminal width for the command regardless of how long the path and branch
get. `add_newline = true` is separate: it is the blank line *above* the prompt.

`$git_state` is what makes a rebase visible — without it a detached mid-rebase
HEAD renders like any other branch. `$status` sits at the end of the top line
rather than next to `❯`, so the cursor line stays clean; the `✗` character
already says *that* a command failed, `$status` adds *which* code.

`[directory] read_only` is set to a nerd-font glyph because the default is the
emoji `🔒` and `repo_root_format` references `$read_only`. Every other module
overridden here is monochrome cyan; the exceptions are deliberate warnings —
`read_only` keeps its red default, as does `battery` below its 10% threshold.

`right_format` (sudo, jobs, battery, time) only exists thanks to ble.sh. Bash
has no RPROMPT, and `starship init bash` emits the right prompt solely inside
`if [[ ${BLE_ATTACHED-} ]]`, as `bleopt prompt_rps1`. On a machine without the
ble.sh package it silently disappears. That same init prefixes the value with
one newline per newline in `PS1`, so with `$line_break` the right prompt lands
on the `❯` row. `sudo` and `time` need explicit `disabled = false`; both are
off by default, which is why the equivalent block in the old zsh config never
rendered anything but `$jobs`.

`command_timeout = 200` caps per-module work; the git modules are the only ones
that can hit it, on a large repo.

## Hyprland input

`dot_config/hypr/input.lua` is the user-side Hyprland input override, loaded
after Omarchy's defaults. It sets
`kb_options = "caps:swapescape,shift:both_capslock_cancel"`, swapping Caps Lock
and Escape. This drops Omarchy's default `compose:caps`, so Caps Lock is no
longer the Compose key. Use `caps:escape` instead if Escape should not become
Caps Lock.

Validate after `chezmoi apply` with `hyprctl reload && hyprctl configerrors`.

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
