#!/bin/bash
#
# Opens the skills-sync TUI: choose which agent skills to copy out of the
# skills repos you follow into the one you own, review the diff, sync.
# Meant to be run by `omarchy launch tui --app-id=TUI.float`.
#
# This is a launcher, not a UI. Everything visible belongs to `skills-sync`
# (~/dev/skills-sync), a Bubble Tea panel TUI whose keys are already the ones
# this desktop uses -- `j`/`k`, `space`, `g`/`G`, `q` -- and which does things
# no fzf picker can: two panes of repo membership, per-status bulk toggles, a
# scrollable diff beside the list it belongs to, and a directory browser for
# adding a repo. There was an fzf front end here for one evening; it was a
# worse subset of that, plus a tab-separated contract between the two halves,
# so it is gone.
#
# The launcher exists for the three things the binary must not know about:
#
#   1. the desktop's palette, sourced below and exported into its environment
#   2. `skills-sync` not being installed yet, which is a notification rather
#      than an error message in a window that has already closed
#   3. the window closing the instant the process exits -- see the pause
#
set -uo pipefail

glyph=$'\uf19d'

say() {
  if [[ -n ${HYPRLAND_INSTANCE_SIGNATURE:-} ]] && command -v omarchy-notification-send >/dev/null 2>&1; then
    omarchy-notification-send -g "$glyph" "Skills" "$1"
  else
    echo "$1" >&2
  fi
}

if ! command -v skills-sync >/dev/null 2>&1; then
  say $'skills-sync is not installed. Run:\ncd ~/dev/skills-sync && GOBIN=$HOME/.local/bin go install .'
  exit 1
fi

# The palette Omarchy rendered for us, if this desktop is the one running it.
# `set -a` because the binary reads the environment, not the file: the six
# names are its API and this is the only place they are set.
theme=${OMARCHY_THEME_DIR:-$HOME/.local/state/omarchy/current/theme}/skills-sync.env
if [[ -r $theme ]]; then
  set -a
  # shellcheck source=/dev/null
  source "$theme"
  set +a
fi

skills-sync "$@"
status=$?

# A floating terminal closes when its command exits, and everything that
# matters is printed *after* the TUI restores the screen: the plan, the
# `Proceed?` answer, the skills that were copied, and any error. Without this
# the window blinks out mid-sentence.
#
# Unconditional on purpose. There is no signal that separates "aborted, nothing
# to read" from "synced four skills" -- both exit 0 -- and inferring it from the
# wording of a message would make this script a parser of the other one's prose.
# One keystroke to dismiss a window is the cheaper end of that trade.
if [[ -t 0 ]]; then
  read -rsn1 -p $'\nPress any key to close. '
  echo
fi

exit $status
