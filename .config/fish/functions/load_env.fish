function load_env
    for line in (cat $HOME/dotfiles/.env)
        set -l key_value (string split "=" $line)
        set -xg $key_value[1] $key_value[2]
    end
end
