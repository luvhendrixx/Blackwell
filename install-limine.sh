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
# ESP is the mount point of the EFI system partition (e.g. /boot or /efi),
# NOT a directory containing an EFI/ subdir. Older revisions appended /BOOT
# here, so passing ESP=/boot produced /boot/BOOT and aborted the install.
ESP="${ESP:-/boot}"
# Normalise a trailing slash.
ESP="${ESP%/}"
DEST_BOOT="$ESP/EFI/BOOT"
DEST_LIMINE="$ESP/EFI/limine"

say()  { printf '\033[1;34m::\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m!!\033[0m %s\n' "$*"; }
die()  { printf '\033[1;31mxx\033[0m %s\n' "$*" >&2; exit 1; }

# ESP is a mount point (/boot, /efi). Some older call sites passed the parent
# of the EFI dir instead, so normalise that back to the mount point.
case "$ESP" in
    */EFI) ESP="${ESP%/EFI}" ;;
esac

# Probe as root: an ESP mounted with dmask=0077 (mkfs.vfat default) is not
# readable by the invoking user, so a plain `[ -d ]` fails on a perfectly
# good ESP. sudo is already required for everything else in this script.
sudo test -d "$ESP/EFI" || sudo mkdir -p "$DEST_BOOT" \
    || die "$ESP does not look like an ESP mount point (no $ESP/EFI, and
       could not create it). Pass the mount point, e.g. ESP=/boot or ESP=/efi."
# Allow the caller (install.sh) to pass a machine-adjusted config
LIMINE_CONF="${REPO_LIMINE_CONF:-$REPO_DIR/limine/limine.conf}"
[ -f "$LIMINE_CONF" ] || die "limine/limine.conf missing from the repo"

# ── 0. per-machine values ────────────────────────────────────────────────
# In limine/limine.conf, set:
#   root=UUID=<findmnt -no UUID />
#   path=boot():/EFI/Linux/<kernel>.efi   (or let limine-entry-tool manage it)

# ── 1. theme files ───────────────────────────────────────────────────────
say "Installing themed config + wallpaper to the ESP"
sudo cp "$REPO_DIR/limine/wallpaper.jpg" "$DEST_BOOT/wallpaper.jpg"
# Exactly ONE config on the ESP, at its root: that is where limine-entry-tool
# manages it, and Limine also finds it there for the EFI/BOOT fallback binary.
# A second copy under EFI/BOOT goes stale and makes Limine warn about
# conflicting configs, then load the stale one (often an empty menu).
# Carry the existing boot entries across. The repo template deliberately ships
# with no entries (limine-entry-tool generates them), so a plain cp leaves a
# themed menu with nothing to boot. Entries are the block starting at the first
# line beginning with '/' at column 0; everything above it is theme/settings.
tmp_conf=$(mktemp)
if sudo test -f "$ESP/limine.conf"; then
    sudo cp "$ESP/limine.conf" "$ESP/limine.conf.bak.$(date +%Y%m%d-%H%M)"
    sudo sh -c 'ls -1t "$1"/limine.conf.bak.* 2>/dev/null | tail -n +4 | xargs -r rm -f' _ "$ESP"
    sudo cat "$ESP/limine.conf" > "$tmp_conf.old" 2>/dev/null
    entry_block=$(sed -n '/^[^[:space:]]/,$ { /^\//,$p }' "$tmp_conf.old")
    if [ -n "$entry_block" ]; then
        say "Preserving existing boot entries ($(grep -c '^/' <<< "$entry_block") top-level)"
        cp "$LIMINE_CONF" "$tmp_conf.new"
        { cat "$tmp_conf.new"; printf '\n'; printf '%s\n' "$entry_block"; } > "$tmp_conf"
        sudo cp "$tmp_conf" "$ESP/limine.conf"
    else
        warn "No boot entries found on the ESP -- menu will be empty until"
        warn "you run: sudo limine-mkinitcpio"
        sudo cp "$LIMINE_CONF" "$ESP/limine.conf"
    fi
    rm -f "$tmp_conf.old"
else
    warn "No existing $ESP/limine.conf -- menu will be empty until you run:"
    warn "  sudo limine-mkinitcpio"
    sudo cp "$LIMINE_CONF" "$ESP/limine.conf"
fi
rm -f "$tmp_conf" "$tmp_conf.new"

# Remove the stale copies that shadow it. Probe with sudo for the same
# dmask reason as above, otherwise every stray looks absent and is skipped.
for stray in "$DEST_BOOT/limine.conf" "$ESP/EFI/limine/limine.conf" "$ESP/boot/limine.conf"; do
    if sudo test -f "$stray"; then
        warn "Removing conflicting Limine config: $stray"
        sudo rm -f "$stray"
    fi
done

# ── 1b. limine-entry-tool config (if the automation is installed) ───────
if [ -f "$REPO_DIR/limine/limine-entry-tool.conf" ] && command -v limine-mkinitcpio >/dev/null 2>&1; then
    say "Installing /etc/default/limine (limine-entry-tool settings)"
    sudo cp "$REPO_DIR/limine/limine-entry-tool.conf" /etc/default/limine
    # machine-specific: ESP mount point
    if grep -q "^ESP_PATH=" /etc/default/limine; then
        sudo sed -i "s|^ESP_PATH=.*|ESP_PATH=$ESP|" /etc/default/limine
        say "Set ESP_PATH=$ESP in /etc/default/limine"
    else
        printf 'ESP_PATH=%s\n' "$ESP" | sudo tee -a /etc/default/limine >/dev/null
        say "Appended ESP_PATH=$ESP to /etc/default/limine"
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
    if sudo efibootmgr | grep -qi "limine"; then
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
