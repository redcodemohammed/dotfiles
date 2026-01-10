#!/bin/bash
SDK_PATH="/home/mohammed/Android/Sdk/emulator"

avd_list=$("$SDK_PATH"/emulator -list-avds)

if command -v vicinae &>/dev/null; then
    chosen_avd=$(echo "$avd_list" | vicinae dmenu --placeholder "Select Emulator")
else
    chosen_avd=$(echo "$avd_list" | fzf --prompt="Select Emulator: ")
fi

if [ -n "$chosen_avd" ]; then
    prime-run "$SDK_PATH"/emulator @"$chosen_avd" &
fi
