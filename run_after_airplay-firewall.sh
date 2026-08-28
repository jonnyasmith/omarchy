#!/usr/bin/env bash
#
# Let HomePods finish a PipeWire RAOP session. The RTSP connection and audio
# packets leave this machine, but UDP transport also sends control and timing
# packets back to the ports PipeWire advertises in SETUP:
#
#   control_port=6001;timing_port=6002
#
# ufw's default incoming policy is deny. Without this narrow LAN rule, HomePod
# accepts OPTIONS and ANNOUNCE, then never answers SETUP; PipeWire still exposes
# the sink and applications keep playing into it, but the speaker is silent.
#
# The source is fixed to this house's /24, not Anywhere. Both managed machines
# use this network for these receivers; using RFC1918 wholesale would expose the
# ports on unrelated private networks when the laptop travels.

set -euo pipefail

command -v ufw >/dev/null 2>&1 || exit 0
pacman -Q pipewire-zeroconf >/dev/null 2>&1 || exit 0

if ! pkexec ufw status |
  grep -q '^6001:6002/udp *ALLOW *192\.168\.86\.0/24'; then
  echo "Allowing AirPlay control from the home LAN (needs root)..."
  pkexec ufw allow from 192.168.86.0/24 to any port 6001:6002 proto udp \
    comment 'AirPlay control and timing' >/dev/null
fi
