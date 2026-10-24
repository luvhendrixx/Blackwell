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
CACHYOS=0

for arg in "$@"; do
  case "$arg" in
  --dry-run) DRY_RUN=1 ;;
  --link-only) LINK_ONLY=1 ;;
  --cachyos) CACHYOS=1 ;;
  -h | --help)
    sed -n '2,12p' "$0"
    exit 0
    ;;
  esac
done

say() { printf '\033[1;34m::\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m!!\033[0m %s\n' "$*"; }
die() {
  printf '\033[1;31mxx\033[0m %s\n' "$*" >&2
  exit 1
}

run() { if [ "$DRY_RUN" = 1 ]; then echo "  would run: $*"; else "$@"; fi; }

# ── 1. sanity checks ────────────────────────────────────────────────────────
[ "$(uname -s)" = "Linux" ] || die "Linux only."
if [ -e /etc/arch-release ] || [ -e /etc/endeavouros-release ]; then
  say "Arch-based system detected"
else
  warn "This dotfiles set targets Arch Linux; continuing anyway."
fi

command -v pacman >/dev/null || die "pacman not found."
command -v git >/dev/null || die "git not found."

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

  # Snapshot the sync databases once. Do NOT call pacman inside the read
  # loop: it inherits the loop's stdin and swallows the remaining lines.
  sync_db=$(pacman -Slq 2>/dev/null)

  # Use a here-string, not a pipe: `grep -q` exits on first match and the
  # upstream printf dies of SIGPIPE, which pipefail reports as failure --
  # so a piped grep -q would report every package as missing.
  aur_fallback_list() {
    grep -vE '^\s*(#|$)' "$REPO_DIR/packages-repo.txt" |
      while read -r p; do
        grep -qxF "$p" <<<"$sync_db" || printf '%s\n' "$p"
      done
  }

  if [ -f "$REPO_DIR/packages-repo.txt" ]; then
    repo_pkgs=$(grep -vE '^\s*(#|$)' "$REPO_DIR/packages-repo.txt" |
      while read -r p; do
        grep -qxF "$p" <<<"$sync_db" && printf '%s\n' "$p"
      done | tr '\n' ' ')
    strays=$(aur_fallback_list)

    if [ -n "$repo_pkgs" ]; then
      say "Installing official-repo packages"
      # shellcheck disable=SC2046
      run sudo pacman -S --needed --noconfirm $repo_pkgs ||
        die "pacman failed to install official-repo packages."
    fi

    if [ -n "$strays" ]; then
      warn "Not in official repos, deferring to the AUR helper:"
      printf '     %s\n' $strays
      printf '   (add these to packages-aur.txt to make it permanent)\n'
    fi
  fi

  if [ -n "$AUR_HELPER" ]; then
    aur_pkgs=""
    [ -f "$REPO_DIR/packages-aur.txt" ] &&
      aur_pkgs=$(grep -vE '^\s*(#|$)' "$REPO_DIR/packages-aur.txt" | tr '\n' ' ')
    # repo-list strays are appended so they still get installed
    aur_pkgs="$aur_pkgs $strays"

    if [ -n "$(printf '%s' "$aur_pkgs" | tr -d ' ')" ]; then
      say "Installing AUR packages with $AUR_HELPER"
      # shellcheck disable=SC2046
      run "$AUR_HELPER" -S --needed --noconfirm $aur_pkgs ||
        die "$AUR_HELPER failed to install AUR packages."
    fi
  elif [ -f "$REPO_DIR/packages-aur.txt" ]; then
    warn "No AUR helper found; install packages-aur.txt manually."
  fi

  # Extras that are already in packages-repo.txt; kept as a safety net for
  # people who trimmed the list. Failure here is not fatal.
  say "Ensuring helper tools are present"
  # shellcheck disable=SC2046
  run sudo pacman -S --needed --noconfirm brightnessctl rofimoji wtype keyd python-fonttools imagemagick libvips wf-recorder ||
    warn "Some helper tools failed to install."
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
    warn "$HOME/Pictures/Wallpapers exists — moving to .pre-dotfiles"
    run mv "$HOME/Pictures/Wallpapers" "$HOME/Pictures/Wallpapers.pre-dotfiles"
  fi
  [ -L "$HOME/Pictures/Wallpapers" ] && run rm "$HOME/Pictures/Wallpapers"
  run ln -s "$REPO_DIR/wallpapers" "$HOME/Pictures/Wallpapers"
  echo "  linked ~/Pictures/Wallpapers"
fi

