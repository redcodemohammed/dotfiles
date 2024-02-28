function c
    # Initialize maxdepth
    set maxdepth 1

    # Check for '-v' flag
    set use_vscode false
    for arg in $argv
        switch "$arg"
            case '-v'
                set use_vscode true
            case '*'
                # Assume any other argument is the folder name
                set folder_name $arg
        end
    end

    # If no folder name is provided, use fzf-tmux to select a folder from ~/dotfiles/.config
    if test -z "$folder_name"
        set folder_name (fd --type d --hidden --exclude .git --base-directory ~/dotfiles/.config --max-depth $maxdepth | fzf-tmux -p --reverse)

        # Check if a folder was selected
        if test -z "$folder_name"
            echo "No folder selected, exiting."
            return 1
        end
    end

    # Open the selected folder in the appropriate editor
    if test $use_vscode = true
        code ~/dotfiles/.config/$folder_name
    else
        nvim ~/dotfiles/.config/$folder_name
    end
end
