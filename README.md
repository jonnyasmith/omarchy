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
