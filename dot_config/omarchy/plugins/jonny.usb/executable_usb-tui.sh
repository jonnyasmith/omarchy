#!/bin/bash
#
# The keyboard half of USB drive handling: pick an attached removable drive,
# then power it off for safe removal, reformat it, or write a bootable image to
# it. Meant to be run by `omarchy launch tui --app-id=TUI.float`.
#
# Unlike the dev-ports picker this one does *not* exit on the first keystroke:
# dd prints progress for minutes and every destructive action asks to be
# confirmed by name, so the window has to stay until the work is finished and
# read. It is a tree -- drive, then action, then filesystem or image -- walked
# in normal mode: j/k move, l or enter goes down, h comes back up, `/` searches
# and esc leaves the search. See ../jonny.lib/vim-fzf.sh, which owns all of
# that. Choosing an action is a second list rather than a chord on the drive
# list: a chord that erases a drive is a chord pressed by accident.
#
#   usb-tui.sh                 pick a drive, then an action
#   usb-tui.sh /dev/sdb        skip the picker; usable by hand
#
# `usb.sh` owns the scan and prints `device <TAB> label <TAB> detail`; nothing
# here parses a block device itself.
#
# Privilege, of which there are two kinds here on purpose:
#
#   * unmount, format and power-off go through udisks over D-Bus, whose polkit
#     actions are `active: yes` for a local logged-in session -- so the common
#     path asks for no password at all. `udisksctl` has verbs for the first and
#     the last; formatting is `Block.Format` + `PartitionTable.
#     CreatePartitionAndFormat`, which is what GNOME Disks calls, so udisks
#     does the partition alignment, the type byte and the ownership fixup.
#   * writing an image is `sudo dd`, because the only unprivileged route into a
#     raw block device is a file descriptor passed back over D-Bus
#     (`Block.OpenForRestore`), which a shell cannot receive. The floating
#     terminal is visible, so sudo can prompt in it -- see the omarchy skill's
#     rule: sudo where there is a terminal, pkexec where there is not.

set -uo pipefail

self=$(readlink -f "$0")
here=$(dirname "$self")

# Same rendered palette the dev-ports picker uses, written by every
# `omarchy theme set`. Absent until a theme has been applied, in which case fzf
# falls back to its own defaults and the colours below to plain ANSI.
palette="${XDG_STATE_HOME:-$HOME/.local/state}/omarchy/current/theme/fzf.env"
FZF_THEME_OPTS="" FZF_THEME_ACCENT="" FZF_THEME_DIM="" FZF_THEME_RED=""
# shellcheck source=/dev/null
[[ -r $palette ]] && source "$palette"

