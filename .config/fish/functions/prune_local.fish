function prune_local
  set branch $argv[1]

  # If no branch is provided, check for dev or development, fallback to main
  if test -z "$branch"
    if git show-ref --verify --quiet refs/heads/dev
      set branch dev
    else if git show-ref --verify --quiet refs/heads/development
      set branch development
    else
      set branch main
    end
  end

  git checkout $branch
  git pull
  git fetch --prune
  git remote prune origin
  git branch -vv | awk '/: gone]/{print $1}' | xargs -r git branch -D
end

