# Wrapper function to download a file using wget
function download_file
    set url $argv[1]
    # Use $HOME environment variable to specify the download directory
    set output_file "$HOME/Downloads/$argv[2]"
    if test -z "$url" -o -z "$argv[2]"
        echo "Error: URL and output file name must be provided"
        send_telegram_notification "❗ Download Failed" "URL and output file name must be provided." "Sent from my Fish"
        return 1
    end

    wget -O $output_file $url
    if test $status -eq 0
        send_telegram_notification "✅ Download Complete" "File downloaded from '$url' to '$output_file'." "Sent from my Fish"
    else
        send_telegram_notification "❗ Download Failed" "Failed to download file from '$url'." "Sent from my Fish"
    end
end
