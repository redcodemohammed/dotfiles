#!/usr/bin/env bash
# Now-playing widget for the second tmux status line. Based on tokyo-night-tmux's
# music-tmux-statusbar.sh, minus its hard 25-char title limit: the title uses whatever
# room is left on the line after the path, and is only cut (with …) if it would run into it.
#
# Usage: now-playing.sh <client_width> <pane_current_path>

WIDTH=${1:-120}
PANE_PATH=${2:-}

ACCENT_COLOR="#7aa2f7"   # Tokyo Night blue
TEXT_ON_ACCENT="#1A1B26" # dark text on the blue progress fill
TIME_COLOR="#414868"
# Unfilled parts use bg=default, which the status line sets to its own shade via push-default

command -v playerctl >/dev/null || exit 0

# Title goes last so the final read variable keeps it whole, even if it contains ';'
FORMAT="{{status}};{{mpris:length}};{{position}};{{playerName}};{{title}}"
PLAYER=$(playerctl -a metadata --format "$FORMAT" 2>/dev/null | grep -m1 '^Playing;')
[[ -z $PLAYER ]] && PLAYER=$(playerctl -a metadata --format "$FORMAT" 2>/dev/null | grep -m1 '^Paused;')
[[ -z $PLAYER ]] && exit 0

IFS=';' read -r STATUS LENGTH POSITION _ TITLE <<<"$PLAYER"
[[ -z $TITLE ]] && exit 0

# microseconds -> seconds
DURATION=$((${LENGTH:-0} / 1000000))
POSITION=$((${POSITION:-0} / 1000000))

if ((DURATION > 0 && DURATION < 3600)); then
  TIME="[$(date -d@"$POSITION" -u +%M:%S) / $(date -d@"$DURATION" -u +%M:%S)]"
else
  TIME="[--:--]"
fi

if [[ $STATUS == "Playing" ]]; then
  PLAY_STATE="░ "
else
  PLAY_STATE="░ 󰏤"
fi

# Room left for the title: line width, minus the path widget on the left ("░  " + path + gap),
# minus the rest of this widget (play state, spaces, time)
DISPLAY_PATH="${PANE_PATH/#$HOME/\~}"
PATH_LEN=$((${#DISPLAY_PATH} + 8))
FIXED_LEN=$((${#PLAY_STATE} + 1 + 1 + ${#TIME} + 1))
MAX_TITLE=$((WIDTH - PATH_LEN - FIXED_LEN))
((MAX_TITLE < 10)) && MAX_TITLE=10

if ((${#TITLE} > MAX_TITLE)); then
  TITLE="${TITLE:0:MAX_TITLE-1}"
  TITLE="${TITLE%"${TITLE##*[![:space:]]}"}…" # drop trailing spaces before the ellipsis
fi

OUTPUT="$PLAY_STATE $TITLE"
OUT="$OUTPUT $TIME "
TIME_INDEX=$((${#OUTPUT} + 1))

# Progress bar: the first PERCENT% of the widget gets the blue fill
if ((DURATION > 0)); then
  PERCENT=$((POSITION * 100 / DURATION))
else
  PERCENT=0
fi
PROGRESS=$((${#OUT} * PERCENT / 100))

if ((PROGRESS <= TIME_INDEX)); then
  echo "#[nobold,fg=$TEXT_ON_ACCENT,bg=$ACCENT_COLOR]${OUTPUT:0:PROGRESS}#[fg=$ACCENT_COLOR,bg=default]${OUTPUT:PROGRESS} #[fg=$TIME_COLOR,bg=default]$TIME "
else
  DIFF=$((PROGRESS - TIME_INDEX))
  echo "#[nobold,fg=$TEXT_ON_ACCENT,bg=$ACCENT_COLOR]$OUTPUT #[fg=$TEXT_ON_ACCENT,bg=$ACCENT_COLOR]${OUT:TIME_INDEX:DIFF}#[fg=$TIME_COLOR,bg=default]${OUT:PROGRESS}"
fi
