#!/bin/bash
#
# The keyboard half of the dev-ports widget: pick a listening dev server, open
# it, exit. Meant to be run by `omarchy launch tui --app-id=TUI.float`, so the
# floating terminal it lives in closes the moment this script returns -- which
# is why nothing here waits on the thing it launched.
#
# It lives beside `ports.sh` and the bar widget because all three share one
# contract: `ports.sh` prints `port <TAB> label <TAB> detail` and owns every
# piece of the awkwardness. The widget draws that TSV for the mouse, this
# draws it for the keyboard, and neither parses a socket itself.
#
#   enter      open as a webapp window (no tab strip, no address bar)
#   alt-enter  open as an ordinary browser tab, for devtools and sessions
#   ctrl-r     rescan
#   esc        quit, having done nothing
#
# `--rows` is this script calling itself: fzf's reload binding needs a command
# it can re-run, and pointing it back here beats embedding the awk program in
# a string that has to survive both bash and sh quoting.

set -uo pipefail

self=$(readlink -f "$0")
here=$(dirname "$self")

# The active Omarchy theme, rendered by `omarchy theme set` into the current
# theme's state directory. Loaded before the --rows branch below so a reload
# draws in the same colours as the first paint. Absent on a machine that has
# not had a theme applied yet, in which case fzf's own defaults and a plain
# ANSI dim are what is left.
palette="${XDG_STATE_HOME:-$HOME/.local/state}/omarchy/current/theme/fzf.env"
FZF_THEME_OPTS="" FZF_THEME_ACCENT="" FZF_THEME_DIM=""
# shellcheck source=/dev/null
[[ -r $palette ]] && source "$palette"

