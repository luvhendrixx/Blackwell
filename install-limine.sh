#!/usr/bin/env bash
# Install the macOS-style Limine bootloader theme to the ESP.
# Adjust ESP=/boot/EFI or /efi if yours differs.
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ESP="${ESP:-/boot/EFI}"
DEST="$ESP/BOOT"

[ -d "$DEST" ] || { echo "!! $DEST not found — set ESP=... and retry" >&2; exit 1; }
[ -f "$DEST/limine.conf" ] || { echo "!! no limine.conf in $DEST — is Limine your bootloader?" >&2; exit 1; }

sudo cp "$DEST/limine.conf" "$DEST/limine.conf.bak.$(date +%Y%m%d)"
sudo cp "$REPO_DIR/limine/limine.conf" "$DEST/limine.conf"
sudo cp "$REPO_DIR/limine/wallpaper.jpg" "$DEST/wallpaper.jpg"

echo "Limine theme installed to $DEST (previous config backed up)."
echo "NOTE: edit the root=PARTUUID line in limine/limine.conf to match your machine."