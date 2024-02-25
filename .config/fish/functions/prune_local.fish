function prune_local
  git checkout main
  git pull
  git fetch --prune
  git remote prune origin
  git branch -vv | awk '/: gone]/{print $1}' | xargs -r git branch -d
end

