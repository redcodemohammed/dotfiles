if status is-interactive
    
end

# set alias
alias ex 'exa --long --header --git'
alias tree 'exa --header -a --tree -I .git'
alias cat 'bat'

# disable greeting
set -g fish_greeting

# set defaults
set EDITOR nvim
set VISUAL code
# init zoxide
zoxide init fish | source


fish_add_path /home/mohammed/.spicetify
set -gx VOLTA_HOME "$HOME/.volta"
set -gx PATH "$VOLTA_HOME/bin" $PATH
