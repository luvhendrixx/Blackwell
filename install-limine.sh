#!/usr/bin/env bash
#
# Install the macOS-style Limine bootloader + automated kernel entries.
#
# What this does:
#   1. Deploys the Limine EFI binary to the ESP (and keeps the standard
#      EFI/BOOT fallback path intact for recovery)
#   2. Copies the themed limine.conf + wallpaper to the ESP
#   3. Registers a UEFI boot entry (when efibootmgr is usable)
#   4. Prints the follow-up for automatic kernel entries
#      (limine-mkinitcpio-hook-git / limine-entry-tool)
#
# Usage:
#   ./install-limine.sh              # install + deploy
#   ESP=/efi ./install-limine.sh     # if your ESP is not mounted at /boot
#
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ESP="${ESP:-/boot/EFI}"
DEST_BOOT="$ESP/BOOT"
DEST_LIMINE="$ESP/EFI/limine"

say()  { printf '\033[1;34m::\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m!!\033[0m %s\n' "$*"; }
die()  { printf '\033[1;31mxx\033[0m %s\n' "$*" >&2; exit 1; }

[ -d "$DEST_BOOT" ] || die "$DEST_BOOT not found — is that your ESP? (try ESP=/efi)"
# Allow the caller (install.sh) to pass a machine-adjusted config
LIMINE_CONF="${REPO_LIMINE_CONF:-$REPO_DIR/limine/limine.conf}"
[ -f "$LIMINE_CONF" ] || die "limine/limine.conf missing from the repo"

# ── 0. per-machine values ────────────────────────────────────────────────
# In limine/limine.conf, set:
#   root=UUID=<findmnt -no UUID />
#   path=boot():/EFI/Linux/<kernel>.efi   (or let limine-entry-tool manage it)

# ── 1. theme files ───────────────────────────────────────────────────────
say "Installing themed config + wallpaper to the ESP"
sudo cp "$DEST_BOOT/limine.conf" "$DEST_BOOT/limine.conf.bak.$(date +%Y%m%d-%H%M)" 2>/dev/null || true
sudo cp "$REPO_DIR/limine/wallpaper.jpg" "$DEST_BOOT/wallpaper.jpg"
# Exactly ONE config on the ESP, at its root: that is where limine-entry-tool
# manages it, and Limine also finds it there for the EFI/BOOT fallback binary.
# A second copy under EFI/BOOT would go stale (empty menu on the fallback path).
sudo cp "$LIMINE_CONF" "$ESP/limine.conf"
sudo rm -f "$DEST_BOOT/limine.conf"

# ── 1b. limine-entry-tool config (if the automation is installed) ───────
if [ -f "$REPO_DIR/limine/limine-entry-tool.conf" ] && command -v limine-mkinitcpio >/dev/null 2>&1; then
    say "Installing /etc/default/limine (limine-entry-tool settings)"
    sudo cp "$REPO_DIR/limine/limine-entry-tool.conf" /etc/default/limine
    # machine-specific: ESP mount point
    if ! grep -q "^ESP_PATH=" /etc/default/limine; then
        say "ESP_PATH not set in the config — add ESP_PATH=<mountpoint of your ESP>"
    fi
fi

# ── 2. Limine EFI binary ────────────────────────────────────────────────
say "Deploying Limine EFI"
sudo mkdir -p "$DEST_LIMINE"
sudo cp /usr/share/limine/BOOTX64.EFI "$DEST_LIMINE/limine_x64.efi"
# Keep/repair the fallback path too (some firmware ignores NVRAM entries).
sudo cp /usr/share/limine/BOOTX64.EFI "$DEST_BOOT/BOOTX64.EFI"

# ── 3. firmware entry (best effort) ─────────────────────────────────────
if command -v efibootmgr >/dev/null; then
    if efibootmgr | grep -qi "limine"; then
        say "Firmware entry for Limine already present"
    else
        disk=$(findmnt -no SOURCE "$ESP" | sed 's/[0-9]*$//;s/p$//')
        part=$(findmnt -no SOURCE "$ESP" | grep -o '[0-9]*$')
        if [ -n "$disk" ] && [ -n "$part" ]; then
            say "Registering Limine in firmware NVRAM"
            sudo efibootmgr --create --disk "$disk" --part "$part" \
                 --label "Limine (Arch Linux)" \
                 --loader '\EFI\limine\limine_x64.efi' --unicode || \
                 warn "efibootmgr failed — the EFI/BOOT fallback path still works"
        fi
    fi
fi

# ── 4. automated kernel entries (optional but recommended) ──────────────
if command -v limine-mkinitcpio >/dev/null 2>&1; then
    say "limine-mkinitcpio is installed — kernel entries are managed automatically"
    say "run 'sudo limine-install' once to register the managed Limine, then"
    say "rebuild a kernel with 'sudo limine-mkinitcpio -p <kernel>'"
else
    cat <<'EOF'

Next (recommended, enables automatic kernel entries):
  yay -S limine-mkinitcpio-hook-git kernel-modules-hook
  sudo limine-install
  sudo limine-mkinitcpio -p linux-zen

After that, every `pacman -S linux*` automatically adds/removes its
Limine boot entry. Keep this script's themed config at $ESP/limine.conf;
the tool preserves non-entry lines (wallpaper, interface_*, timeout).
EOF
fi

say "Done. Reboot to see the themed Limine menu."