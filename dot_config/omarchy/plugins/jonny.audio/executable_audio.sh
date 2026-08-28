#!/bin/bash
#
# Lists every audio output this machine can reach, one TSV row each:
#
#   current <TAB> kind <TAB> sink <TAB> label <TAB> detail
#
#   current  `*` for the default sink, `-` for the rest -- never empty, see below
#   kind     `airplay` or `local`
#   sink     PipeWire sink name, the only field the picker acts on
#   label    what the device calls itself ("Kitchen", "Logi Dock Analog Stereo")
#   detail   model and address for AirPlay, bus and profile for local
#
# Two sources, because neither is enough on its own. `pactl` knows which sinks
# exist and which one is default, but an AirPlay sink carries none of the mDNS
# metadata that says what the box on the shelf actually is -- PipeWire keeps
# raop.ip and device.model in the module args, and a pulse-loaded discovery
# module does not expose those through pactl at all. So the model comes from
# avahi's own cache, keyed by the hostname/ip/port triple that
# module-raop-discover builds every raop sink name out of. avahi-browse reads
# that cache rather than the network, so it costs milliseconds.
#
# Runs standalone: `audio.sh` prints the table, and every consumer parses the
# same TSV rather than pactl's output shape.

set -uo pipefail

# Apple's model strings are what the mDNS record carries; nobody thinks of a
# speaker as an "AudioAccessory1,1". Unknown models fall through as themselves,
# which is more useful than "AirPlay device".
friendly() {
  case $1 in
    AudioAccessory1,*) echo "HomePod" ;;
    AudioAccessory5,*) echo "HomePod mini" ;;
    AudioAccessory6,*) echo "HomePod (2nd gen)" ;;
    AppleTV*) echo "Apple TV" ;;
    AirPort*) echo "AirPort Express" ;;
    *) echo "$1" ;;
  esac
}

# hostname.ip.port -> model, exactly the key module-raop-discover names its
# sinks after (raop_sink.Kitchen.local.192.168.86.84.7000).
declare -A model addr
while IFS=';' read -r tag _ _ _ _ _ host ip port txt; do
  [[ $tag == '=' ]] || continue
  [[ $txt =~ am=([^\"]+) ]] || continue
  model["$host.$ip.$port"]=${BASH_REMATCH[1]}
  addr["$host.$ip.$port"]=$ip
done < <(timeout 3 avahi-browse -rtp _raop._tcp 2>/dev/null)

default=$(pactl get-default-sink 2>/dev/null)

# Every field is printed as `-` rather than left empty, on both sides of this
# loop. Tab is IFS *whitespace* in bash, so a run of tabs collapses to one and
# an empty field silently shifts every field after it -- which showed up as an
# AirPlay sink's name appearing in the detail column.
#
# AirPlay first: those are the outputs being looked for, and the ones the bar's
# own volume menu will not switch to. Local sinks keep their pactl order below.
while IFS=$'\t' read -r name description api bus profile; do
  [[ -n $name ]] || continue
  for f in description api bus profile; do
    [[ ${!f} == - ]] && declare "$f="
  done

  if [[ $name == raop_sink.* ]]; then
    key=${name#raop_sink.}
    kind=airplay
    detail=$(friendly "${model[$key]:-AirPlay}")
    [[ -n ${addr[$key]:-} ]] && detail+=" · ${addr[$key]}"
  else
    kind=local
    detail=$profile
    [[ -n $bus ]] && detail=${detail:+$detail · }$bus
    [[ -n $detail ]] || detail=$api
  fi

  cur='-'
  [[ $name == "$default" ]] && cur='*'
  printf '%s\t%s\t%s\t%s\t%s\n' "$cur" "$kind" "$name" "${description:-$name}" "${detail:--}"
done < <(
  pactl -f json list sinks 2>/dev/null |
    jq -r 'def d: if . == null or . == "" then "-" else . end;
      sort_by(.name | startswith("raop_sink.") | not) | .[] |
      [ .name,
        (.description | d),
        (.properties."device.api" | d),
        (.properties."device.bus" | d),
        (.properties."device.profile.description" | d)
      ] | @tsv'
)
