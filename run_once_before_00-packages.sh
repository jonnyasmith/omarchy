#!/usr/bin/env bash
#
# The programs this repo's files assume, on a machine that has none of them.
#
# `chezmoi apply` on a fresh Omarchy install lands dot_bashrc's ble.sh guard,
# the pinned mise tool list and run_after_sshd-tailnet.sh, then all three do
# nothing: the guard falls through to plain bash, the tool set stays empty, and
# the sshd script exits 0 at `command -v tailscale`, leaving port 22 shut. Every
# one of those is documented in README.md and none of it was executable, so a
# new machine was a manual checklist. This is that checklist, minus the steps
# that genuinely need a human.
#
# run_once_before_:
#   before_ so ble.sh and tailscale exist before the files that reference them
#     and before the run_after_ scripts that gate on them, in the same apply.
#   once_ so it costs nothing on every later apply. chezmoi keys `once_` on this
#     file's contents, per machine, so editing it re-runs it -- which is why
#     every step below is gated and idempotent, and why a failed step is fine:
#     the next apply retries it.
#
# Privileged steps go through pkexec, like the rest of this repo, rather than
# through `omarchy pkg add` / `omarchy pkg aur add`. Those wrappers hard-code
# `sudo`, which needs a terminal to type a password into; pkexec reaches the
# polkit agent, so an apply driven by an agent or a script authenticates the
# same way as one driven by a human.

set -euo pipefail

user=${USER:-$(id -un)}
todo=()

# --- Repo packages -----------------------------------------------------------

# tailscale is the only one Omarchy does not already ship. Without it
# run_after_sshd-tailnet.sh does nothing, and reachability over the tailnet is
# the entire reason sshd is enabled on these machines.
repo_pkgs=(tailscale)

missing=()
for pkg in "${repo_pkgs[@]}"; do
  pacman -Q "$pkg" &>/dev/null || missing+=("$pkg")
done

if ((${#missing[@]})); then
  echo "Installing ${missing[*]} (needs root)..."
  pkexec pacman -S --needed --noconfirm "${missing[@]}"
fi

# tailscaled has to be running before `tailscale up` can do anything, and that
# part is unattended. The login itself is not -- see the summary at the end.
if command -v tailscale >/dev/null 2>&1 &&
  ! systemctl is-enabled --quiet tailscaled.service 2>/dev/null; then
  echo "Enabling tailscaled.service (needs root)..."
  pkexec systemctl enable --now tailscaled.service
fi

if command -v tailscale >/dev/null 2>&1 && ! tailscale status &>/dev/null; then
  todo+=("tailscale up"$'\t'"browser SSO; until then nothing can reach port 22")
fi

# --- AUR packages ------------------------------------------------------------

# blesh-git is not in the official repos. Every reference in dot_bashrc and
# dot_config/blesh/ is guarded, so its absence is silent rather than broken --
# and silently missing the point of both files. --sudo routes yay's privileged
# half through pkexec for the reason given in the header.
if ! pacman -Q blesh-git &>/dev/null; then
  echo "Building blesh-git from the AUR (needs root to install)..."
  yay -S --needed --noconfirm --sudo /usr/bin/pkexec blesh-git
fi

# --- Docker group ------------------------------------------------------------

# run_after_portainer.sh gates on `docker info`, which fails for a user outside
# the docker group even with docker.socket enabled. Group membership only
# reaches a process at login, so this cannot finish inside this apply: the next
# one after a re-login starts the container.
if command -v docker >/dev/null 2>&1 && getent group docker >/dev/null; then
  # The group database: whether usermod still has work to do.
  if ! id -nG "$user" | grep -qw docker; then
    echo "Adding $user to the docker group (needs root)..."
    pkexec usermod -aG docker "$user"
  fi
  # This process, which took its groups from the session at login and will not
  # see docker until the next one -- including on a re-apply, which is exactly
  # when the reminder is still needed.
  id -nG | grep -qw docker ||
    todo+=("log out and back in"$'\t'"docker group; then re-apply for Portainer")
fi

# --- What is left for a human ------------------------------------------------

# No private key is on disk, so ssh has nothing to offer until the 1Password
# agent is switched on, and that toggle exists only in the GUI.
[[ -S "$HOME/.1password/agent.sock" ]] ||
  todo+=("1Password > Developer > SSH agent"$'\t'"GUI-only toggle; no key without it")

if ((${#todo[@]})); then
  printf '\nStill needs a human:\n'
  printf '  %s\n' "${todo[@]}" | expand -t 44
  printf '\n'
fi
