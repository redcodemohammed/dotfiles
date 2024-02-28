function f
    # Use 'fd' to find files and pipe the output to 'fzf-tmux' for selection
    set selected_file (fd --type f --hidden --exclude .git | fzf-tmux -p --reverse)

    # Check if a file was selected (non-empty output) and the exit status is 0
    if test -z "$selected_file" -o $status -ne 0
        echo "No file selected, exiting."
        return 1
    end

    # Open the selected file in the editor
    $EDITOR $selected_file
end
