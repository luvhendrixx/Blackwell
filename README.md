# dotfiles

Arch Linux + Hyprland (Lua config) + a Quickshell macOS-style shell.
Everything in this repo is the single source of truth: `~/.config/*` and
`~/.zshrc` are symlinks into `dotfiles/`, so editing either side edits the
same file.

```
.
├── .config/                 # symlinked into ~/.config
│   ├── hypr/                # Hyprland (hyprland.lua, keybinds.lua, look.lua, rules.lua, scripts/)
│   ├── quickshell/          # shell.qml, Bar.qml, notifications, panels, wallpapers
│   ├── 43pr/                # theme engine (light/dark toggle + theming)
│   ├── nvim/                # LazyVim starter + keymaps
│   ├── ghostty/ cava/ btop/ rofi/ fastfetch/ superfile/ matugen/
│   ├── gtk-3.0/ gtk-4.0/    # cursor + icon theme settings
│   └── ...
├── home/.zshrc              # symlinked to ~/.zshrc (starship, zoxide, eza, plugins)
├── wallpapers/              # symlinked to ~/Pictures/Wallpapers (wallpaper picker)
├── limine/                  # macOS-style bootloader theme (limine.conf + wallpaper.jpg)
├── packages-repo.txt        # official-repo packages
├── packages-aur.txt         # AUR packages
├── install.sh               # packages + symlinks + post-install
├── install-limine.sh        # copy the bootloader theme to the ESP
├── update.sh                # pull upstream changes
└── README.md
```

## Install (new machine)

```bash
git clone git@github.com:luvhendrixx/dotfiles.git ~/dotfiles
cd ~/dotfiles
./install.sh
```

That single command: installs packages (repo + AUR), links every config,
sets up keyd / cursor / icon defaults, **auto-detects your ESP mount point and
root UUID**, deploys the themed Limine bootloader, registers it in firmware, and
generates a boot entry for the installed kernel. Then reboot.

Useful flags: `./install.sh --dry-run`, `./install.sh --link-only`.

## Highlights

- **Hyprland** configured in Lua (`hyprland.lua` + split-out modules), dwindle layout,
  dark-cream active window border, blur/vibrancy.
- **Quickshell shell** — macOS-style bar (Apple logo, focused-app name, File/Edit/
  View/Window/Help menus, translucent liquid-glass strip), notifications, power menu,
  settings, wallpaper picker.
- **Universal clipboard** — `SUPER+C` / `SUPER+V` use key-state injection with a
  terminal-aware `CTRL+SHIFT` variant, matching Omarchy's approach.
- **omasnap** — `PRINT` screenshot/annotation overlay; autosave disabled (copy first,
  save on demand).
- **Right Shift = Compose** via `keyd`, so xkb's missing `compose:rshift` works.
- **Scratchpad** — `SUPER+S` toggle, `SUPER+ALT+S` send window; `SUPER+\`` toggles a
  dedicated floating terminal.
- **Brightness/volume OSDs** — brightness OSD mirrors the volume flyout.
- **LazyVim** with `Ctrl+E` end-of-line, `Ctrl+W` new line below, `Ctrl+A` select all.
- **Housekeeping** — `paccache-hook` prunes the pacman cache, `pacman-orphans.timer`
  removes orphans weekly, `snap-pac` snapshots before/after transactions.

## Keymap (the essentials)

| Keys | Action |
| --- | --- |
| `SUPER + T` / `SUPER + Return` | Ghostty |
| `SUPER + Q` / `SUPER + W` | Close window |
| `SUPER + E` / `SUPER + SHIFT + F` | Files (Nautilus) |
| `SUPER + B` | Browser (Zen) |
| `SUPER + Space` | App launcher (rofi) |
| `SUPER + D` | Wallpaper picker |
| `SUPER + S` / `SUPER + ALT + S` | Scratchpad toggle / send window |
| `SUPER + \`` | Floating terminal toggle |
| `SUPER + ,` | Dismiss last notification |
| `SUPER + .` | Emoji picker (copies + types) |
| `SUPER + C` / `SUPER + V` | Universal copy / paste |
| `SUPER + I` / `SUPER + N` | Settings / notifications |
| `SUPER + F` / `SUPER + O` | Fullscreen / opacity |
| `SUPER + H J K L` / arrows | Focus window |
| `SUPER + SHIFT + H J K L` / arrows | Move window |
| `SUPER + CTRL + H J K L` | Resize window |
| `SUPER + 1…0` / `SUPER + SHIFT + 1…0` | Switch / move to workspace |
| `SUPER + /` / `SUPER + ALT + /` | Zoom in / out |
| `SUPER + SHIFT + X` | Quickshell wheel launcher |
| `SUPER + SHIFT + E` | Exit session |
| `SUPER + Tab` | Lock screen |
| `SUPER + SHIFT + GRAVE` | Power menu |
| `PRINT` | omasnap screenshot overlay |
| Volume / Brightness keys | wpctl / brightnessctl (+ OSD) |
| `Right Shift` | Compose (via keyd) |

Full list: the Apple logo in the bar (or `~/.config/hypr/scripts/keymaps.sh`)
opens a searchable rofi cheat sheet generated from `keybinds.lua`.

## Bootloader (Limine)

Themed macOS-style Limine menu (wallpaper + interface colours) lives in `limine/`.
`./install-limine.sh` deploys the EFI binary, the config and the wallpaper, and
registers a firmware boot entry (keeping the standard `EFI/BOOT` fallback path).

### Automatic kernel entries

`install.sh` installs `limine-mkinitcpio-hook-git` (it's in `packages-aur.txt`)
and runs the one-time setup:

```bash
sudo limine-install       # deploy + register the managed Limine EFI
sudo limine-mkinitcpio    # build a UKI for the installed kernel + write its entry
```

After that, every `pacman -S linux*` automatically adds/removes its Limine entry
(pacman hooks: `80-limine-efi-deploy`, `90-limine-mkinitcpio-install/remove`), and
`kernel-modules-hook` keeps the previous kernel if an upgrade fails.
Config lives in `/etc/default/limine` (`ESP_PATH`, `ENABLE_UKI`, `FIND_BOOTLOADERS`).

The tool manages `$ESP/limine.conf` and preserves non-entry lines, so the wallpaper
and `interface_*` colours survive regeneration. It also keeps a timestamped
`limine.conf.old` backup. Keep exactly **one** `limine.conf` on the ESP (at its
root) — a second copy under `EFI/BOOT/` goes stale.

## Notes

- The Limine config uses `root=UUID=` (filesystem, not disk) so it survives disk
  swaps. On a new machine run `findmnt -no UUID /` and update that one line in
  `limine/limine.conf` before running `./install-limine.sh`. (i think i fixed it tho, so its safe now)
- Waybar was replaced by the Quickshell bar; there is no waybar config here.
- Theme toggle: `SUPER + L` (43pr engine, light/dark).
