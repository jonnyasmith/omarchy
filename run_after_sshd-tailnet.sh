#!/usr/bin/env bash
#
# Inbound SSH, reachable over the tailnet only.
#
# Three pieces, none of which chezmoi can own directly because they live outside
# $HOME: the hardening drop-in in /etc/ssh/sshd_config.d, the ufw rule that is
# the *only* thing making port 22 reachable, and the enabled sshd.service.
# The authorized_keys half is managed normally, as private_dot_ssh/.
#
# Reachability is enforced by ufw, not by ListenAddress: sshd would have to
# start after tailscaled had claimed 100.x, and a boot-order race that leaves
# sshd dead is worse than a packet filter. ufw's default policy is
# deny (incoming), so the single `allow in on tailscale0` rule is what admits
# the tailnet and nothing else -- LAN and WAN see a drop.
#
# Auth is publickey only. The key is the 1Password-agent Ed25519 identity, which
# every machine in this tailnet already has, so no private key is on disk here.

set -euo pipefail

drop_in=/etc/ssh/sshd_config.d/10-tailnet-only.conf

# Nothing to do on a box without ufw or tailscale: opening sshd without the
# firewall rule in place would expose port 22 to the LAN instead of the tailnet.
command -v ufw >/dev/null 2>&1 || exit 0
command -v tailscale >/dev/null 2>&1 || exit 0
[[ -x /usr/bin/sshd ]] || exit 0

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

announced=false
announce() {
  $announced && return 0
  echo "Configuring tailnet-only sshd (needs root)..."
  announced=true
}

# Lexical order decides: 10- is read before Arch's 99-archlinux.conf, and the
# first value sshd obtains for a keyword wins.
cat >"$tmp/drop-in" <<'EOF'
# Managed by chezmoi: run_after_sshd-tailnet.sh
# Key-only SSH. Network reachability is restricted to the tailnet by ufw
# (allow in on tailscale0; default deny incoming covers LAN and WAN).
PasswordAuthentication no
KbdInteractiveAuthentication no
PermitRootLogin no
AuthenticationMethods publickey

# Replace the Unix socket a previous connection left behind instead of failing
# the forward. ~/.ssh/config sends this machine's 1Password agent to the far end
# at a constant path (see the tailnet block there), and without this the second
# attach dies with "remote port forwarding failed for listen path" because the
# first one's socket is still on disk. Only affects sockets this user's own
# sessions bound.
StreamLocalBindUnlink yes
EOF

if ! cmp -s "$tmp/drop-in" "$drop_in"; then
  announce
  pkexec install -Dm644 -o root -g root "$tmp/drop-in" "$drop_in"
  reload=true
fi

# `ufw allow` is idempotent, but it is also slow and noisy, so ask first.
if ! pkexec ufw status | grep -q '^22/tcp *on tailscale0 *ALLOW'; then
  announce
  pkexec ufw allow in on tailscale0 to any port 22 proto tcp \
    comment 'ssh over tailnet' >/dev/null
fi

if ! systemctl is-enabled --quiet sshd.service; then
  announce
  # Host keys do not exist until sshd-keygen runs, which `start` pulls in.
  pkexec systemctl enable --now sshd.service
elif ! systemctl is-active --quiet sshd.service; then
  announce
  pkexec systemctl start sshd.service
elif [[ ${reload-} == true ]]; then
  announce
  pkexec systemctl reload sshd.service
fi
