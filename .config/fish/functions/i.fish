function i
    set package $argv[1]
    if test -z "$package"
        echo "Error: No package name provided"
        send_telegram_notification "❗ Package Installation Failed" "No package name provided." "Sent from my Fish script"
        return 1
    end

    yay -S --noconfirm $package
    if test $status -eq 0
        send_telegram_notification "✅ Package Installed" "The package '$package' has been successfully installed." "Sent from my Fish script"
    else
        send_telegram_notification "❗ Package Installation Failed" "Failed to install the package '$package'." "Sent from my Fish script"
    end
end