ansi_fg() {
  local hex=${1#\#}
  [[ $hex =~ ^[0-9a-fA-F]{6}$ ]] || return 1
  printf '\033[38;2;%d;%d;%dm' \
    "$((16#${hex:0:2}))" "$((16#${hex:2:2}))" "$((16#${hex:4:2}))"
}

reset=$'\033[0m'
accent=$(ansi_fg "$FZF_THEME_ACCENT") || accent=$'\033[1m'
dim=$(ansi_fg "$FZF_THEME_DIM") || dim=$'\033[2m'
# The one colour the dev-ports picker never needed. Bold red rather than the
# theme's red on its own, because this marks the line that says a drive is
# about to be erased.
danger=$'\033[1m'$(ansi_fg "$FZF_THEME_RED" || printf '\033[31m')

# Nerd Font glyphs, as `\u` escapes rather than literal characters: they are
# private-use codepoints, and every hop between here and the file -- editor,
# clipboard, terminal -- is a chance to lose one silently.
g_usb=$'\uf287' g_power=$'\uf011' g_format=$'\uf12d' g_write=$'\uf093'

# Drive rows for fzf: padded display column, then the device path as a hidden
# trailing field. Padded here rather than with --with-nth so the columns do not
# jump about as model names change, and hidden rather than parsed back out of
# the display column because that one carries ANSI escapes.
rows() {
  "$here/usb.sh" |
    awk -F'\t' -v a="$accent" -v d="$dim" -v r="$reset" \
      '{ printf "%s%-28.28s%s %s%s%s\t%s\n", a, $2, r, d, $3, r, $1 }'
}

if [[ ${1:-} == --rows ]]; then
  rows
  exit 0
fi

# One line of output in a window that closes is not a message: say it on the
# desktop when there is a desktop, and on stdout when a human ran this by hand.
say() {
  if [[ -n ${HYPRLAND_INSTANCE_SIGNATURE:-} ]] && command -v omarchy-notification-send >/dev/null 2>&1; then
    omarchy-notification-send -g "$g_usb" "USB drives" "$1"
  else
    echo "$1"
  fi
}

pause() {
  echo
  read -rsn1 -p "${dim}press any key${reset}" _
  echo
}

# ── the picker ───────────────────────────────────────────────────────────────

# Normal mode by default: j/k move, l or enter goes a level down, h comes back
# up, `/` opens a search box and esc closes it again. All of that, and the
# reason fzf can do it at all, lives in one place so that this picker and the
# dev-ports one cannot drift apart.
# shellcheck source=../jonny.lib/vim-fzf.sh
source "$here/../jonny.lib/vim-fzf.sh"

# ── the drive ────────────────────────────────────────────────────────────────

pick_drive() {
  local listing selection
  listing=$(rows)
  if [[ -z $listing ]]; then
    say "No removable drives attached."
    return 1
  fi
  # There is nothing above this list, so back and quit are the same thing.
  selection=$(
    printf '%s\n' "$listing" |
      vfzf --ctx "$accent$g_usb  usb drive$reset" --keys 'r rescan' -- \
        --delimiter=$'\t' --with-nth=1 --info=inline-right \
        --bind="r:reload($(printf '%q' "$self") --rows)"
  ) || return 1
  vfzf_row "$selection" | cut -f2
}

# udisks object paths are the device name, not the path: /dev/sdb is
# /org/freedesktop/UDisks2/block_devices/sdb.
udisks_object() {
  printf '/org/freedesktop/UDisks2/block_devices/%s' "$(basename "$1")"
}

udisks_call() {
  local object=$1 method=$2
  shift 2
  gdbus call --system --dest org.freedesktop.UDisks2 \
    --object-path "$object" --method "org.freedesktop.UDisks2.$method" "$@"
}

# The scan's own label and detail columns, so the confirmation prompt and the
# action header say the same thing the picker said. Falls back to lsblk for a
# device named on the command line that the scan does not list -- a loop
# device, or a drive that stopped being removable between the two calls.
describe() {
  local line
  line=$("$here/usb.sh" | awk -F'\t' -v d="$device" '$1 == d { print $2 " — " $3 }')
  [[ -n $line ]] || line=$(lsblk -dno VENDOR,MODEL,SIZE "$device" 2>/dev/null | tr -s ' ')
  printf '%s' "$line"
}

# The drive itself is the first row of `lsblk -l`, and it is not a partition.
parts() { lsblk -lnpo PATH "$device" 2>/dev/null | tail -n +2; }
# `-o MOUNTPOINTS` pads the column, so an unmounted drive prints spaces rather
# than nothing; `-l` and `-r` cannot be combined, which is how this managed to
# report a mounted drive as free and hand udisks a busy device to wipe.
mounted() { lsblk -lnpo MOUNTPOINTS "$device" 2>/dev/null | grep -q '[^[:space:]]'; }

# udiskie --automount is running on this desktop, so a drive is mounted again
# within a second of appearing -- and it re-mounts a partition the moment one is
# created. Every destructive call therefore unmounts and then *checks*, rather
# than assuming: udisks refuses to wipe a busy device, and finding that out
# halfway through leaves a drive with a partition table and no filesystem.
unmount_all() {
  local try part
  for try in 1 2 3; do
    mounted || return 0
    while read -r part; do
      [[ -n $part ]] && udisksctl unmount -b "$part" --no-user-interaction >/dev/null 2>&1
    done < <(parts)
    sleep 0.3
  done
  mounted && return 1
  return 0
}

# The guard on everything that destroys data: the drive's own name, typed. The
# picker showed the model and the size, so this is the point at which "the
# second one down" becomes "/dev/sdb" in the reader's head.
confirm_destructive() {
  local what=$1 base answer
  base=$(basename "$device")
  echo
  printf '%s%s%s\n' "$danger" "$what" "$reset"
  printf '  %s  %s\n' "$device" "$(describe)"
  echo
  read -rp "type ${accent}${base}${reset} to confirm: " answer
  [[ $answer == "$base" ]] || { echo "cancelled."; return 1; }
  unmount_all || { echo "could not unmount every partition on $device; nothing done." >&2; return 1; }
  return 0
}

# ── power off ────────────────────────────────────────────────────────────────

do_poweroff() {
  local err
  unmount_all || { echo "could not unmount every partition on $device." >&2; return 1; }
  if err=$(udisksctl power-off -b "$device" --no-user-interaction 2>&1); then
    echo "${accent}$device is safe to unplug.${reset}"
    say "$(basename "$device") is safe to unplug."
  else
    echo "$err" >&2
    return 1
  fi
}

# ── format ──────────────────────────────────────────────────────────────────

# Filesystem label limits, checked here rather than left to udisks: udisks does
# validate, but only on the second call, by which point the partition table has
# already been rewritten and the drive is empty.
label_limit() {
  case $1 in
    vfat) echo 11 ;;
    exfat) echo 15 ;;
    ext4) echo 16 ;;
  esac
}

