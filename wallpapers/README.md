# Wallpapers

Every image here is used by the wallpaper picker (`SUPER + D`), which reads
`$HOME/Pictures/Wallpapers/` — that path is a symlink to this directory, so
dropping a new image in here makes it show up in the picker immediately.

Supported extensions: `.png`, `.jpg`, `.jpeg`, `.webp`.

## Using the picker

The strip opens on the wallpaper that is currently on the desktop (`CURRENT`).

| Action | What it does |
| --- | --- |
| `←` / `→` | Browse, one wallpaper at a time |
| Mouse wheel | Browse |
| Hover a preview | Highlight it, then click to apply |
| `Enter` / `Space` / click | Apply and close |
| `Esc` / `W` / `Q` | Close without changing anything |

Applying a wallpaper also runs the theme generator (`43pr`), so the desktop
colours follow the new image.

## Preview cache

The picker never decodes full-size images if it can avoid it. Thumbnails are
written to `$HOME/.cache/quickshell/thumbs/<name>.thumb.jpg` and are reused
until the source image is newer.

- Thumbnails are built at login by `hypr/scripts/wallpaper-init.sh`, and again
  whenever the picker opens (a warm run is just a directory scan).
- New images preview from the original immediately while their thumbnail is
  generated in the background, so the picker never waits on the cache.
- `vipsthumbnail` (libvips) is used when installed: it is about 2–3× faster
  than ImageMagick and produces much smaller JPEGs. ImageMagick is the
  fallback.
