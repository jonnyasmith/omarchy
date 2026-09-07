#!/usr/bin/env bash
#
# Blank backgrounds — first run.
#
# All the work is in the managed hook this calls,
# `dot_config/omarchy/hooks/theme-set.d/executable_solid-background.hook`, which
# generates one flat-colour PNG per installed theme into
# `~/.config/omarchy/backgrounds/<slug>/`. That hook only fires on
# `omarchy theme set`, so without this a fresh machine would sit on the stock
# wallpapers until the next theme change. Firing it here means the blank
# background exists the moment `chezmoi apply` finishes.
#
# run_after_, not run_once_: the hook skips every theme whose file already
# exists, so a populated machine costs one stat per theme (~35 ms) and a new
# theme installed later is picked up without touching chezmoi's state database.
#
# The current theme's name is passed, which is what makes the hook apply the
# background it just generated. On an already-populated machine nothing is
# generated, so nothing is applied and a deliberate `omarchy theme bg next`
# survives the apply.

set -uo pipefail

hook="$HOME/.config/omarchy/hooks/theme-set.d/solid-background.hook"
[[ -x $hook ]] || exit 0

theme=$(cat "$HOME/.local/state/omarchy/current/theme.name" 2>/dev/null)
[[ -n ${theme:-} ]] || exit 0

target="$HOME/.config/omarchy/backgrounds/$theme/0-solid.png"
existed=0
[[ -s $target ]] && existed=1

"$hook" "$theme" || exit 0

# Thumbnails, and only when this run is what created the file. The background
# switcher caches the current theme's folder alone, and omarchy-theme-set warms
# it after every theme change, so there is nothing to do on a machine that was
# already populated.
if [[ $existed == 0 && -s $target ]] && command -v omarchy-theme-bg-cache >/dev/null 2>&1; then
	omarchy-theme-bg-cache >/dev/null 2>&1
fi

exit 0
