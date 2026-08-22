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

## mise global tools

`dot_config/mise/config.toml` is the global [mise](https://mise.jdx.dev/) tool
set — the one mise reads for every directory that has no closer config, and the
only mise file tracked here. Omarchy's bash rc already runs `mise activate`, so
nothing in this repo wires it up; `chezmoi apply` then `mise install` is the
whole restore path on a new machine.

| Tool | Pin |
|---|---|
| `claude`, `codex`, `gh`, `pnpm`, `zoxide` | `latest` |
| `github:can1357/oh-my-pi` | `latest` |
| `node` | `26.7.0` |

`node` is pinned exact because it is the runtime everything else resolves
against; the CLIs float, since they are self-contained binaries that are only
useful current. The `github:` backend installs from release assets rather than a
registry entry, so it needs the full `owner/repo` as the key.

`[settings] minimum_release_age = "7d"` is the counterweight to all that
floating: a `latest` resolved the day it ships is a supply-chain window, so mise
ignores any release younger than a week. It applies to every tool here,
including the `github:` backend.

`zoxide` is the one entry that duplicates a pacman package — Omarchy installs
`zoxide 0.10.0-1` and its bash rc initialises it. The mise shim wins on `PATH`,
so the pinned copy is the one that runs, and the pacman package is what a
machine without `mise install` falls back to. Both are currently 0.10.0.

`mise up` bumps the floating ones and rewrites this file in place — it is the
live file that changes, so `chezmoi re-add ~/.config/mise/config.toml`
afterwards. Per-project `mise.toml` files stay with their projects and are not
managed here; note that plain `mise use <tool>` writes one into the current
directory, so global changes need `mise use -g`.

## Neovim keymaps

`dot_config/nvim/` holds two files layered on top of the `omarchy-nvim`
package's LazyVim starter. That package installs into
`/etc/skel/.config/nvim/`, so `omarchy update` never touches the live config
and these two files are the only nvim state tracked here.

`lua/config/keymaps.lua` maps `<leader>w` to `:w`, which is AstroNvim's save
binding. LazyVim leaves `<leader>w` unmapped and uses it as a which-key proxy
for `<C-w>`, with two real maps beneath it — `<leader>wd` (delete window) and
`<leader>wm` (zoom). Both are deleted first: while either exists, every save
waits out `timeoutlen` (300ms in LazyVim) to disambiguate the longer sequence.
Nothing is actually lost. `<leader>wd` was `<C-w>c`, every window command is
still on `<C-w>`, which-key's window hydra is still on `<C-w><Space>`, and
LazyVim maps zoom to `<leader>uZ` on the same line as `<leader>wm`.

`lua/plugins/which-key.lua` demotes the now-childless `windows` group to a
plain `Save` entry via `group = false, proxy = false, expand = false`. LazyVim
declares `opts_extend = { "spec" }` on which-key, so a later spec entry for the
same key merges over the stock one instead of replacing the list.

`<C-s>` still saves as well; LazyVim maps it in `i`/`x`/`n`/`s` modes and that
is left alone.

## Hyprland input

`dot_config/hypr/input.lua` is the user-side Hyprland input override, loaded
after Omarchy's defaults. It sets
`kb_options = "caps:swapescape,shift:both_capslock_cancel"`, swapping Caps Lock
and Escape. This drops Omarchy's default `compose:caps`, so Caps Lock is no
longer the Compose key. Use `caps:escape` instead if Escape should not become
Caps Lock.

Validate after `chezmoi apply` with `hyprctl reload && hyprctl configerrors`.

## Caffeine

A keep-awake toggle, as a bar widget next to the battery. Three managed parts:

| Path | What |
|---|---|
| `dot_local/bin/executable_caffeine` | the whole state machine; usable on its own |
| `dot_config/omarchy/plugins/jonny.caffeine/` | the bar widget (`manifest.json` + `BarWidget.qml`) |
| `dot_config/omarchy/extensions/omarchy-menu.jsonc` | the preset submenu the widget's right-click summons |

```bash
caffeine on            # indefinitely
caffeine on 90m --lid  # 90 minutes, lid close held too
caffeine off
caffeine status --json
```

Omarchy has no suspend-on-idle at all: the shell's idle service only runs a
screensaver at `idle.screensaver` and locks at `idle.lock`, both seconds, both
in `~/.config/omarchy/shell.json`. So "stay awake" here means suppressing those
two, which is what Omarchy's own stay-awake flag —
`~/.local/state/omarchy/indicators/stay-awake` — already does. `caffeine`
writes that same file rather than inventing a second source of truth, so it
stays in lockstep with `omarchy toggle idle`, the built-in StayAwake indicator,
and the Omarchy menu. The idle service watches that directory, so whoever
writes it, everyone sees it.

Expiry is a transient systemd **user** timer, the mechanism `omarchy reminder`
already uses, so the deadline survives a shell restart and is inspectable with
`systemctl --user list-timers caffeine-expire.timer`. The script publishes that
deadline to `~/.local/state/omarchy/caffeine.json`; the widget watches that one
file and ticks the countdown locally, so nothing polls and no subprocess runs
per second.

`--lid` is the only part that is not just the stay-awake flag. Lid close is
logind's business (`HandleLidSwitch=suspend`) and ignores the flag entirely, so
that mode additionally holds a real
`systemd-inhibit --what=handle-lid-switch:idle:sleep` lock in a transient unit,
released the moment caffeine stops. It shows a different glyph — a crossed-out
`Zz` rather than the coffee cup — because a held lid inhibitor is how a laptop
cooks itself in a bag, and it should never be ambiguous which mode is armed.

Widget gestures:

| Gesture | Action |
|---|---|
| left | toggle indefinitely |
| right | preset submenu (15m / 30m / 1h / 2h / indefinite / lid) |
| middle | drop the timer, stay awake indefinitely |
| scroll | ±15 min on the live deadline |

Scrolling down on an indefinite session sets a 15-minute window; scrolling
below one minute turns it off.

Two things to know when editing this:

- **Bar widget QML changes need `omarchy restart shell`.** Saving under
  `~/.config/omarchy/plugins/` logs `Local plugin changed, reloading` and
  `omarchy-shell shell rescanPlugins` returns cleanly, but neither
  re-instantiates an already-mounted bar widget. The old component keeps
  running and the edit looks like it did nothing.
- **`dot_config/omarchy/shell.json` is managed**, because that is where the bar
  layout lives and the widget has to be listed there to appear at all. The
  shell rewrites this file itself whenever the bar is reordered by dragging or
  by `omarchy bar move`, so expect it to drift; re-`chezmoi add` after
  deliberate layout changes.

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
