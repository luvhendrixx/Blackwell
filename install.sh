#!/usr/bin/env bash
#
# luvhendrixx/dotfiles — installer
# Arch Linux + Hyprland (Lua config) + Quickshell desktop
#
# Usage:
#   ./install.sh              # install packages and link configs
#   ./install.sh --link-only  # only (re)create the config symlinks
#   ./install.sh --dry-run    # print what would happen
#
set -uo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC="$REPO_DIR/.config"
CONFIG_DIR="$HOME/.config"
DRY_RUN=0
LINK_ONLY=0

for arg in "$@"; do
    case "$arg" in
        --dry-run)   DRY_RUN=1 ;;
        --link-only) LINK_ONLY=1 ;;
        -h|--help)   sed -n '2,12p' "$0"; exit 0 ;;
    esac
done

say()  { printf '\033[1;34m::\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m!!\033[0m %s\n' "$*"; }
die()  { printf '\033[1;31mxx\033[0m %s\n' "$*" >&2; exit 1; }

run() { if [ "$DRY_RUN" = 1 ]; then echo "  would run: $*"; else "$@"; fi; }

# ── 1. sanity checks ────────────────────────────────────────────────────────
[ "$(uname -s)" = "Linux" ] || die "Linux only."
if [ -e /etc/arch-release ] || [ -e /etc/endeavouros-release ]; then
    say "Arch-based system detected"
else
    warn "This dotfiles set targets Arch Linux; continuing anyway."
fi

command -v pacman >/dev/null || die "pacman not found."
command -v git    >/dev/null || die "git not found."

# ── 2. packages ─────────────────────────────────────────────────────────────
if [ "$LINK_ONLY" = 0 ]; then
    if command -v yay >/dev/null; then
        AUR_HELPER=yay
    elif command -v paru >/dev/null; then
        AUR_HELPER=paru
    else
        AUR_HELPER=""
    fi

    if [ -f "$REPO_DIR/packages-repo.txt" ]; then
        say "Installing official-repo packages"
        # shellcheck disable=SC2046
        run sudo pacman -S --needed --noconfirm $(grep -vE '^\s*(#|$)' "$REPO_DIR/packages-repo.txt" | tr '\n' ' ')
    fi

    if [ -n "$AUR_HELPER" ] && [ -f "$REPO_DIR/packages-aur.txt" ]; then
        say "Installing AUR packages with $AUR_HELPER"
        # shellcheck disable=SC2046
        run "$AUR_HELPER" -S --needed --noconfirm $(grep -vE '^\s*(#|$)' "$REPO_DIR/packages-aur.txt" | tr '\n' ' ')
    elif [ -f "$REPO_DIR/packages-aur.txt" ]; then
        warn "No AUR helper found; install packages-aur.txt manually."
    fi

    # Optional extras not in the package lists
    say "Ensuring helper tools are present"
    run sudo pacman -S --needed --noconfirm brightnessctl rofimoji wtype keyd python-fonttools imagemagick
fi

# ── 3. symlink configs ──────────────────────────────────────────────────────
say "Linking configs from $SRC into $CONFIG_DIR"
mkdir -p "$CONFIG_DIR"

link_one() {
    local rel="$1"
    local src="$SRC/$rel"
    local dst="$CONFIG_DIR/$rel"

    [ -e "$src" ] || return 0
    mkdir -p "$(dirname "$dst")"

    if [ -L "$dst" ]; then
        local current
        current="$(readlink "$dst")"
        [ "$current" = "$src" ] && return 0
        run rm "$dst"
    elif [ -e "$dst" ]; then
        local backup="$dst.pre-dotfiles"
        warn "$dst exists — moving to $backup"
        run mv "$dst" "$backup"
    fi

    run ln -s "$src" "$dst"
    echo "  linked $rel"
}

for entry in "$SRC"/*; do
    [ -e "$entry" ] || continue
    link_one "$(basename "$entry")"
done

# Wallpapers -> ~/Pictures/Wallpapers
if [ -d "$REPO_DIR/wallpapers" ]; then
    mkdir -p "$HOME/Pictures"
    if [ -d "$HOME/Pictures/Wallpapers" ] && [ ! -L "$HOME/Pictures/Wallpapers" ]; then
        warn "$HOME/Pictures/Wallpapers exists — merging repo wallpapers in"
        cp -an "$REPO_DIR/wallpapers/." "$HOME/Pictures/Wallpapers/" 2>/dev/null
    fi
    run rm -rf "$HOME/Pictures/Wallpapers"
    run ln -s "$REPO_DIR/wallpapers" "$HOME/Pictures/Wallpapers"
    echo "  linked ~/Pictures/Wallpapers"
fi

# Home-level dotfiles
if [ -d "$REPO_DIR/home" ]; then
    say "Linking home dotfiles"
    for f in "$REPO_DIR/home"/.*; do
        case "$f" in */.|*/..) continue ;; esac
        [ -f "$f" ] || continue
        name="$(basename "$f")"
        [ -L "$HOME/$name" ] && continue
        [ -e "$HOME/$name" ] && run mv "$HOME/$name" "$HOME/$name.pre-dotfiles"
        run ln -s "$f" "$HOME/$name"
        echo "  linked ~/$name"
    done
fi

# ── 4. post-install steps ───────────────────────────────────────────────────
if [ "$DRY_RUN" = 0 ]; then
    say "Enabling keyd (Right Shift = compose key)"
    if [ -f /etc/keyd/default.conf ]; then
        run sudo systemctl enable --now keyd
    else
        printf '[ids]\n*\n\n[main]\nrightshift = compose\n' \
            | run sudo tee /etc/keyd/default.conf >/dev/null
        run sudo systemctl enable --now keyd
    fi

    say "Enabling pacman housekeeping"
    run sudo systemctl enable --now paccache-hook.service 2>/dev/null
    run sudo systemctl enable --now pacman-orphans.timer 2>/dev/null

    say "Setting cursor + icon defaults"
    run gsettings set org.gnome.desktop.interface cursor-theme 'Bibata-Modern-Ice'
    run gsettings set org.gnome.desktop.interface cursor-size 15
    run gsettings set org.gnome.desktop.interface icon-theme 'Papirus-Dark'
    run xdg-mime default org.gnome.Nautilus.desktop inode/directory
fi

# ── 5. done ─────────────────────────────────────────────────────────────────
cat <<'EOF'

Setup complete.

  • Log out and back in (or reboot) so keyd, XCURSOR_* and the shell profile
    are applied to every session.
  • Bootloader theme: sudo ./install-limine.sh  (copies limine/limine.conf and
    limine/wallpaper.jpg to the ESP).
  • Keymap cheat sheet: press the  key in the bar, or run
    ~/.config/hypr/scripts/keymaps.sh
EOF