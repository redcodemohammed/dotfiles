#!/bin/bash
# Save as ~/bin/rofi-emulator or similar

# Get list of AVDs and let user choose
chosen_avd=$(/home/mohammed/Android/Sdk/emulator/emulator -list-avds | rofi  -dmenu -p "Select Emulator:")

# Launch the selected emulator if one was chosen
if [ -n "$chosen_avd" ]; then
    prime-run /home/mohammed/Android/Sdk/emulator/emulator @"$chosen_avd" &
fi