do_format() {
  local fs choice label limit object partition size table
  # 2 means "nothing happened": ctrl-h or esc out of this list is a step back
  # up the tree, and the action menu must not stop to say "press any key" about
  # it -- doing so eats the next keystroke, which is usually another ctrl-h.
  choice=$(
    printf '%s\n' \
      $'FAT32\treads everywhere: Windows, macOS, cameras, car stereos\tvfat' \
      $'exFAT\tthe same reach, without the 4 GB file limit\texfat' \
      $'ext4\tLinux only, owned by you, keeps permissions\text4' |
      awk -F'\t' -v a="$accent" -v d="$dim" -v r="$reset" \
        '{ printf "%s%-6s%s %s%s%s\t%s\n", a, $1, r, d, $2, r, $3 }' |
      vfzf --ctx "$accent$g_format  filesystem$reset" --back -- \
        --delimiter=$'\t' --with-nth=1
  ) || return 2
  fs=$(vfzf_row "$choice" | cut -f2)
  [[ -n $fs ]] || return 2

  limit=$(label_limit "$fs")
  echo
  read -rp "label (max $limit chars, blank for none): " label
  # Kept to what every one of the three filesystems accepts, and to what is
  # safe to interpolate into the GVariant dictionary below.
  if [[ -n $label ]]; then
    [[ ${#label} -le $limit ]] || { echo "label is longer than $limit characters."; return 1; }
    [[ $label =~ ^[A-Za-z0-9._\ -]+$ ]] || { echo "label may only hold letters, digits, space, dot, dash and underscore."; return 1; }
  fi

  confirm_destructive "This erases everything on the drive and creates one $fs filesystem." || return 1

  object=$(udisks_object "$device")
  # MBR below 2 TiB because it is the table a camera, a car stereo and an old
  # Windows box can all read; GPT above, where MBR cannot address the sectors.
  size=$(lsblk -bdno SIZE "$device" 2>/dev/null)
  table=dos
  [[ ${size:-0} -gt $((2 * 1024 ** 4)) ]] && table=gpt

  echo
  echo "${dim}writing $table partition table…${reset}"
  udisks_call "$object" Block.Format "$table" "{'teardown': <true>}" >/dev/null || return 1

  # offset 0 + size 0 is udisks for "the whole drive, aligned properly".
  # `update-partition-type` sets the MBR type byte from the filesystem (0x0c
  # for FAT32 LBA, 0x07 for exFAT, 0x83 for ext4) instead of leaving the
  # default, and `take-ownership` chowns the new ext4 root to the caller, which
  # is the difference between a usable stick and a read-only one.
  echo "${dim}creating one $fs partition…${reset}"
  partition=$(
    udisks_call "$object" PartitionTable.CreatePartitionAndFormat \
      0 0 '' '' "{}" "$fs" \
      "{'label': <'$label'>, 'update-partition-type': <true>, 'take-ownership': <true>}"
  ) || return 1

  partition=${partition#*\'}
  partition=${partition%%\'*}
  echo "${accent}formatted $fs${label:+ ($label)} on ${partition##*/}.${reset}"

  # udiskie mounts it within the second; asking anyway is idempotent and covers
  # a machine with no automounter.
  sleep 1
  mounted || udisksctl mount -b "$(parts | head -1)" --no-user-interaction 2>&1 | sed 's/^/  /'
  lsblk -o NAME,SIZE,FSTYPE,LABEL,MOUNTPOINTS "$device"
}

# ── write an image ──────────────────────────────────────────────────────────

# Where images actually land. Depth 2 rather than a full-home scan so the list
# appears instantly; anything elsewhere goes in by path.
image_rows() {
  local dir
  for dir in "$HOME/Downloads" "$HOME/Desktop" "$HOME/Documents" "$HOME/iso" "$HOME/isos" "$HOME/Images"; do
    [[ -d $dir ]] || continue
    find "$dir" -maxdepth 2 -type f \( -iname '*.iso' -o -iname '*.img' \) \
      -printf '%s\t%TY-%Tm-%Td\t%p\n' 2>/dev/null
  done | sort -k2,2r |
    awk -F'\t' -v a="$accent" -v d="$dim" -v r="$reset" \
      '{ n=$3; sub(/.*\//, "", n);
         printf "%s%-42.42s%s %s%6.1f GB  %s  %s%s\t%s\n", a, n, r, d, $1/1073741824, $2, $3, r, $3 }'
}

do_write() {
  local list choice image size devsize answer
  list=$(image_rows)
  choice=$(
    { printf '%s\n' $'  '"${dim}type a path instead…${reset}"$'\t-'
      [[ -n $list ]] && printf '%s\n' "$list"; } |
      vfzf --ctx "$accent$g_write  image$reset" --back -- \
        --delimiter=$'\t' --with-nth=1
  ) || return 2  # back or cancel: nothing to read, so no pause -- see do_format
  image=$(vfzf_row "$choice" | cut -f2)
  [[ -n $image ]] || return 2
  if [[ $image == - ]]; then
    echo
    read -rep "path to image: " image
    image=${image/#\~/$HOME}
  fi
  [[ -f $image ]] || { echo "no such file: $image"; return 1; }

  size=$(stat -c %s "$image")
  devsize=$(lsblk -bdno SIZE "$device" 2>/dev/null)
  if [[ ${size:-0} -gt ${devsize:-0} ]]; then
    printf 'the image is larger than the drive (%s vs %s).\n' \
      "$(numfmt --to=iec "$size")" "$(numfmt --to=iec "$devsize")"
    return 1
  fi

  confirm_destructive "This overwrites the whole drive with $(basename "$image")." || return 1

  echo
  echo "${dim}sudo is needed to write to $device; a shell cannot be handed a"
  echo "raw block device by udisks.${reset}"
  # oflag=direct keeps the page cache out of the way so the progress line
  # tracks the drive rather than RAM; conv=fsync makes dd's exit mean the data
  # is on the device. Hybrid ISOs are meant to be written raw like this -- it
  # is the same command the Arch install guide gives.
  if ! sudo dd if="$image" of="$device" bs=4M status=progress oflag=direct conv=fsync; then
    # Covers both halves of a non-zero exit: sudo refusing the password, where
    # nothing was written, and dd stopping part way, where the drive holds
    # neither its old filesystem nor a bootable image. The reader can tell
    # which from the lines above; what they must not read is "it is fine".
    echo "the write did not finish. Nothing on this drive can be relied on until it is written or formatted again." >&2
    return 1
  fi
  sync

  # dd exiting 0 with conv=fsync only means the drive *accepted* the bytes. A
  # dying stick, or one lying about its capacity, acks a write and stores
  # something else -- and the reader finds out from a kernel panic halfway
  # through an install. So read the written region back and compare it.
  #
  # blockdev --flushbufs rather than iflag=direct on the read: O_DIRECT needs
  # every read length aligned, which the final partial block is not, while
  # count_bytes is what lets dd stop on the image's exact byte count instead of
  # rounding up to 4M and confusing cmp. Dropping the buffer cache first is
  # what makes this read the drive rather than the copy of it still in RAM --
  # without it the comparison verifies nothing.
  echo
  echo "${dim}verifying: reading it back off the drive.${reset}"
  # Unchecked, a failed flush would leave the comparison reading RAM and
  # passing every time -- a verification step that cannot fail is worse than
  # none, because it is believed.
  if ! sudo blockdev --flushbufs "$device"; then
    echo "${danger}could not drop the drive's cache, so the write cannot be verified.${reset}" >&2
    return 1
  fi
  if ! sudo dd if="$device" bs=4M count="$size" iflag=count_bytes status=progress |
      cmp "$image" -; then
    # cmp has already named the first differing byte, or dd the read error.
    echo "${danger}the drive does not read back what was written.${reset}" >&2
    echo "Do not boot from it. Try a different drive, or a different port; a drive that fails this is usually failing." >&2
    return 1
  fi
  echo "${accent}wrote and verified $(basename "$image") on $device.${reset}"

  echo
  read -rn1 -p "power the drive off for removal? [y/N] " answer
  echo
  [[ $answer == [yY] ]] && do_poweroff
  return 0
}

# ── the action menu ─────────────────────────────────────────────────────────

# Returns 2 to mean "back to the drive list" and 0 to mean "there is nothing
# left to do here": the drive was powered off, unplugged, or quit out of.
action_menu() {
  local action rc back=()
  # Named on the command line means the picker never ran, so there is no drive
  # list for h to go back to and the footer must not claim otherwise.
  (( locked )) || back=(--back)
  while :; do
    action=$(
      printf '%s\n' \
        "$g_power"$'\tPower off (safe removal)\tpoweroff' \
        "$g_format"$'\tFormat — erase and make one filesystem\tformat' \
        "$g_write"$'\tWrite image — make a bootable drive from an ISO\twrite' |
        awk -F'\t' -v a="$accent" -v d="$dim" -v r="$reset" \
          '{ printf "%s%s  %s%s%s\t%s\n", a, $1, d, $2, r, $3 }' |
        vfzf --ctx "$(describe)" "${back[@]}" -- \
          --delimiter=$'\t' --with-nth=1
    )
    rc=$?
    (( rc == 2 )) && return 2
    (( rc == 0 )) || return 0
    case $(vfzf_row "$action" | cut -f2) in
      poweroff) do_poweroff; pause; return 0 ;;
      # Anything that ran, finished or failed, leaves output worth reading; a
      # submenu backed out of (2) leaves none, so it goes straight back.
      format) do_format; (( $? == 2 )) || pause ;;
      write) do_write; (( $? == 2 )) || pause ;;
      *) return 0 ;;
    esac
    # Powered off, unplugged, or gone for some other reason: there is nothing
    # left to act on, so do not draw a menu for a device that is not there.
    [[ -b $device ]] || return 0
  done
}

# ── the tree ────────────────────────────────────────────────────────────────

# A device named on the command line means the picker never ran, so there is no
# level above the action menu for ctrl-h to go back to.
device=${1:-}
locked=0
[[ -n $device ]] && locked=1

while :; do
  if (( locked )); then
    # Named by a human, so a device that is not there is a typo worth an error.
    [[ -b $device ]] || { echo "not a block device: $device" >&2; exit 1; }
  else
    device=$(pick_drive) || exit 0
    [[ -n $device ]] || exit 0
    # Unplugged between the scan and the keypress: a stale row, not a broken
    # script. Go round and rescan rather than taking the window down.
    if [[ ! -b $device ]]; then
      say "$device is no longer attached."
      continue
    fi
  fi
  action_menu
  (( $? == 2 )) || exit 0
  (( locked )) && exit 0
done
