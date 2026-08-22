# Fingerprint Authentication

Read this before enrolling fingerprints, debugging `fprintd`, or touching PAM
for fingerprint login. Some readers need a proprietary TOD (Touch OEM Driver)
blob instead of stock libfprint, and `omarchy setup security fingerprint` cannot
install those.

## Normal Setup

```bash
omarchy setup security fingerprint    # Detects, installs, enrolls, verifies, wires PAM
```

The wizard enrolls the right index finger, verifies it, and only then edits
`/etc/pam.d/sudo`, `/etc/pam.d/polkit-1`, and
`/etc/pam.d/omarchy-lock-fingerprint`. Detection proves a reader exists, not
that libfprint can drive it, so PAM comes last on purpose.

## When Enrollment Fails With `NoSuchDevice`

```
Impossible to enroll: GDBus.Error:net.reactivated.Fprint.Error.NoSuchDevice: No devices available
```

`fprintd` is fine; libfprint has no driver for the reader. Confirm what
libfprint can actually bind — never infer support from `lsusb` alone:

```bash
lsusb | grep -i finger        # Get the USB ID, e.g. 27c6:533c
python3 -c "
import gi; gi.require_version('FPrint','2.0')
from gi.repository import FPrint
c = FPrint.Context(); c.enumerate()
ds = c.get_devices(); print('count:', len(ds))
[print(d.get_driver(), '|', d.get_name()) for d in ds]"
```

`count: 0` with the device present in `lsusb` means no driver claims it. Check
the ID against <https://fprint.freedesktop.org/supported-devices.html>.

Do not use `/usr/lib/udev/hwdb.d/60-autosuspend-libfprint-2.hwdb` as a support
list — it only sets USB autosuspend policy and contains unsupported readers.

## Unsupported Readers: TOD Drivers

Unsupported readers need a vendor TOD blob plus a TOD-enabled libfprint from the
AUR. `libfprint-tod` conflicts with repo `libfprint` but provides it, so repo
`fprintd` keeps working. Match the blob to the USB ID by reading the candidate
package's udev rules:

| Package | Covers |
|---|---|
| `libfprint-2-tod1-xps9300-bin` | Goodix 53xc — `27c6:530c`, `533c`, `538c`, `5840` |
| `libfprint-2-tod1-goodix-v2` | Goodix 550a and later Ubuntu PPA blobs |
| `libfprint-2-tod1-synatudor-git` | Synaptics Tudor |
| `libfprint-2-tod1-broadcom` | Dell ControlVault |

`makepkg` cannot install its own dependencies without passwordless `sudo`:
install build deps with `pkexec`, build unprivileged, install with `pkexec` and
**absolute** paths (`pkexec` resets the working directory).

```bash
mkdir -p /tmp/fpbuild && cd /tmp/fpbuild
git clone https://aur.archlinux.org/libfprint-tod.git
git clone https://aur.archlinux.org/libfprint-2-tod1-xps9300-bin.git

# The libfprint-tod source is a signed tag; import the key or makepkg aborts.
gpg --keyserver hkps://keyserver.ubuntu.com \
    --recv-keys D4C501DA48EB797A081750939449C2F50996635F

pkexec pacman -S --needed --noconfirm \
  glib2-devel gobject-introspection gtk-doc meson umockdev \
  cairo python-cairo python-gobject

(cd libfprint-tod && makepkg --noconfirm --nocheck)
# --ask=4 answers the libfprint conflict prompt; --noconfirm alone defaults to
# N there and the transaction aborts.
pkexec pacman -U --noconfirm --ask=4 /tmp/fpbuild/libfprint-tod/libfprint-tod-*.pkg.tar.zst

(cd libfprint-2-tod1-xps9300-bin && makepkg --noconfirm --nocheck)
pkexec pacman -U --noconfirm /tmp/fpbuild/libfprint-2-tod1-xps9300-bin/*.pkg.tar.zst

pkexec sh -c 'udevadm control --reload &&
              udevadm trigger --subsystem-match=usb --action=add &&
              systemctl restart fprintd'
```

