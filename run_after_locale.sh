#!/usr/bin/env bash
#
# UK locale, in both places a locale has to be set.
#
# Omarchy's installer takes the keyboard layout from the install prompt but
# hardcodes the locale, so a UK machine comes out with `VC Keymap: uk` and
# `LANG=en_US.UTF-8`, and en_GB.UTF-8 is not even generated. Fixing that is the
# first half of this script.
#
# The second half is the half that is easy to miss. /etc/locale.conf is read by
# *systemd*, which puts LANG into the user manager's environment, and a
# graphical session inherits it from there. An sshd session does not: the shell
# is a child of sshd, and the only locale channel PAM offers is pam_env, which
# reads /etc/environment and nothing else. Arch ships that file with comments
# only, so every ssh login lands in the C locale.
#
# That is invisible until something reads LANG. `herdr --remote minisforum`
# runs `ssh minisforum herdr server`, so the remote Herdr server -- and every
# pane it spawns -- inherits the empty value, and ble.sh opens each pane with
# "suspicious environment: $LANG is empty". The panes were right and ble.sh was
# only the first thing to notice.
#
# Both files therefore have to say the same thing: locale.conf for local
# sessions, /etc/environment for ssh, herdr panes, cron, and system units.
#
# LC_COLLATE is deliberately left alone. en_GB dictionary ordering would change
# `ls` and `sort` output against the byte ordering every existing script here
# was written on; only LANG is set, so collation follows it and can be pinned
# back to C in this file if that ever bites.
#
# Already-correct hosts exit without a single pkexec call, so this stays silent
# on every apply after the first.

set -euo pipefail

lang=en_GB.UTF-8
# locale -a normalizes the codeset: en_GB.UTF-8 is reported as en_GB.utf8.
lang_generated=en_GB.utf8

command -v localectl >/dev/null 2>&1 || exit 0
[[ -f /etc/locale.gen ]] || exit 0

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

announced=false
announce() {
  $announced && return 0
  echo "Setting the system locale to $lang (needs root)..."
  announced=true
}

# Generate first. `localectl set-locale` on an ungenerated locale writes a
# locale.conf that nothing can load, which is worse than the wrong locale.
if ! locale -a 2>/dev/null | grep -qx "$lang_generated"; then
  announce
  pkexec sh -c '
    set -e
    grep -q "^en_GB.UTF-8 UTF-8" /etc/locale.gen ||
      sed -i "s/^#[[:space:]]*\(en_GB.UTF-8 UTF-8\)/\1/" /etc/locale.gen
    locale-gen
  '
fi

# systemd's copy: local sessions, via the user manager's environment.
if [[ $(. /etc/locale.conf 2>/dev/null; echo "${LANG-}") != "$lang" ]]; then
  announce
  pkexec localectl set-locale "LANG=$lang"
fi

# pam_env's copy: ssh, herdr --remote panes, cron, system units.
{
  grep -v '^LANG=' /etc/environment || true
  echo "LANG=$lang"
} >"$tmp/environment"

if ! cmp -s "$tmp/environment" /etc/environment; then
  announce
  pkexec install -Dm644 -o root -g root "$tmp/environment" /etc/environment
fi