# fzf takes hex; a terminal escape does not. Truecolor rather than the nearest
# of 256, because the theme's accent is an exact colour and foot renders it.
ansi_fg() {
  local hex=${1#\#}
  [[ $hex =~ ^[0-9a-fA-F]{6}$ ]] || return 1
  printf '\033[38;2;%d;%d;%dm' \
    "$((16#${hex:0:2}))" "$((16#${hex:2:2}))" "$((16#${hex:4:2}))"
}

# Dim is the fallback rather than nothing: it is the one attribute that follows
# whatever palette the terminal itself is using.
port_colour=$(ansi_fg "$FZF_THEME_ACCENT") || port_colour=$'\033[2m'
detail_colour=$(ansi_fg "$FZF_THEME_DIM") || detail_colour=$'\033[2m'

# All three columns are visible and therefore all three are searchable: the
# project directory, the port, and the command line. The command line is the
# reason -- two checkouts of the same repo are both `acme-web`, and the only
# thing that tells them apart is the path in the argv. It used to be a preview
# pane, which showed it for one row at a time and kept it out of the query.
#
# Padded here rather than left to fzf's --with-nth, which would print the raw
# tabs and leave the columns jumping about as label lengths change. Only the
# label is truncated: fzf matches the whole string and lets the terminal cut
# the display, so a long argv stays searchable without widening every row. The
# port is repeated as a hidden trailing field because the visible one carries
# ANSI escapes, so it is no longer safe to parse.
rows() {
  "$here/ports.sh" "$1" "$2" |
    awk -F'\t' -v c="$port_colour" -v d="$detail_colour" -v r=$'\033[0m' \
      '{ printf "%-22.22s %s:%-5s%s %s%s%s\t%s\n", $2, c, $1, r, d, $3, r, $1 }'
}

if [[ ${1:-} == --rows ]]; then
  rows "${2:-3000}" "${3:-9999}"
  exit 0
fi

# Both surfaces read their port range and their https list from the same place:
# the widget's own entry in shell.json, whose bare keys are its settings
# (`entrySettings` in shell/plugins/bar/BarModel.js strips only `id`). Without
# this the two would silently disagree the day either is configured.
config="${XDG_CONFIG_HOME:-$HOME/.config}/omarchy/shell.json"
min=3000 max=9999 https=""
if command -v jq >/dev/null 2>&1 && [[ -f $config ]]; then
  IFS=$'\t' read -r min max https < <(
    jq -r '
      ([.. | objects | select(.id? == "jonny.ports")] | first) // {}
      | "\(.minPort // 3000)\t\(.maxPort // 9999)\t\((.httpsPorts // []) | join(" "))"
    ' "$config" 2>/dev/null
  ) || { min=3000 max=9999 https=""; }
  [[ $min =~ ^[0-9]+$ ]] || min=3000
  [[ $max =~ ^[0-9]+$ ]] || max=9999
fi

# Explicit arguments still win, so this is usable by hand outside the bar.
min=${1:-$min}
max=${2:-$max}

listing=$(rows "$min" "$max")
if [[ -z $listing ]]; then
  # A terminal that opens and closes faster than you can read it is no way to
  # deliver one line, so on a desktop this goes to the notification surface
  # instead. Outside one -- a plain shell, a pipe -- stdout is still right.
  message="No dev servers listening on :$min-:$max."
  if [[ -n ${HYPRLAND_INSTANCE_SIGNATURE:-} ]] && command -v omarchy-notification-send >/dev/null 2>&1; then
    omarchy-notification-send -g 󰒍 "Dev ports" "$message"
  else
    echo "$message"
  fi
  exit 0
fi

# Unquoted on purpose: one flag per word, and the rendered value has no spaces
# in it. Empty when no theme has been rendered, which fzf reads as no flags.
# shellcheck disable=SC2086
selection=$(
  printf '%s\n' "$listing" | fzf \
    --ansi \
    --delimiter=$'\t' \
    --with-nth=1 \
    --no-multi \
    --cycle \
    --layout=reverse \
    --info=inline \
    --height=100% \
    --pointer='▌' \
    --prompt='dev port  ' \
    --header='enter open · alt-enter browser tab · ctrl-r rescan · esc quit' \
    --bind="ctrl-r:reload($(printf '%q' "$self") --rows $min $max)" \
    --expect=alt-enter \
    $FZF_THEME_OPTS
) || exit 0

# --expect puts the key on the first line, blank when it was plain enter.
key=$(sed -n 1p <<<"$selection")
line=$(sed -n 2p <<<"$selection")
[[ -n $line ]] || exit 0

port=$(cut -f2 <<<"$line")
[[ $port =~ ^[0-9]+$ ]] || exit 1

# Always localhost, never the address ss reported: Vite binds [::1] only, so a
# literal 127.0.0.1 URL built from the port would be a dead link.
scheme=http
for p in $https; do [[ $p == "$port" ]] && scheme=https; done
url="$scheme://localhost:$port"

# Hand the launch to Hyprland instead of running it here, because this process
# is about to die: the terminal closes with it. Chromium's `--app=` request is
# made by a short-lived child that hands the URL to the already-running
# browser, and that child is killed along with the terminal's scope before the
# browser opens the window -- so `enter` looked like it did nothing at all,
# while `alt-enter` worked, since `omarchy-launch-browser` starts the browser
# as a transient unit's own main process. `exec`, `setsid --fork` and
# `systemd-run` (both --service and --scope) all fail the same way: the fix is
# not detachment, it is that something which is not exiting has to do the
# spawning. The bar widget never had the bug because `bar.run()` spawns from
# the long-lived omarchy-shell; Hyprland is the equivalent long-lived process a
# script can reach.
#
# `exec_cmd` is the Lua dispatcher name -- `hyprctl dispatch exec <cmd>` is no
# longer parsed by this Hyprland, it returns a Lua syntax error and rc=7. Both
# arguments are built from a digits-only port, so the quoting is safe.
if [[ $key == alt-enter ]]; then
  command="omarchy-launch-browser $url"
else
  command="omarchy-launch-or-focus-webapp localhost:$port $url"
fi

hyprctl dispatch "hl.dsp.exec_cmd(\"$command\")" >/dev/null
