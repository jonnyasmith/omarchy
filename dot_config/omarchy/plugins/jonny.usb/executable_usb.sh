#!/bin/bash
#
# Lists the removable drives currently attached, one TSV row each:
#
#   device <TAB> label <TAB> detail
#
# e.g. /dev/sdb	SanDisk Ultra Fit 28.9G	sdb · vfat ARCH_202601 · mounted
#
# Whole disks only. The partitions are what you mount, but format, image-write
# and power-off all act on the drive, so the drive is the unit the picker picks
# and the partitions are detail text.
#
# Two selection tests, because neither is sufficient on its own: `rm` is the
# kernel's removable-media bit, which a USB SSD in a bridge enclosure reports
# as 0, and `tran == "usb"` misses a card reader on some controllers. Then a
# third test throws away anything carrying a system mount, so a misreported
# internal disk cannot reach a menu whose entries all destroy data. `zram0`
# fails the first two (not removable, no transport) and every loop device is
# `type: loop`, so neither needs naming here.
#
# `lsblk -J` rather than sysfs by hand: one process, one JSON tree, and the
# partition children come with it.

set -uo pipefail

command -v jq >/dev/null 2>&1 || exit 0

lsblk -J -o PATH,NAME,TYPE,RM,HOTPLUG,TRAN,VENDOR,MODEL,SIZE,FSTYPE,LABEL,MOUNTPOINTS 2>/dev/null |
  jq -r '
    # Includes the node itself, so a mount on an unpartitioned disk counts.
    def descendants: recurse(.children[]?);
    def mounts: [descendants | .mountpoints[]? | select(. != null)];
    def clean: (. // "") | gsub("^\\s+|\\s+$"; "");

    # A drive holding any of these is not a removable drive whatever the bits
    # say, and is certainly not one to offer to erase.
    def system_mount: . == "/" or . == "/boot" or . == "/home"
      or startswith("/boot/") or startswith("/var/") or . == "[SWAP]";

    .blockdevices[]
    | select(.type == "disk")
    | select(.rm == true or .tran == "usb")
    | select([mounts[] | select(system_mount)] | length == 0)
    | . as $d
    | [descendants | select(.type == "part")] as $parts
    | ([$d.vendor | clean, ($d.model | clean)] | map(select(length > 0)) | join(" ")) as $name
    | (if ($name | length) > 0 then $name else $d.name end) as $name

    # Filesystems, in partition order, named by label where they have one. No
    # partitions at all is the state a fresh image-write leaves behind on some
    # ISOs and the state a wiped drive is in, so it gets said out loud rather
    # than rendered as an empty column.
    | (if ($parts | length) > 0 then
         $parts | map(((.fstype | clean) | if length > 0 then . else "unformatted" end)
                      + ((.label | clean) | if length > 0 then " " + . else "" end))
                | join(", ")
       elif (($d.fstype | clean) | length) > 0 then
         ($d.fstype | clean) + " (no partition table)"
       else
         "no partition table"
       end) as $fs

    | (if ([$d | mounts[]] | length) > 0 then " · mounted" else "" end) as $mounted
    | [$d.path, "\($name) \($d.size)", "\($d.name) · \($fs)\($mounted)"]
    | @tsv
  '
