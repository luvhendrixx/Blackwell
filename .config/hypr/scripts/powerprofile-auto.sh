#!/bin/bash
# Auto power profiles: performance on AC, balanced on battery,
# power-saver when battery is critically low.
AC_PATH=/sys/class/power_supply/AC/online
for bat in /sys/class/power_supply/BAT*/capacity; do
    BAT_PATH=$bat
done

while true; do
    ac=$(cat "$AC_PATH" 2>/dev/null || echo 1)
    pct=$(cat "$BAT_PATH" 2>/dev/null || echo 100)
    cur=$(powerprofilesctl get 2>/dev/null)
    if [ "$ac" = "1" ]; then
        want=performance
    elif [ "$pct" -le 10 ]; then
        want=power-saver
    else
        want=balanced
    fi
    [ "$cur" != "$want" ] && powerprofilesctl set "$want" 2>/dev/null
    sleep 30
done
