if not set -q SSH_AUTH_SOCK
    eval (ssh-agent -c | sed 's/^echo/#echo/')
end
