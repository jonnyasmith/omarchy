#!/usr/bin/env bash
#
# Restores the fingerprint PAM configuration written by
# omarchy-setup-security-fingerprint: pam_fprintd in the sudo and polkit stacks,
# each behind a clamshell gate, plus the lock screen's fingerprint-only stack.
#
# /etc/pam.d/sudo is a pacman backup file, so a sudo upgrade leaves it alone and
# drops a .pacnew instead. These edits are still lost to a package reinstall,
# `omarchy remove security fingerprint`, a --overwrite, or a fresh machine.
# /etc/pam.d/polkit-1 and /etc/pam.d/omarchy-lock-fingerprint are owned by no
# package at all.
#
# Every edit here fails open: the gate is [success=1 default=ignore] and
# pam_fprintd is `sufficient`, so a missing reader or a broken driver costs a
# password prompt, never access.

set -euo pipefail

gate='auth      [success=1 default=ignore] pam_exec.so quiet /usr/bin/omarchy-hw-laptop-closed'
fprintd='auth      sufficient pam_fprintd.so'
lock_stack=/etc/pam.d/omarchy-lock-fingerprint

# Never wire PAM to a reader that cannot work. Each guard is a reason to do
# nothing at all on this machine.
[[ -e /usr/lib/security/pam_fprintd.so ]] || exit 0
[[ -e /usr/lib/security/pam_exec.so ]] || exit 0
[[ -x /usr/bin/omarchy-hw-laptop-closed ]] || exit 0
command -v fprintd-list >/dev/null 2>&1 || exit 0
# An enrolled finger is the only proof the driver actually drives the sensor.
fprintd-list "$USER" 2>/dev/null | grep -qE '^ - #' || exit 0

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

announced=false
announce() {
  $announced && return 0
  echo "Restoring fingerprint PAM configuration (needs root)..."
  announced=true
}

# Stage the wanted content for an existing stack; print nothing when it already
# has both lines. Insertion order matters: the gate must sit immediately above
# pam_fprintd so success=1 skips exactly that module.
stage_stack() {
  local target=$1 staged=$2
  local have_fprintd=false have_gate=false

  grep -qF 'pam_fprintd.so' "$target" && have_fprintd=true
  grep -qF 'omarchy-hw-laptop-closed' "$target" && have_gate=true

  if $have_fprintd && $have_gate; then
    return 1
  fi

  if $have_fprintd; then
    # Gate only. Insert above the first pam_fprintd line.
    awk -v gate="$gate" '
      !done && /pam_fprintd\.so/ { print gate; done = 1 }
      { print }
    ' "$target" >"$staged"
  else
    # Neither line: prepend both, matching the wizard.
    { printf '%s\n%s\n' "$gate" "$fprintd"; cat "$target"; } >"$staged"
  fi

  # Refuse to install anything that lost a line or failed to gain exactly what
  # was missing — a mangled auth stack is not worth the convenience.
  local before after expected added
  # One line added when only the gate was missing, two when both were.
  $have_fprintd && added=1 || added=2
  before=$(wc -l <"$target")
  after=$(wc -l <"$staged")
  expected=$(( before + added ))
  if [[ $after -ne $expected ]]; then
    echo "refusing to edit $target: expected $expected lines, staged $after" >&2
    return 2
  fi
  grep -qxF "$gate" "$staged" || { echo "refusing to edit $target: gate missing" >&2; return 2; }
  grep -qF 'pam_fprintd.so' "$staged" || { echo "refusing to edit $target: pam_fprintd missing" >&2; return 2; }
  # The gate is only meaningful directly above pam_fprintd.
  grep -A1 -xF "$gate" "$staged" | grep -q 'pam_fprintd\.so' ||
    { echo "refusing to edit $target: gate not adjacent to pam_fprintd" >&2; return 2; }

  return 0
}

for target in /etc/pam.d/sudo /etc/pam.d/polkit-1; do
  staged="$tmp/$(basename "$target")"

  if [[ ! -e $target ]]; then
    # polkit ships no pam.d file on this system; write the wizard's stack.
    printf '%s\n%s\nauth      required pam_unix.so\n\naccount   required pam_unix.so\npassword  required pam_unix.so\nsession   required pam_unix.so\n' \
      "$gate" "$fprintd" >"$staged"
    announce
    pkexec install -Dm644 -o root -g root "$staged" "$target"
    continue
  fi

  set +e
  stage_stack "$target" "$staged"
  rc=$?
  set -e
  case $rc in
    0) announce
       # Expand the timestamp here: it is inside single quotes by the time the
       # root shell sees it, so `date` would never run there.
       pkexec sh -c "cp -a '$target' '$target.bak.$(date +%s)' && install -m644 -o root -g root '$staged' '$target'" ;;
    1) ;;  # already configured
    *) exit 1 ;;
  esac
done

# Lock screen stack (Super + Ctrl + L). Fingerprint-only by design: the lock
# screen runs it alongside a separate omarchy-lock-password stack, so the
# password field keeps working when this one fails.
printf '#%%PAM-1.0\nauth       required                    pam_fprintd.so\naccount    include                     system-local-login\n' \
  >"$tmp/lock"
if ! cmp -s "$tmp/lock" "$lock_stack"; then
  announce
  pkexec install -Dm644 -o root -g root "$tmp/lock" "$lock_stack"
fi
