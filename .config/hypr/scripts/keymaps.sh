#!/bin/bash
# Cheat-sheet of our Hyprland keybinds from keybinds.lua via rofi (omarchy-style).
CONF="$HOME/.config/hypr/keybinds.lua"
TMP=/tmp/harry-keymaps.tsv

awk '
/^[[:space:]]*hl\.bind\(/ {
    line = $0
    keys = line
    sub(/^[[:space:]]*hl\.bind\(/, "", keys)
    sub(/,.*/, "", keys)
    gsub(/mainMod/, "SUPER", keys)
    gsub(/"/, "", keys)
    gsub(/[[:space:]]*\.\.[[:space:]]*/, "", keys)
    gsub(/\+/, "+", keys)
    gsub(/[[:space:]]+/, " ", keys)
    gsub(/^ | $/, "", keys)

    desc = ""
    if (match(line, /--[[:space:]]*(.*)$/, m)) desc = m[1]

    cmd = ""
    if (match(line, /exec_cmd\("([^"]*)"\)/, m)) cmd = m[1]
    if (match(line, /exec_cmd\(([a-zA-Z_]+)\)/, m)) cmd = m[1]

    if (desc == "") desc = cmd
    if (desc == "") desc = "(custom)"
    print keys "\t" desc "\t" cmd
}' "$CONF" > "$TMP"

sel=$(cut -f1,2 "$TMP" | sed 's/\t/ — /' | rofi -dmenu -p "Keymaps" -i -width 50)
[ -z "$sel" ] && exit 0
key=${sel%% —*}
key=${key%"${key##*[![:space:]]}"}
cmd=$(awk -F '\t' -v k="$key" '$1 == k { print $3; exit }' "$TMP")
if [ -n "$cmd" ]; then
    case "$cmd" in
        rofi*|qs\ -n*) bash -c "$cmd" & ;;
        terminal) ghostty & ;;
        fileManager) nautilus & ;;
        browser) zen-browser & ;;
        *) hyprctl dispatch "exec $cmd" ;;
    esac
else
    notify-send "Keymap" "$sel"
fi
