#!/bin/bash
# Toggle a floating ghostty scratchpad (SUPER + `)
if hyprctl clients -j | grep -q '"class": "magic-term"'; then
    hyprctl dispatch togglespecialworkspace magic-term
else
    hyprctl dispatch exec "[workspace special:magic-term silent; float; size 900 600; move 50% 50%] ghostty --class=magic-term"
fi
