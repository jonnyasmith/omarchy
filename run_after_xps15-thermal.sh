#!/usr/bin/env bash
#
# Thermal and hybrid-GPU fixes for the Dell XPS 15 9500 (Comet Lake i9-10885H +
# Turing GTX 1650 Ti). Everything here lives in /etc, so chezmoi cannot own the
# files directly and an `omarchy update` cannot preserve them either.
#
# Two problems, both from Omarchy defaults meeting five-year-old laptop cooling:
#
# 1. Dell's firmware advertises a 68 W sustained package limit (PL1) in both the
#    MSR and MMIO RAPL domains, 23 W above the i9-10885H's 45 W spec. This
#    chassis cannot move 68 W: a sustained all-core load parks the package at
#    Tjmax (100 C) and pins both fans at maximum. Capping PL1 to the CPU's stock
#    45 W costs nothing that this cooling system could have delivered anyway.
#    PL2 is left alone, so short bursts still boost.
#
# 2. install/hardware/nvidia.sh writes `nvidia_drm modeset=1` plus early KMS for
#    any NVIDIA GPU, with no hybrid-laptop branch, and nothing ever sets
#    power/control on the dGPU. The kernel therefore forbids PCIe D3, so the
#    1650 Ti sits in D0 at ~3 W and 57 C for an entire uptime while aquamarine
#    renders the desktop on the Intel iGPU. NVreg_DynamicPowerManagement=0x02
#    asks for fine-grained RTD3 explicitly rather than leaving it to the
#    driver's platform guess.
#
# It also enables the nvidia sleep units. Omarchy's installer sets
# PreserveVideoMemoryAllocations=1 (implied by its early-KMS setup) but never
# enables the services that save and restore that memory, which is what makes a
# resume come back with a corrupt framebuffer.
#
# Every step is guarded and idempotent: wrong machine, missing GPU or missing
# units mean this script does nothing at all.

set -euo pipefail

# Only this model. The PL1 number is specific to its firmware and cooling.
[[ $(cat /sys/class/dmi/id/product_name 2>/dev/null) == "XPS 15 9500" ]] || exit 0

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

announced=false
announce() {
  $announced && return 0
  echo "Applying XPS 15 9500 thermal and GPU power configuration (needs root)..."
  announced=true
}

# Install $1 at $2 when the content differs. Returns 0 when it wrote.
install_if_changed() {
  local staged=$1 target=$2
  cmp -s "$staged" "$target" && return 1
  announce
  pkexec install -Dm644 -o root -g root "$staged" "$target"
}

# --- 1. Cap sustained package power at the i9-10885H's 45 W spec -------------

cat >"$tmp/rapl.service" <<'EOF'
[Unit]
Description=Cap CPU package power (RAPL) to what this chassis can cool
Documentation=man:intel_rapl(4)
# The firmware value is restored by resume, so this runs again afterwards.
After=suspend.target hibernate.target hybrid-sleep.target suspend-then-hibernate.target
ConditionPathExists=/sys/class/powercap/intel-rapl:0/constraint_0_power_limit_uw

[Service]
Type=oneshot
RemainAfterExit=yes
# Three writes per domain, and the MMIO domain matters because that is the one
# Dell's firmware programs; the lower of the two wins. A domain that refuses a
# write is not fatal.
#
#   PL1 45 W  - the i9-10885H's spec, down from Dell's 68 W.
#   window 28 s - Intel's default, down from Dell's 56 s, so PL1 starts
#                 governing about half a minute sooner.
#   PL2 60 W  - measured: this cooling system reaches Tjmax within seconds
#               above ~60 W, and the 135 W firmware value only buys time at
#               100 C with both fans at maximum.
ExecStart=/usr/bin/bash -c 'for d in /sys/class/powercap/intel-rapl:0 /sys/class/powercap/intel-rapl-mmio:0; do [[ -w $d/constraint_0_power_limit_uw ]] && echo 45000000 >$d/constraint_0_power_limit_uw; [[ -w $d/constraint_0_time_window_us ]] && echo 28000000 >$d/constraint_0_time_window_us; [[ -w $d/constraint_1_power_limit_uw ]] && echo 60000000 >$d/constraint_1_power_limit_uw; done; exit 0'

[Install]
WantedBy=multi-user.target
WantedBy=suspend.target
WantedBy=hibernate.target
WantedBy=hybrid-sleep.target
WantedBy=suspend-then-hibernate.target
EOF

rapl_unit=/etc/systemd/system/cpu-power-cap.service
if install_if_changed "$tmp/rapl.service" "$rapl_unit"; then
  pkexec systemctl daemon-reload
