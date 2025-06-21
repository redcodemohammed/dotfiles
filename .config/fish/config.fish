if status is-interactive
    atuin init fish --disable-up-arrow | source
end

# set alias
alias ex 'eza --long --header --git --icons'
alias tree 'eza --header -a --tree --git-ignore  --icons'
alias cat 'bat'
alias ls 'ex'
alias logged_in_at "last | grep 'system boot' | sed -E 's/( [A-Za-z]{3})[ ]+([0-9]) /\1 0\2 /' | grep (date +'%b %d') | tail -n 1 | cut -d ' ' -f 13"
alias v "vscli recent"
alias vo "vscli open"
set -g fish_greeting

# set defaults
set EDITOR nvim
set VISUAL code
# init zoxide
zoxide init fish | source


fish_add_path /home/mohammed/.spicetify
set -gx VOLTA_HOME "$HOME/.volta"
set -gx PATH "$VOLTA_HOME/bin" $PATH

# pnpm
set -gx PNPM_HOME "/home/mohammed/.local/share/pnpm"
if not string match -q -- $PNPM_HOME $PATH
  set -gx PATH "$PNPM_HOME" $PATH
end
# pnpm end

# android
set -x ANDROID_HOME $HOME/Android/Sdk
set -x PATH $ANDROID_HOME/emulator $PATH
set -x PATH $ANDROID_HOME/tools $PATH
set -x PATH $ANDROID_HOME/tools/bin $PATH
set -x PATH $ANDROID_HOME/platform-tools $PATH
# android end

#other
set -x CHROME_EXECUTABLE /usr/bin/google-chrome-stable
#other end

#dircolors
eval (dircolors -c ~/.dircolors)

# bun
set --export BUN_INSTALL "$HOME/.bun"
set --export PATH $BUN_INSTALL/bin $PATH


function load_env_vars --description "Load variables from a .env file"
    set lines (cat $argv | string split -n '\n' | string match -vre '^\s*#' | string match -vre '^\s*$')
    for line in $lines
        set arr (string split -n -m 1 = $line)
        if test (count $arr) -ne 2
            continue
        end
        set -gx $arr[1] $arr[2]
    end
end

load_env_vars ~/dotfiles/.env
