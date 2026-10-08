#!/usr/bin/env bash
# Pick a wallpaper on first boot.
#
# awww-daemon draws nothing until it is told what to show, so a fresh machine
# would otherwise boot to a black background. Once the user has picked one
# (SUPER+D -> hyprquickpaper), awww records it in its own state file and we
# leave that choice alone on subsequent boots.
set -uo pipefail

WALLS="$HOME/Pictures/Wallpapers"

# awwa's saved state: leave an existing selection untouched.
if [ -f "$HOME/.config/awww/state.json" ] && [ -s "$HOME/.config/awww/state.json" ]; then
    exit 0
fi

[ -d "$WALLS" ] || exit 0

img=$(find "$WALLS" -maxdepth 1 -type f \
        \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' \) \
        2>/dev/null | shuf -n 1)
[ -n "$img" ] || exit 0

# Reuse the wallpaper picker's command so the theme generator runs too.
exec "$HOME/.config/quickshell/hyprquickpaper/commands.sh" "$img"