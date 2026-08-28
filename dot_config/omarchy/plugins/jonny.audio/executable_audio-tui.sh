#!/bin/bash
#
# Pick where sound comes out: the speakers in this box, the dock, or any AirPlay
# receiver on the network -- the HomePods and Apple TVs around the house. Meant
# to be run by `omarchy launch tui --app-id=TUI.float`, so the floating terminal
# closes the moment this returns.
#
#   enter / l  make it the default output and move everything already playing
#   alt-t      play a test tone on the highlighted device, without switching
#   r          rescan: reload AirPlay discovery, then redraw
#   esc / q    quit, having changed nothing
#
# Switching is two operations, not one. `set-default-sink` only decides where
# the *next* stream goes; anything already playing keeps its old sink until it
# is moved, which is why a switch that only set the default looked like it did
# nothing while music was on.
#
# Rescan exists because an AirPlay sink is fragile: module-raop-sink destroys
# itself on any RTSP error (a device that hangs up, or refuses the session
# outright), and module-raop-discover will not recreate it until the mDNS
# service reappears -- which for a device that never left the network is never.
# Native discovery is part of the PipeWire daemon, so rebuilding its sinks
# requires restarting that daemon. PipeWire Pulse and WirePlumber reconnect to
# its systemd socket; they do not need restarting.
#
# `--rows` is this script calling itself, so fzf's reload binding has a command
# to re-run rather than an awk program quoted through two shells.

set -uo pipefail

self=$(readlink -f "$0")
here=$(dirname "$self")

tone=/usr/share/sounds/freedesktop/stereo/audio-test-signal.oga

# The active Omarchy theme, rendered by `omarchy theme set` into the current
# theme's state directory. Loaded before the --rows branch so a reload draws in
# the same colours as the first paint.
palette="${XDG_STATE_HOME:-$HOME/.local/state}/omarchy/current/theme/fzf.env"
FZF_THEME_OPTS="" FZF_THEME_ACCENT="" FZF_THEME_DIM=""
# shellcheck source=/dev/null
[[ -r $palette ]] && source "$palette"

# fzf takes hex; a terminal escape does not.
ansi_fg() {
  local hex=${1#\#}
  [[ $hex =~ ^[0-9a-fA-F]{6}$ ]] || return 1
  printf '\033[38;2;%d;%d;%dm' "0x${hex:0:2}" "0x${hex:2:2}" "0x${hex:4:2}"
}

accent=$(ansi_fg "$FZF_THEME_ACCENT") || accent=$'\033[2m'
dim=$(ansi_fg "$FZF_THEME_DIM") || dim=$'\033[2m'
reset=$'\033[0m'

# FontAwesome, both in the BMP private-use area: every Nerd Font build has
# them, unlike the Material Design ranges above U+F0000.
speaker=$'\uf028'
wifi=$'\uf1eb'

# One visible column plus a hidden one: fzf matches the whole line, so the
# device name, the model and the address are all searchable, while --with-nth=1
# keeps the sink name -- which is long, ugly and the only thing acted on -- out
# of sight. Padded here rather than by --with-nth, which would print raw tabs.
rows() {
  local cur kind sink label detail icon mark
  while IFS=$'\t' read -r cur kind sink label detail; do
    if [[ $kind == airplay ]]; then icon=$wifi; else icon=$speaker; fi
    [[ $detail == - ]] && detail=""
    mark=" "
    [[ $cur == '*' ]] && mark=$'\u2713'
    printf '%s%s%s %s %-28.28s %s%s%s\t%s\n' \
      "$accent" "$icon" "$reset" "$mark" "$label" "$dim" "$detail" "$reset" "$sink"
  done < <("$here/audio.sh")
}

if [[ ${1:-} == --rows ]]; then
  # Native module reload plus the second or two Avahi's answers take to come
  # back; without the wait the redraw shows a shorter list than reality.
  if [[ ${2:-} == --rescan ]]; then
    systemctl --user restart pipewire.service
    sleep 2
  fi
  rows
  exit 0
fi

listing=$(rows)
if [[ -z $listing ]]; then
  printf '%s\n' "No audio outputs. Is pipewire running?" >&2
  sleep 2
  exit 1
fi

# Normal mode by default -- j/k move, l or enter switches, `/` searches -- out
# of ../jonny.lib/vim-fzf.sh, so this picker and the other two share one set of
# keys. alt-t is a chord, so it works in search mode too and is bound here.
# shellcheck source=../jonny.lib/vim-fzf.sh
source "$here/../jonny.lib/vim-fzf.sh"

line=$(
  printf '%s\n' "$listing" |
    vfzf --ctx "$accent$speaker  audio output$reset" \
      --keys 'alt-t test tone · r rescan' -- \
      --delimiter=$'\t' --with-nth=1 --info=inline-right \
      --bind="r:reload($(printf '%q' "$self") --rows --rescan)" \
      --bind="alt-t:execute-silent(pw-play --target {2} $tone >/dev/null 2>&1 &)"
) || exit 0
[[ -n $line ]] || exit 0

sink=$(vfzf_row "$line" | cut -f2)
[[ -n $sink ]] || exit 1

# Current HomePod firmware advertises a legacy RAOP sink even when Home access
# policy will reject it. PipeWire only finds that out after changing the
# default, then destroys the sink on the 403 response and leaves system audio
# pointed at a name that no longer exists. Probe the same RTSP endpoint first;
# a usable unauthenticated receiver answers OPTIONS with 200.
if [[ $sink == raop_sink.* ]]; then
  if [[ $sink =~ \.([0-9]+\.[0-9]+\.[0-9]+\.[0-9]+)\.7000$ ]]; then
    ip=${BASH_REMATCH[1]}
    status=$(
      timeout 3 bash -c '
        exec 3<>"/dev/tcp/$1/7000" || exit
        printf "OPTIONS * RTSP/1.0\r\nCSeq: 1\r\nUser-Agent: AirPlay/540.31\r\n\r\n" >&3
        IFS= read -r line <&3
        printf "%s" "$line"
      ' _ "$ip" 2>/dev/null
    )
  else
    status=""
  fi

  if [[ $status != *" 200 "* ]]; then
    notify-send -u critical "AirPlay access refused" \
      "In Apple Home: Home Settings → Speakers & TV → Anyone on the Same Network, with Require Password off."
    exit 1
  fi
fi

if ! pactl set-default-sink "$sink" 2>/dev/null; then
  notify-send -u critical "Audio output" "$sink is gone. Press r to rescan."
  exit 1
fi

# Everything already playing, moved in one pass. A stream that ended between
# the list and the move is not an error worth reporting.
while read -r id _; do
  [[ $id =~ ^[0-9]+$ ]] || continue
  pactl move-sink-input "$id" "$sink" 2>/dev/null
done < <(pactl list short sink-inputs 2>/dev/null)

label=$("$here/audio.sh" | awk -F '\t' -v sink="$sink" '$3 == sink { print $4; exit }')
notify-send "Audio output" "${label:-$sink}"
