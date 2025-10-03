function rofi-emulator --description "Launch Android emulator using rofi"
    # Check if emulator command exists
    if not command -v emulator >/dev/null 2>&1
        rofi -e "Android emulator not found in PATH"
        return 1
    end
    
    # Get AVD list
    set avd_list (emulator -list-avds)
    
    if test -z "$avd_list"
        rofi -e "No Android emulators found"
        return 1
    end
    
    # Show rofi menu - pass each AVD as separate argument
    set chosen_avd (printf '%s\n' $avd_list | rofi -normal-window -dmenu -i -p "🤖 Launch Emulator:")
    
    # Launch if selection made
    if test -n "$chosen_avd"
        # Optional: show notification
        notify-send "Starting emulator" "$chosen_avd" 2>/dev/null
        
        # Launch emulator in background
        prime-run emulator @"$chosen_avd" >/dev/null 2>&1 &
    end
end
