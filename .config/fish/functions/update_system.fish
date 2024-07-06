function update_system
    yay -Syu --noconfirm
    if test $status -eq 0
        send_telegram_notification "✅ System Update Complete" "Your system has been successfully updated." "Sent from my Fish script"
    else
        send_telegram_notification "❗ System Update Failed" "Failed to update your system." "Sent from my Fish script"
    end
end

# Call the wrapper function
update_system
