#!/usr/bin/env bash
#
# Portainer — the one container this repo runs rather than installs. Docker's
# web UI on http://localhost:9000, managing the local daemon through its socket.
#
# The compose file lives in /opt, outside the tree chezmoi manages, so it is
# written here instead of being a target file.
#
# `run_after_`, not `run_onchange_after_`: the daemon is not reachable on the
# apply that installs Docker or adds this account to the `docker` group, so this
# has to be able to try again on the next one.
#
# Every failure exits 0. A missing Docker, an unreachable daemon, a declined
# polkit prompt or a registry that is down costs the container, never the apply.

set -uo pipefail

command -v docker >/dev/null 2>&1 || exit 0

# `docker info`, not a socket path: it is also the group-membership probe. On
# the apply that added this account to `docker` the socket exists and this shell
# still cannot read it, and compose would fail rather than defer.
if ! docker info >/dev/null 2>&1; then
  echo "Docker is not reachable yet — portainer deferred to the next apply"
  exit 0
fi

compose=/opt/portainer/docker-compose.yml

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

# Staged and compared before it is installed, so an apply with nothing to do
# neither raises a polkit prompt nor recreates the container.
want=$tmp/docker-compose.yml
cat >"$want" <<'EOF'
services:
  portainer:
    image: portainer/portainer-ce
    container_name: portainer
    restart: always
    ports:
      - "9000:9000"
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
      - portainer_data:/data
    networks:
      portainer:
        aliases:
          - "portainer"

volumes:
  portainer_data:

networks:
  portainer:
EOF

changed=false
if ! cmp -s "$want" "$compose"; then
  echo "Installing $compose (needs root)..."
  if pkexec install -Dm644 -o root -g root "$want" "$compose"; then
    changed=true
  else
    echo "Could not write $compose — portainer left alone" >&2
    exit 0
  fi
fi

# `up -d` converges by itself, but it also talks to the registry, so it is kept
# off an apply where the file is unchanged and the container is already up.
if ! $changed && [[ -n "$(docker ps -q -f name='^portainer$')" ]]; then
  exit 0
fi

if docker compose -f "$compose" up -d; then
  echo "Portainer is up — http://localhost:9000"
else
  echo "Could not start portainer" >&2
fi

exit 0
