#!/bin/bash

# Look for an existing Alacritty window
WIN_ID=$(xdotool search --onlyvisible --class Alacritty | head -n 1)

if [ -n "$WIN_ID" ]; then
    # Focus the existing window
    xdotool windowactivate "$WIN_ID"
else
    # Launch Alacritty with Tmux
    alacritty -e tmux
fi