Re-run the enumeration check; a working TOD stack prints the wrapper line:

```
libfprint-tod-Message: Creating TOD wrapper for goodix-tod (Goodix Fingerprint Sensor 53xc) driver
count: 1
goodix-tod | Goodix Fingerprint Sensor 53xc
```

A trailing exit 139 with `libusb_exit ... still referenced` is a TOD shutdown
wart in that throwaway process only. Enumeration output above it is valid.

**After installing a TOD stack, never re-run
`omarchy setup security fingerprint`.** It runs
`omarchy-pkg-add libfprint fprintd usbutils`, which knows only about
`libfprint-git`; the `libfprint-tod` conflict aborts the wizard, and forcing it
through removes the driver. `libfprint` is AUR-managed from then on, so
`omarchy update` will not update it — rebuild it from the AUR by hand.

## Enrolling and Verifying by Hand

`fprintd-enroll` needs no root for your own prints and blocks on physical
touches, so run it where the user can be told to touch the sensor.

```bash
fprintd-list "$USER"                            # Confirm fprintd sees the device
fprintd-enroll -f right-index-finger "$USER"    # Repeat touches until enroll-completed
fprintd-verify                                  # Expect verify-match
```

Finger names: `left-thumb`, `right-thumb`, and
`{left,right}-{index,middle,ring,little}-finger`.

## PAM by Hand

Only needed if enrollment succeeded outside the wizard. Mirror
`omarchy-setup-security-fingerprint` exactly — prepend to `/etc/pam.d/sudo` and
`/etc/pam.d/polkit-1`:

```
auth      [success=1 default=ignore] pam_exec.so quiet /usr/bin/omarchy-hw-laptop-closed
auth      sufficient pam_fprintd.so
```

The first line is the clamshell gate: with the lid shut the reader is
unreachable, so `success=1` skips exactly the `pam_fprintd` line and PAM falls
through to the password prompt instead of blocking. It must stay immediately
above `pam_fprintd.so`. Then `/etc/pam.d/omarchy-lock-fingerprint` for the lock
screen (Super + Ctrl + L):

```
#%PAM-1.0
auth       required                    pam_fprintd.so
account    include                     system-local-login
```

Smoke test — prints `0` after a touch, with no password:

```bash
sudo -k; sudo id -u
```

## Lid Closed

`/usr/bin/omarchy-hw-laptop-closed` reads `/proc/acpi/button/lid/*/state` and
exits `0` when the lid is shut, `1` when it is open. In the `sudo` and
`polkit-1` stacks that means:

- **closed** — gate succeeds, `success=1` skips exactly `pam_fprintd`, PAM goes
  straight to the password prompt. No wait on the unreachable sensor.
- **open** — gate fails, `default=ignore` falls through to `pam_fprintd`, with
  the password still behind it as the fallback.

Per surface:

- **`sudo`** — password prompt immediately.
- **Polkit dialogs** — `PolkitAgent.qml` refreshes lid state per request and
  gates its own `fingerprintMode` on `!laptopClosed`, so it draws the password
  field instead of the sensor icon.
- **Lock screen** — `lock/Service.qml` runs `omarchy-lock-password` and
  `omarchy-lock-fingerprint` as independent PAM flows, so the password field
  never depends on the reader. It does *not* check lid state: `fingerprintPam`
  keeps retrying via `fingerprintRetryTimer` against an unreachable sensor and
  failing silently. Harmless, but expect it in logs.

To test a branch without moving the lid, build a throwaway stack with the gate
forced to a fixed outcome (`/bin/true` = closed, `/bin/false` = open) and drive
it with any PAM client. A closed-lid stack must prompt only for a password; an
open-lid stack must emit `Place your right index finger on the fingerprint
reader`. Delete the test stacks from `/etc/pam.d/` afterwards.
