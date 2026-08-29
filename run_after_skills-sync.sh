#!/usr/bin/env bash
#
# skills-sync — the whole of the skills TUI.
#
# `dot_config/omarchy/plugins/jonny.skills/skills.sh` is a launcher and nothing
# else: every panel, key and diff belongs to a Go program in a private repo,
# which finds the skills tree in a repo that keeps them anywhere from `skills/`
# to `.claude/skills/`, joins on the skill directory name, decides what
# diverged, and copies through a staging directory so a failed sync is
# non-destructive. The launcher lands with `chezmoi apply`; the binary has to
# be built.
#
# run_after_, not run_once_: the first line is a `command -v` and exits, so a
# machine that already has the binary pays nothing. `once_` state lives per
# machine in chezmoi's own database, which would mean a machine that failed the
# build once never retried it.
#
# Deliberately not `go install <module>@latest`: the repo is private, so the
# public checksum database rejects the module path. Building from a clone is the
# route the tool's own README documents, and it also means `go install .` picks
# up work in progress rather than a release.
#
# Cloning is left to a human on purpose. It needs the ssh key out of the
# 1Password agent, whose approval is a GUI prompt, and an apply that silently
# clones a repo into ~/dev is a surprise. The command is printed instead.
#
# Every failure exits 0. A missing binary costs the launcher one notification --
# "skills-sync is not installed" -- and nothing else; it never costs the apply.

set -uo pipefail

command -v skills-sync >/dev/null 2>&1 && exit 0
command -v go >/dev/null 2>&1 || exit 0

repo="$HOME/dev/skills-sync"
if [[ ! -d $repo ]]; then
	echo "skills-sync is not cloned. Run:"
	echo "  git clone git@github.com:jonnyasmith/skills-sync.git $repo"
	exit 0
fi

# GOBIN explicitly. Under mise the default is scoped to the active Go version,
# so every binary installed without it disappears on the next Go upgrade.
echo "Building skills-sync..."
if GOBIN="$HOME/.local/bin" go -C "$repo" install .; then
	echo "skills-sync installed to ~/.local/bin."
else
	echo "skills-sync build failed; the Skills row will say so when opened." >&2
fi

exit 0
