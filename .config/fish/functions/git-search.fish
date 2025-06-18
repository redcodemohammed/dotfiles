function git-search -d "Search git repository history for commits containing a specific keyword"
    # Set default values
    set -l search_messages false
    set -l search_content false
    set -l all_branches ""
    set -l ignore_case ""
    set -l show_patch ""
    set -l format "%h %ad %an: %s"
    set -l search_term ""

    # Parse arguments using argparse
    argparse -n git-search \
        'm/message' \
        'c/content' \
        'a/all' \
        'i/ignore-case' \
        'p/patch' \
        'f/format=' \
        'h/help' \
        -- $argv
    or return

    # Show help if requested
    if set -q _flag_help
        _git_search_help
        return 0
    end

    # Get search term (remaining arguments after parsing)
    if test (count $argv) -eq 0
        echo "Error: No search term provided." >&2
        _git_search_help
        return 1
    end

    set search_term $argv[1]

    # Set flags based on parsed arguments
    if set -q _flag_message
        set search_messages true
    end

    if set -q _flag_content
        set search_content true
    end

    if set -q _flag_all
        set all_branches "--all"
    end

    if set -q _flag_ignore_case
        set ignore_case "--regexp-ignore-case"
    end

    if set -q _flag_patch
        set show_patch "-p"
    end

    if set -q _flag_format
        set format $_flag_format
    end

    # If neither search type is specified, search both
    if test $search_messages = false -a $search_content = false
        set search_messages true
        set search_content true
    end

    echo "Searching git history for: '$search_term'"
    echo "----------------------------------------"

    # Search in commit messages
    if test $search_messages = true
        echo "Commits with matching messages:"
        echo "------------------------------"
        git log $all_branches $ignore_case --grep="$search_term" --date=short --pretty=format:"$format"
        echo ""
    end

    # Search in commit content
    if test $search_content = true
        echo "Commits with matching content:"
        echo "-----------------------------"
        git log $all_branches $show_patch -S"$search_term" $ignore_case --date=short --pretty=format:"$format"
        echo ""
    end
end

function _git_search_help -d "Display help for git-search function"
    echo "Usage: git-search [options] <search-term>"
    echo ""
    echo "Search git repository history for commits containing a specific keyword."
    echo ""
    echo "Options:"
    echo "  -m, --message      Search only in commit messages"
    echo "  -c, --content      Search only in commit content/code changes"
    echo "  -a, --all          Search in all branches (default: current branch only)"
    echo "  -i, --ignore-case  Perform case-insensitive search"
    echo "  -p, --patch        Show the patch (diff) with the search results"
    echo "  -f, --format       Custom format for output (default: '%h %ad %an: %s')"
    echo "  -h, --help         Display this help message"
    echo ""
    echo "Examples:"
    echo '  git-search "function"                  # Search for "function" in code changes'
    echo '  git-search -m "fix bug"                # Search for "fix bug" in commit messages'
    echo '  git-search -c -a -i "api"              # Search for "api" (case insensitive) in all branches\' code'
    echo '  git-search -m -p "refactor"            # Search for "refactor" in messages and show patches'
    echo '  git-search -f "%h %an %s" "database"   # Search with custom format'
end
