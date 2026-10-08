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

    # pacman -S aborts the WHOLE transaction on one unresolvable target, so a
    # single AUR name left in packages-repo.txt silently blocks every other
    # package. Filter the list against the configured sync databases and hand
    # the leftovers to the AUR helper instead.
    strays=""

    aur_fallback_list() {
        grep -vE '^\s*(#|$)' "$REPO_DIR/packages-repo.txt" \
            | while read -r p; do
                  pacman -Slq 2>/dev/null | grep -qxF "$p" || printf '%s\n' "$p"
              done
    }

    if [ -f "$REPO_DIR/packages-repo.txt" ]; then
        repo_pkgs=$(grep -vE '^\s*(#|$)' "$REPO_DIR/packages-repo.txt" | tr '\n' ' ')
        strays=$(aur_fallback_list)

        if [ -n "$repo_pkgs" ]; then
            say "Installing official-repo packages"
            # shellcheck disable=SC2046
            run sudo pacman -S --needed --noconfirm $repo_pkgs \
                || die "pacman failed to install official-repo packages."
        fi

        if [ -n "$strays" ]; then
            warn "Not in official repos, deferring to the AUR helper:"
            printf '     %s\n' $strays
            printf '   (add these to packages-aur.txt to make it permanent)\n'
        fi
    fi

    if [ -n "$AUR_HELPER" ]; then
        aur_pkgs=""
        [ -f "$REPO_DIR/packages-aur.txt" ] && \
            aur_pkgs=$(grep -vE '^\s*(#|$)' "$REPO_DIR/packages-aur.txt" | tr '\n' ' ')
        # repo-list strays are appended so they still get installed
        aur_pkgs="$aur_pkgs $strays"

        if [ -n "$(printf '%s' "$aur_pkgs" | tr -d ' ')" ]; then
            say "Installing AUR packages with $AUR_HELPER"
            # shellcheck disable=SC2046
            run "$AUR_HELPER" -S --needed --noconfirm $aur_pkgs \
                || die "$AUR_HELPER failed to install AUR packages."
        fi
    elif [ -f "$REPO_DIR/packages-aur.txt" ]; then
        warn "No AUR helper found; install packages-aur.txt manually."
    fi

    # Extras that are already in packages-repo.txt; kept as a safety net for
    # people who trimmed the list. Failure here is not fatal.
    say "Ensuring helper tools are present"
    # shellcheck disable=SC2046
    run sudo pacman -S --needed --noconfirm brightnessctl rofimoji wtype keyd python-fonttools imagemagick \
        || warn "Some helper tools failed to install."
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

# ── 5. bootloader ────────────────────────────────────────────────────────────
# Limine needs machine-specific values, so we detect them here instead of
# making you hand-edit anything:
#   * root filesystem UUID  -> substituted into limine/limine.conf
#   * ESP mount point       -> where the EFI/limine binaries and config land
if [ "$DRY_RUN" = 0 ]; then
    esp=$(findmnt -rno TARGET,FSTYPE | awk '$2=="vfat"{print $1; exit}')
    root_uuid=$(findmnt -no UUID /)

    if [ -n "$esp" ] && [ -n "$root_uuid" ]; then
        say "ESP mounted at $esp, root UUID $root_uuid"

        # machine-local limine.conf with this machine's root UUID
        cp "$REPO_DIR/limine/limine.conf" /tmp/limine.conf.new
        sed -i "s|root=UUID=[0-9a-f-]*|root=UUID=$root_uuid|" /tmp/limine.conf.new

        # /etc/kernel/cmdline is the canonical kernel cmdline on Arch
        if [ ! -f /etc/kernel/cmdline ]; then
            mkdir -p /etc/kernel
            printf 'root=UUID=%s rootflags=subvol=@ rw rootfstype=btrfs quiet splash\n' \
                "$root_uuid" > /etc/kernel/cmdline
            say "Wrote /etc/kernel/cmdline"
        elif ! grep -qE "$root_uuid|$(findmnt -no PARTUUID /)" /etc/kernel/cmdline; then
            # A PARTUUID cmdline is legitimate and survives disk swaps just as
            # well as a UUID one, so only complain if neither is present.
            warn "/etc/kernel/cmdline matches neither the root UUID nor PARTUUID."
            warn "Boot is currently using: $(cat /proc/cmdline)"
        fi

        say "Deploying the themed Limine bootloader"
        if [ -x "$REPO_DIR/install-limine.sh" ]; then
            REPO_LIMINE_CONF=/tmp/limine.conf.new ESP="$esp" "$REPO_DIR/install-limine.sh" || \
                die "install-limine.sh failed — the bootloader was NOT themed.
       Re-run it manually once fixed: ESP=$esp ./install-limine.sh"
        fi

        if command -v limine-mkinitcpio >/dev/null 2>&1; then
            say "Generating a boot entry for the installed kernel(s)"
            sudo limine-install
            sudo limine-mkinitcpio || warn "limine-mkinitcpio failed — run it again after fixing."
        else
            warn "limine-mkinitcpio-hook-git not installed: kernel entries will NOT be"
            warn "automatic yet. Install it with: yay -S limine-mkinitcpio-hook-git kernel-modules-hook"
        fi
        rm -f /tmp/limine.conf.new
    else
        warn "Could not detect an ESP mount point or root UUID — skipping bootloader setup."
        warn "Run ./install-limine.sh manually once you know the ESP path."
    fi
fi

# ── 6. done ─────────────────────────────────────────────────────────────────
cat <<'EOF'

Setup complete.

  • Log out and back in (or reboot) so keyd, XCURSOR_* and the shell profile
    are applied to every session.
  • Reboot to see the themed Limine menu. From then on, kernel updates
    install their own boot entries automatically.
  • Keymap cheat sheet: click the  key in the bar, or run
    ~/.config/hypr/scripts/keymaps.sh
EOF