#!/usr/bin/env bash
#
# Builds the TOD (Touch OEM Driver) fingerprint stack for readers stock
# libfprint cannot drive. This is the executable form of the AUR block in
# .chezmoitemplates/omarchy/fingerprint.md; read that file before editing this
# one, and keep the two in step.
#
# `omarchy setup security fingerprint` cannot do this: it installs repo
# libfprint, which has no driver for a Goodix 53xc, so enrollment dies with
# NoSuchDevice. Worse, after a TOD stack is installed that wizard must never run
# again -- it calls `omarchy-pkg-add libfprint fprintd usbutils`, the
# libfprint-tod conflict aborts it, and forcing it through removes the driver.
#
# after_ so it never delays the files; run_once_ because it is a multi-minute
# makepkg. chezmoi keys `once_` on this file's contents, per machine, so a failed
# build is retried on the next apply and an edit here rebuilds.
#
# Ordering against run_after_omarchy-fingerprint-pam.sh is by target name, so
# `fingerprint-tod` runs first -- and that script wires nothing until a finger is
# actually enrolled, which is the one step below that needs a human at the
# sensor. So PAM lands on the apply after enrollment, never before.
#
# The gate is the USB ID, not the DMI product name: the blob covers a reader,
# not a chassis. A machine with no matching reader -- minisforum, or an XPS whose
# stock driver works -- does nothing at all here.

set -euo pipefail

# Goodix 53xc family, exactly the IDs libfprint-2-tod1-xps9300-bin's udev rules
# claim. Other readers need a different blob; the table in fingerprint.md lists
# them, and adding one here means adding its IDs too.
tod_pkg=libfprint-2-tod1-xps9300-bin
tod_ids='27c6:(530c|533c|538c|5840)'

# libfprint-tod is the TOD-enabled libfprint itself. It conflicts with repo
# libfprint but provides it, so repo fprintd keeps working.
pacman -Q libfprint-tod &>/dev/null && exit 0
command -v lsusb >/dev/null 2>&1 || exit 0
command -v makepkg >/dev/null 2>&1 || exit 0
command -v git >/dev/null 2>&1 || exit 0
lsusb | grep -qiE "ID $tod_ids" || exit 0

echo "Unsupported fingerprint reader found; building the TOD stack (needs root)..."

build=$(mktemp -d)
trap 'rm -rf "$build"' EXIT

# The libfprint-tod source is a signed tag; makepkg aborts without the key.
gpg --keyserver hkps://keyserver.ubuntu.com \
  --recv-keys D4C501DA48EB797A081750939449C2F50996635F

# makepkg cannot install its own dependencies without passwordless sudo, so the
# build deps go in explicitly. Build unprivileged, install with absolute paths:
# pkexec resets the working directory.
pkexec pacman -S --needed --noconfirm \
  glib2-devel gobject-introspection gtk-doc meson umockdev \
  cairo python-cairo python-gobject

git clone --depth 1 https://aur.archlinux.org/libfprint-tod.git "$build/libfprint-tod"
git clone --depth 1 "https://aur.archlinux.org/$tod_pkg.git" "$build/$tod_pkg"

# `-[0-9]*` and not `*`: makepkg.conf carries OPTIONS=debug here, so each build
# also produces a <pkg>-debug package the plain glob would install alongside.
(cd "$build/libfprint-tod" && makepkg --noconfirm --nocheck)
# --ask=4 answers the libfprint replacement prompt. --noconfirm alone answers N
# there and the transaction aborts.
pkexec pacman -U --noconfirm --ask=4 "$build"/libfprint-tod/libfprint-tod-[0-9]*.pkg.tar.zst

(cd "$build/$tod_pkg" && makepkg --noconfirm --nocheck)
pkexec pacman -U --noconfirm "$build/$tod_pkg/$tod_pkg"-[0-9]*.pkg.tar.zst

# The blob ships udev rules; fprintd has to re-enumerate to see the wrapper.
pkexec sh -c 'udevadm control --reload &&
              udevadm trigger --subsystem-match=usb --action=add &&
              systemctl restart fprintd'

# Proof the wrapper bound, rather than proof the packages installed. A warning
# and not a failure: if the blob does not match this reader, rebuilding it on
# every apply will not change that -- pick a different one from fingerprint.md.
drivers=$(python3 -c "
import gi; gi.require_version('FPrint','2.0')
from gi.repository import FPrint
c = FPrint.Context(); c.enumerate()
print('\n'.join(f'{d.get_driver()} | {d.get_name()}' for d in c.get_devices()))" 2>/dev/null || true)

if [[ -z $drivers ]]; then
  echo "Warning: $tod_pkg is installed but libfprint still binds no device." >&2
  echo "See the driver table in the omarchy fingerprint skill guide." >&2
  exit 0
fi

printf '\nlibfprint now binds:\n%s\n' "$drivers"
cat <<'EOF'

Still needs a human (touches on the sensor):
  fprintd-enroll -f right-index-finger    repeat until enroll-completed
  fprintd-verify                          expect verify-match

Then re-apply: run_after_omarchy-fingerprint-pam.sh wires sudo, polkit and the
lock screen only once a finger is enrolled.

Never run `omarchy setup security fingerprint` on this machine again -- it
removes this driver. libfprint is AUR-managed from now on, so `omarchy update`
will not update it; rebuild it by hand.
EOF
