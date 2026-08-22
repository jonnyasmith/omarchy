#!/bin/bash
#
# Lists the local dev servers that are actually listening, one TSV row each:
#
#   port <TAB> label <TAB> detail
#
# `ss` is the only source that sees everything, container or not, and it needs
# no privilege and no Docker daemon. It just names things badly: a Vite server
# reports as `node-MainThread`. So the label comes from the process's own cwd
# instead — the project directory is what you actually recognise. That only
# works for processes we own; a container's port belongs to root, so those
# names come from `docker ps`, and only when the daemon is already awake.
# Waking it to draw a bar widget would defeat the socket activation that keeps
# it asleep.

set -uo pipefail

min=${1:-3000}
max=${2:-9999}

declare -A label detail

sanitise() { tr '\t\n' '  ' <<<"$1" | sed 's/  */ /g; s/^ //; s/ $//'; }

# Pass 1: every listener in range, labelled from /proc where we can read it.
# One port can appear twice (IPv4 and IPv6 binds are separate sockets), so the
# first labelled row for a port wins and later duplicates are dropped.
while read -r _ _ _ local _ rest; do
  port=${local##*:}
  [[ $port =~ ^[0-9]+$ ]] || continue
  ((port >= min && port <= max)) || continue
  [[ -v label[$port] ]] && continue

  pid=""
  [[ ${rest:-} =~ pid=([0-9]+) ]] && pid=${BASH_REMATCH[1]}

  if [[ -n $pid ]] && cwd=$(readlink "/proc/$pid/cwd" 2>/dev/null); then
    label[$port]=${cwd##*/}
    detail[$port]=$(sanitise "$(tr '\0' ' ' <"/proc/$pid/cmdline" 2>/dev/null)")
  else
    # Root-owned, or it exited between the scan and the read. Leave it
    # unlabelled for pass 2 rather than showing a thread name nobody wants.
    label[$port]=""
    detail[$port]=""
  fi
done < <(ss -ltnpH 2>/dev/null)

# Pass 2: name the root-owned rows from Docker, but only if the daemon is
# already running. dockerd writes /run/docker.pid itself (the unit is
# Type=notify with no PIDFile=), so its presence is a free liveness check.
if [[ -f /run/docker.pid ]] && command -v docker >/dev/null 2>&1; then
  while IFS=$'\t' read -r name ports; do
    [[ -n $name ]] || continue
    while read -r hostport; do
      [[ -v label[$hostport] ]] || continue
      [[ -n ${label[$hostport]} ]] && continue
      label[$hostport]=$name
      detail[$hostport]="container $name"
    done < <(grep -oP ':\K[0-9]+(?=->)' <<<"$ports" | sort -u)
  done < <(docker ps --format '{{.Names}}\t{{.Ports}}' 2>/dev/null)
fi

for port in $(printf '%s\n' "${!label[@]}" | sort -n); do
  name=${label[$port]}
  [[ -n $name ]] || name="port $port"
  printf '%s\t%s\t%s\n' "$port" "$name" "${detail[$port]}"
done
