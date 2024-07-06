function send_telegram_notification
    # Arguments: notification_title, notification_body, notification_footer
    set notification_title $argv[1]
    set notification_body $argv[2]
    set notification_footer $argv[3]

    # Load environment variables
    load_env

    # Telegram Bot API URL and token
    set tg_api_url "https://api.telegram.org/bot$NOTIFICATIONS_TG_BOT/sendMessage"
    set chat_id "472938964"

    # Get current time
    set current_time (date "+%Y-%m-%d %H:%M:%S")

    # Get memory usage (RSS - Resident Set Size)
    set memory_usage (ps -o rss= -p $fish_pid | awk '{print $1/1024 " MB"}')

    # Complete message with time and memory usage
    set message "🚨 $notification_title 🚨
$notification_body
$notification_footer

------------------
Time: $current_time
Memory Usage: $memory_usage
"

    # Send the notification
    set response (curl -s -X POST $tg_api_url -d chat_id=$chat_id -d text="$message" -d parse_mode="Markdown")

    # Error handling
    if echo $response | grep -q '"ok":true'
        echo "Notification sent successfully: $message"
    else
        echo "Failed to send notification: $response"
    end
end
