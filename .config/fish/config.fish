if status is-interactive
    # Commands to run in interactive sessions can go here
end

# set alias
alias ls 'exa'
alias cat 'bat'

# disable greeting
set -g fish_greeting

# set defaults
set EDITOR nvim
set VISUAL code
# init zoxide
zoxide init fish | source

