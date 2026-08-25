#!/usr/bin/env bash
#
# Desktops never sleep, so they stay reachable over the tailnet.
#
# This machine is remoted into from elsewhere (see "Inbound SSH over Tailscale"
# in the README). A suspended box is indistinguishable from a dead one: sshd is
# up, tailscaled is up, and the packets go nowhere. Wake-on-LAN is not a way
# back either — this host is on Wi-Fi, and a magic packet has to originate on
# the same L2 segment, which is exactly what being at the office rules out.
#
# Nothing here suppresses an *existing* idle-suspend, because there is none:
# Omarchy's idle service only runs the screensaver and the lock, and logind's
# IdleAction defaults to ignore. What this closes is the manual path -- the
# Suspend row in the system menu, `systemctl suspend` from a shell, a future
# Omarchy default that sets IdleAction -- one mis-click before leaving the house
# being enough to cost a day's remote access.
#
# Two layers, deliberately:
#
# 1. The sleep targets are masked. That is the enforcement: logind reaches every
#    sleep path (menu, D-Bus, power key, IdleAction) by queueing a job for
#    sleep.target, and a masked unit fails the job instead of running it. It
#    holds regardless of what any config file above it says.
# 2. `omarchy-toggle suspend-off` hides the menu row, so the UI stops offering
#    an action that would now fail with "Unit suspend.target is masked".
#
# Only desktop-class chassis opt in: closing a lid should still suspend, and an
# unrecognised machine should behave like a laptop rather than inherit this. The
# gate is the DMI chassis type rather than a hostname, so it is right on any
# future machine without an edit.
#
# Everything is guarded and idempotent: off a desktop, or once already applied,
# this does nothing at all.

set -euo pipefail

# 3 Desktop, 4 Low Profile Desktop, 5 Pizza Box, 6 Mini Tower, 7 Tower,
# 15 Space-saving, 16 Lunch Box, 17 Main Server Chassis, 23 Rack Mount,
# 35 Mini PC. This box reports 35; the XPS 15 is a Notebook, so it never
# reaches the masking below.
case "$(cat /sys/class/dmi/id/chassis_type 2>/dev/null)" in
  3 | 4 | 5 | 6 | 7 | 15 | 16 | 17 | 23 | 35) ;;
  *) exit 0 ;;
esac

announced=false
announce() {
  $announced && return 0
  echo "Masking sleep targets so this desktop stays reachable (needs root)..."
  announced=true
}

# suspend-then-hibernate is included even though nothing invokes it here: it is
# a sleep entry point, and leaving one unmasked defeats the point of the others.
unmasked=()
for unit in sleep.target suspend.target hibernate.target hybrid-sleep.target suspend-then-hibernate.target; do
  [[ $(systemctl is-enabled "$unit" 2>/dev/null) == masked ]] || unmasked+=("$unit")
done

if ((${#unmasked[@]})); then
  announce
  pkexec systemctl mask "${unmasked[@]}" >/dev/null
fi

# The menu half. `omarchy-toggle <flag> on` is idempotent, but it is also a
# process launch on every apply, so test the flag file it owns first.
if [[ ! -f $HOME/.local/state/omarchy/toggles/suspend-off ]] &&
  command -v omarchy-toggle >/dev/null 2>&1; then
  omarchy-toggle suspend-off on
fi
