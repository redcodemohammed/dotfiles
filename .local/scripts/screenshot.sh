#!/usr/bin/env bash

LOG=/tmp/screenshot-debug.log
IMG="/tmp/screenshot-$(date +%s).png"

echo "started $(date)" >> "$LOG"

sleep 0.7

GEOM=$(/usr/bin/slurp 2>> "$LOG")
echo "GEOM=$GEOM" >> "$LOG"

[ -z "$GEOM" ] && exit 1

/usr/bin/grim -g "$GEOM" "$IMG" 2>> "$LOG"
/usr/bin/satty --filename "$IMG" 2>> "$LOG"
