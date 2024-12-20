if status is-interactive
 atuin init fish --disable-up-arrow | source
end

# set alias
alias ex 'eza --long --header --git --icons'
alias tree 'eza --header -a --tree -I .git  --icons'
alias cat 'bat'
alias ls 'ex'

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

#dircolors
eval (dircolors -c ~/.dircolors)

# bun
set --export BUN_INSTALL "$HOME/.bun"
set --export PATH $BUN_INSTALL/bin $PATH
