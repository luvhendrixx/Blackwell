#!/usr/bin/env bash
# Fast thumbnail cache for the wallpaper picker (SUPER + D).
#
#   cache.sh          # generate missing / out-of-date previews
#   cache.sh warm     # same (kept for readability at call sites)
#
# A thumbnail lives at <cache>/<file name>.thumb.jpg. Existing thumbs are
# reused until the source image is newer than them, so opening the picker a
# second time needs no image decoding at all.
#
# vipsthumbnail (libvips) is preferred: it is roughly 2-3x faster than
# ImageMagick and writes much smaller JPEGs (a 4 MB PNG preview drops from
# ~800 KB to ~70 KB). ImageMagick is kept as a fallback.
set -uo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG="$DIR/config.json"

cfg() { jq -r "$1 // empty" "$CONFIG" 2>/dev/null; }

expand_home() {
    local path="$1"

    if [[ "$path" == '$HOME' ]]; then
        printf '%s\n' "$HOME"
    elif [[ "$path" == '$HOME/'* ]]; then
        printf '%s/%s\n' "$HOME" "${path#'$HOME/'}"
    else
        printf '%s\n' "$path"
    fi
}

wallpaper_path=$(expand_home "$(cfg .wallpaper_path)")
cache_path=$(expand_home "$(cfg .cache_path)")
size=$(cfg .thumbnail_size); size=${size:-1280}
quality=$(cfg .thumbnail_quality); quality=${quality:-82}
batch=$(cfg .cache_batch_size); batch=${batch:-4}

[[ -n "$wallpaper_path" && -d "$wallpaper_path" ]] || exit 0
[[ -n "$cache_path" ]] || exit 0
mkdir -p "$cache_path" || exit 1

# Only one warm-up at a time. Pressing SUPER+D while a previous run is still
# working (or while the picker warmed its own cache on open) is a no-op.
if command -v flock >/dev/null 2>&1; then
    exec 9>"$cache_path/.warm.lock"
    flock -n 9 || exit 0
fi

# Don't start 20 encoders on a 4-thread laptop.
cpus=$(nproc 2>/dev/null || echo 4)
(( batch > cpus * 2 )) && batch=$(( cpus * 2 ))
(( batch < 1 )) && batch=1

thumb_for() { printf '%s/%s.thumb.jpg' "$cache_path" "$(basename "$1")"; }

make_thumb() {
    local src="$1" out="$2" tmp
    tmp="$out.$$.$RANDOM.tmp.jpg"

    if command -v vipsthumbnail >/dev/null 2>&1; then
        # libvips prints a warning when an optional module (openslide) is
        # missing; that is harmless and would spam the picker's log.
        vipsthumbnail "$src" --size="${size}x${size}" \
            --output="${tmp}[Q=${quality},strip]" 2>/dev/null
    fi

    # vips unavailable, failed, or produced nothing -> ImageMagick fallback.
    if [[ ! -s "$tmp" ]] && command -v magick >/dev/null 2>&1; then
        magick "$src" -auto-orient -thumbnail "${size}x${size}>" \
            -strip -quality "$quality" "jpg:$tmp" 2>/dev/null
    fi

    if [[ -s "$tmp" ]]; then
        # Atomic replace so the picker never reads a half-written JPEG.
        mv -f "$tmp" "$out"
    else
        rm -f "$tmp"
        printf 'cache.sh: could not create a thumbnail for %s\n' "$src" >&2
    fi
}

# Newest images first: a freshly downloaded wallpaper gets its preview
# before the rest of the library finishes.
while IFS= read -r -d '' img; do
    out=$(thumb_for "$img")
    [[ -f "$out" && "$out" -nt "$img" ]] && continue

    while (( $(jobs -rp | wc -l) >= batch )); do
        wait -n || true
    done
    make_thumb "$img" "$out" &
done < <(find -L "$wallpaper_path" -maxdepth 1 -type f \
            \( -iname '*.jpg' -o -iname '*.jpeg' \
               -o -iname '*.png' -o -iname '*.webp' \) \
            -printf '%T@ %p\0' 2>/dev/null |
         sort -zrn |
         cut -z -d' ' -f2-)
wait

# Remove previews whose source was renamed or deleted.
find "$cache_path" -maxdepth 1 -type f -name '*.thumb.jpg' -print0 2>/dev/null |
while IFS= read -r -d '' thumb; do
    name=$(basename "$thumb")
    src="$wallpaper_path/${name%.thumb.jpg}"
    [[ -e "$src" ]] || rm -f "$thumb"
done
