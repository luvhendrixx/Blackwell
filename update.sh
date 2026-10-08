#!/usr/bin/env bash
# Pull upstream changes for this dotfiles repo.
set -euo pipefail
cd "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

git pull --ff-only

echo
echo "Configs are symlinked, so changes are live immediately."
echo "Reload Hyprland with: hyprctl reload"
echo "Restart the shell with: pkill -x qs && qs &"