# Home-level dotfiles
if [ -d "$REPO_DIR/home" ]; then
  say "Linking home dotfiles"
  for f in "$REPO_DIR/home"/.*; do
    case "$f" in */. | */..) continue ;; esac
    [ -f "$f" ] || continue
    name="$(basename "$f")"
    [ -L "$HOME/$name" ] && continue
    [ -e "$HOME/$name" ] && run mv "$HOME/$name" "$HOME/$name.pre-dotfiles"
    run ln -s "$f" "$HOME/$name"
    echo "  linked ~/$name"
  done
fi

# fastfetch doesn't expand $HOME or ~ in logo paths, so its config ships with
# an @HOME@ placeholder. Give each user a patched REAL copy of the config (in a
# real dir, not the symlinked one) so the repo file stays clean for the next
# person; other assets in the repo dir (images, etc.) are symlinked back in.
ff_dir="$CONFIG_DIR/fastfetch"
if [ -d "$SRC/fastfetch" ]; then
  if [ -L "$ff_dir" ]; then
    run rm "$ff_dir"
  elif [ -e "$ff_dir" ]; then
    run mv "$ff_dir" "$ff_dir.pre-dotfiles"
  fi
  run mkdir -p "$ff_dir"
  run cp "$SRC/fastfetch/config.jsonc" "$ff_dir/config.jsonc"
  for f in "$SRC/fastfetch"/*; do
    name="$(basename "$f")"
    [ "$name" = "config.jsonc" ] && continue
    [ -e "$ff_dir/$name" ] || run ln -s "$f" "$ff_dir/$name"
  done
  run sed -i "s|@HOME@|$HOME|g" "$ff_dir/config.jsonc"
  echo "  patched fastfetch config (per-user copy)"
fi

# ── 4. post-install steps ───────────────────────────────────────────────────
if [ "$DRY_RUN" = 0 ] && [ "$LINK_ONLY" = 0 ]; then
  say "Enabling keyd (Right Shift = compose key)"
  if [ -f "$SRC/keyd/default.conf" ]; then
    run sudo ln -sf "$SRC/keyd/default.conf" /etc/keyd/default.conf
  else
    printf '[ids]\n*\n\n[main]\nrightshift = compose\n' |
      run sudo tee /etc/keyd/default.conf >/dev/null
  fi
  run sudo systemctl enable --now keyd

  say "Setting up auto-cpufreq (replaces other power managers)"
  if systemctl cat auto-cpufreq.service >/dev/null 2>&1; then
    for svc in power-profiles-daemon tlp; do
      systemctl cat "$svc.service" >/dev/null 2>&1 && run sudo systemctl disable --now "$svc"
    done
    run sudo systemctl enable --now auto-cpufreq
  else
    warn "auto-cpufreq not installed; skipping (add it to packages-aur.txt)"
  fi
  if [ "$CACHYOS" = 1 ]; then
    say "Installing the CachyOS kernel"
    if pacman -Sl cachyos >/dev/null 2>&1; then
      run sudo pacman -S --needed --noconfirm linux-cachyos linux-cachyos-headers ||
        warn "CachyOS kernel install failed."
    else
      warn "The CachyOS repo is not enabled; set it up first (see cachyos.org), then re-run with --cachyos."
    fi
  fi
  say "Installing fallback kernels (ZEN + stock linux, so limine always has a bootable entry)"
  run sudo pacman -S --needed --noconfirm linux-zen linux ||
    warn "Fallback kernel install failed."
  say "Enabling pacman housekeeping"
  run sudo systemctl enable --now paccache-hook.service 2>/dev/null
  run sudo systemctl enable --now pacman-orphans.timer 2>/dev/null
  run sudo systemctl enable --now fwupd-refresh.timer 2>/dev/null

  say "Setting cursor + icon defaults"
  run gsettings set org.gnome.desktop.interface cursor-theme 'Bibata-Modern-Ice'
  run gsettings set org.gnome.desktop.interface cursor-size 15
  run xdg-mime default org.gnome.Nautilus.desktop inode/directory

  # ── MacLock: PAM stack ──────────────────────────────────────────────────
  # MacLock checks passwords with PAM. Ship a dedicated stack so it doesn't
  # depend on hyprlock; if this file is ever missing, MacLock falls back to
  # /etc/pam.d/login (always present via pambase).
  say "Installing MacLock PAM config"
  run sudo install -D -m 644 "$REPO_DIR/system/pam.d/maclock" /etc/pam.d/maclock

  # ── Firmware update notice ──────────────────────────────────────────────
  # After each pacman upgrade, tell the user if fwupd (LVFS) has firmware
  # updates available. It only prints a notice; it never installs anything.
  say "Installing fwupd firmware-check pacman hook"
  run sudo install -D -m 644 "$REPO_DIR/system/pacman.d/hooks/95-fwupd-check.hook" /etc/pacman.d/hooks/95-fwupd-check.hook

  # ── MacLock: compile the fragment shaders (liquidglass, burn, …) ───────
  # The QML references "*.frag.qsb" directly. Without them everything drawn
  # through ShaderEffect — cover art, contour glow, glass refraction —
  # silently renders nothing, so the lock screen loses its cover art.
  if [ "$LINK_ONLY" = 0 ]; then
    if [ "$DRY_RUN" = 1 ]; then
      echo "  would run: compile MacLock .frag -> .frag.qsb shaders"
    else
      QSB=$(command -v qsb 2>/dev/null || echo /usr/lib/qt6/bin/qsb)
      if [ -x "$QSB" ]; then
        for frag in "$REPO_DIR"/.config/quickshell/MacLock/*.frag; do
          qsb_file="${frag%.frag}.frag.qsb"
          # (re)build only when missing or older than its source
          if [ ! -f "$qsb_file" ] || [ "$frag" -nt "$qsb_file" ]; then
            if "$QSB" --qt6 "$frag" -o "$qsb_file" 2>/dev/null; then
              say "MacLock: compiled ${qsb_file##*/}"
            else
              warn "MacLock: failed to compile ${frag##*/}"
            fi
          fi
        done
      else
        warn "qsb not found (qt6-shadertools) — MacLock cover-art/glass effects would be missing."
      fi
    fi
  fi
  say "MacLock ready: SUPER + L locks via ~/.config/quickshell/MacLock/lock-via-ipc.sh"
