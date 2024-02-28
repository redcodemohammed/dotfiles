function wifi_connect
    # Rescan WiFi networks
    nmcli device wifi rescan
    # sleep 10
    # List WiFi networks and select one using fzf-tmux
    set ssid (nmcli --get-values IN-USE,SSID,SECURITY,BARS device wifi list | fzf-tmux)

    # Check if a network was selected
    if test -z "$ssid"
        echo "No network selected."
        return 1
    end

    # Extract only the SSID from the selection
    set ssid (echo $ssid | awk '{print $2}')

    # Check if the network requires a password
    if nmcli --fields SECURITY device wifi | grep --quiet "\*" 
        # Prompt for the password
        echo "Enter password for $ssid:"
        read -s password

        # Connect to the WiFi network with the password
        nmcli device wifi connect "$ssid" password "$password"
    else
        # Connect to the WiFi network without a password
        nmcli device wifi connect "$ssid"
    end
end