fi
if ! systemctl is-enabled --quiet cpu-power-cap.service 2>/dev/null; then
  announce
  pkexec systemctl enable --now cpu-power-cap.service
fi

# --- 2. Let the discrete GPU reach D3cold -----------------------------------

if [[ -d /sys/module/nvidia ]]; then
  # ATTR{power/control}="auto" on bind is the piece nvidia-utils stopped
  # shipping; without it the kernel never even offers D3 to the driver.
  cat >"$tmp/nvidia-pm.rules" <<'EOF'
# Allow PCIe runtime power management on NVIDIA display/3D controllers, so a
# Turing+ dGPU with no clients can drop to D3cold instead of idling in D0.
ACTION=="bind", SUBSYSTEM=="pci", ATTR{vendor}=="0x10de", ATTR{class}=="0x030000", ATTR{power/control}="auto"
ACTION=="bind", SUBSYSTEM=="pci", ATTR{vendor}=="0x10de", ATTR{class}=="0x030200", ATTR{power/control}="auto"
ACTION=="unbind", SUBSYSTEM=="pci", ATTR{vendor}=="0x10de", ATTR{class}=="0x030000", ATTR{power/control}="on"
ACTION=="unbind", SUBSYSTEM=="pci", ATTR{vendor}=="0x10de", ATTR{class}=="0x030200", ATTR{power/control}="on"
EOF
  install_if_changed "$tmp/nvidia-pm.rules" /etc/udev/rules.d/80-nvidia-pm.rules || true

  # Fine-grained RTD3. Without this the driver reports "Runtime D3 status:
  # Disabled by default" on this platform, whatever power/control says.
  # Separate file from Omarchy's /etc/modprobe.d/nvidia.conf, which the
  # installer rewrites wholesale.
  printf 'options nvidia NVreg_DynamicPowerManagement=0x02\n' >"$tmp/nvidia-pm.conf"
  install_if_changed "$tmp/nvidia-pm.conf" /etc/modprobe.d/nvidia-power-management.conf || true

  # The nvidia modules load from the boot image here (MODULES+= in
  # /etc/mkinitcpio.conf.d/nvidia.conf), so the parameter only reaches them if
  # the modconf hook baked this file in. This machine boots a UKI
  # (/boot/EFI/Linux/*.efi, built by kernel-install, with no mkinitcpio
  # presets), so `mkinitcpio -P` would be a no-op — it must be rebuilt through
  # kernel-install. Ask the image itself rather than tracking whether the file
  # just changed: an interrupted rebuild or a later kernel upgrade both leave
  # the answer in /boot.
  #
  # A layout with no recognisable image is reported, never silently accepted.
  rebuild=$(pkexec bash -c '
      command -v lsinitcpio >/dev/null 2>&1 || { echo unknown; exit 0; }
      found=false
      for img in /boot/EFI/Linux/*.efi /boot/initramfs-linux*.img; do
        [[ -e $img ]] || continue
        case $img in *-fallback.img) continue ;; esac
        found=true
        if ! lsinitcpio "$img" 2>/dev/null | grep -q "modprobe.d/nvidia-power-management.conf"; then
          echo stale
          exit 0
        fi
      done
      $found && echo current || echo unknown')

  case $rebuild in
    stale)
      announce
      echo "Rebuilding the boot image so the NVIDIA power parameter reaches early KMS..."
      # limine-mkinitcpio builds the UKI and updates /boot/limine.conf in one
      # step. `kernel-install add-all` reaches it too, by way of a
      # 50-mkinitcpio.install that first fails loudly over the empty
      # /etc/mkinitcpio.d, so it is only the fallback.
      if command -v limine-mkinitcpio >/dev/null 2>&1; then
        pkexec limine-mkinitcpio
      elif [[ -d /boot/EFI/Linux ]] && command -v kernel-install >/dev/null 2>&1; then
        pkexec kernel-install add-all
      else
        pkexec mkinitcpio -P
      fi
      ;;
    unknown)
      echo "warning: cannot inspect the boot image; check that" \
           "NVreg_DynamicPowerManagement reaches the nvidia module" >&2
      ;;
  esac

  # Required by PreserveVideoMemoryAllocations=1, which the driver already has.
  for unit in nvidia-suspend.service nvidia-resume.service nvidia-hibernate.service; do
    systemctl list-unit-files "$unit" --no-legend 2>/dev/null | grep -q . || continue
    systemctl is-enabled --quiet "$unit" 2>/dev/null && continue
    announce
    pkexec systemctl enable "$unit"
  done
fi
