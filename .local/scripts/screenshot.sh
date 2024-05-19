#!/usr/bin/env bash

export G="$(slurp -d)"
export IPATH="$(xdg-user-dir PICTURES)/Screenshots/$(date +'%s_grim.png')"

grim -g $G $IPATH