fi

# ── 5. bootloader ────────────────────────────────────────────────────────────
# Limine needs machine-specific values, so we detect them here instead of
# making you hand-edit anything:
#   * root filesystem UUID  -> substituted into limine/limine.conf
#   * ESP mount point       -> where the EFI/limine binaries and config land
if [ "$DRY_RUN" = 0 ] && [ "$LINK_ONLY" = 0 ]; then
  esp=""
  for cand in /boot /efi /boot/efi; do
    [ "$(findmnt -rno FSTYPE "$cand" 2>/dev/null)" = "vfat" ] && {
      esp="$cand"
      break
    }
  done
  [ -n "$esp" ] || esp=$(findmnt -rno TARGET,FSTYPE | awk '$2=="vfat"{print $1; exit}')
  root_uuid=$(findmnt -no UUID /)

  if [ -n "$esp" ] && [ -n "$root_uuid" ]; then
    say "ESP mounted at $esp, root UUID $root_uuid"

    # machine-local limine.conf with this machine's root UUID
    cp "$REPO_DIR/limine/limine.conf" /tmp/limine.conf.new
    sed -i "s|root=UUID=[0-9a-f-]*|root=UUID=$root_uuid|" /tmp/limine.conf.new

    # /etc/kernel/cmdline is the canonical kernel cmdline on Arch
    partuuid=$(findmnt -no PARTUUID /)
    cmd_pat="$root_uuid"
    [ -n "$partuuid" ] && cmd_pat="$cmd_pat|$partuuid"

    if [ ! -f /etc/kernel/cmdline ]; then
      rootfs=$(findmnt -no FSTYPE /)
      flags=""
      [ "$rootfs" = "btrfs" ] && flags="rootflags=subvol=@ "
      sudo mkdir -p /etc/kernel
      printf 'root=UUID=%s %srw rootfstype=%s quiet splash\n' \
        "$root_uuid" "$flags" "$rootfs" | sudo tee /etc/kernel/cmdline >/dev/null
      say "Wrote /etc/kernel/cmdline"
    elif ! grep -qE "$cmd_pat" /etc/kernel/cmdline; then
      # A PARTUUID cmdline is legitimate and survives disk swaps just as
      # well as a UUID one, so only complain if neither is present.
      warn "/etc/kernel/cmdline matches neither the root UUID nor PARTUUID."
      warn "Boot is currently using: $(cat /proc/cmdline)"
    fi

    say "Deploying the themed Limine bootloader"
    if [ -x "$REPO_DIR/install-limine.sh" ]; then
      REPO_LIMINE_CONF=/tmp/limine.conf.new ESP="$esp" "$REPO_DIR/install-limine.sh" ||
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
  • MacLock: SUPER + L locks the session via ~/.config/quickshell/MacLock/lock-via-ipc.sh
    (PAM password check against /etc/pam.d/maclock; runs as its own Quickshell process)

  - Optional, only on Btrfs with a Snapper "root" config. Adds your snapshots to
    the Limine boot menu (the package is already in packages-aur.txt):
    sudo systemctl enable --now limine-snapper-sync.service
EOF
