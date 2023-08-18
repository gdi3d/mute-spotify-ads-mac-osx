#!/usr/bin/env bash

set -Eeou pipefail
CURRENT_VER=23

# check if version is up-to-date
INSTALLATION_DIR="$(dirname "$0")"
URL=https://raw.githubusercontent.com/gdi3d/mute-spotify-ads-mac-osx/master/NoAdsSpotify.sh
FILENAME="$(basename "$URL")"
TMP_DIR="$(mktemp -d)"

function sigint_handler {
  cat <<EOM

Thank you for using $FILENAME
EOM
  exit 0
}

function err_handler {
  cat <<EOM

⛔️ Oops, something happend. Please open a new issue at https://github.com/gdi3d/mute-spotify-ads-mac-osx/issues/new
EOM
}

trap sigint_handler SIGINT
trap err_handler ERR

# check that curl is present in the system
if ! [ -x "$(command -v curl)" ]; then
  echo "curl command is not present. Auto Update function is disabled"
else
  curl -Ls "$URL" -o "${TMP_DIR}/${FILENAME}"
  LATEST_VER=$(sed -En 's/^CURRENT_VER=(.*)$/\1/p' "${TMP_DIR}/${FILENAME}")
  if [ "${CURRENT_VER:-}" != "${LATEST_VER:-}" ]; then
    read -rn 1 -p "A new version is available, would you like to update? [y/N]" update
    if [ "${update:-y}" == "y" ]; then
      mv "${TMP_DIR}/${FILENAME}" "$INSTALLATION_DIR"
      echo "Update finished"
      exec "$0"
    else
      echo
      echo "Update skipped"
    fi
  fi
fi

rendertimer() {
  # convert seconds to Days, Hours, Minutes, Seconds
  # thanks to Nikolay Sidorov and https://www.shellscript.sh/tips/hms/
  local parts seconds D H M S D_TAG H_TAG M_TAG S_TAG
  seconds=${1:-0}
  # all days
  D=$((seconds / 60 / 60 / 24))
  # all hours
  H=$((seconds / 60 / 60))
  H=$((H % 24))
  # all minutes
  M=$((seconds / 60))
  M=$((M % 60))
  # all seconds
  S=$((seconds % 60))

  # set up "x day(s), x hour(s), x minute(s) and x second(s)" language
  [ "$D" -eq "1" ] && D_TAG="day" || D_TAG="days"
  [ "$H" -eq "1" ] && H_TAG="hour" || H_TAG="hours"
  [ "$M" -eq "1" ] && M_TAG="min" || M_TAG="mins"
  [ "$S" -eq "1" ] && S_TAG="sec" || S_TAG="secs"

  # put parts from above that exist into an array for sentence formatting
  parts=()
  [ "$D" -gt "0" ] && parts+=("$D $D_TAG")
  [ "$H" -gt "0" ] && parts+=("$H $H_TAG")
  [ "$M" -gt "0" ] && parts+=("$M $M_TAG")
  [ "$S" -gt "0" ] && parts+=("$S $S_TAG")

  # construct the sentence
  result="⏳ "
  lengthofparts=${#parts[@]}
  for ((currentpart = 0; currentpart < lengthofparts; currentpart++)); do
    result+="${parts[$currentpart]}"
    # if current part is not the last portion of the sentence, append a comma
    [ $currentpart -ne $((lengthofparts - 1)) ] && result+=", "
  done
  echo "$result of ads muted so far"
}

# create stats file
# this file stores the amount of seconds of ads blocked by the script
STATS_PATH="${MUTE_SPOTIFY_STATS_PATH:-$TMP_DIR}"
STATS_FILENAME="stats.txt"
STATS_FULLPATH="${STATS_PATH}/${STATS_FILENAME}"
echo 0 >"${STATS_FULLPATH}"

# show notifications on desktop
SHOW_SYSTEM_NOTIFICATIONS=0
if [ "${1:-}" = "show" ]; then
  SHOW_SYSTEM_NOTIFICATIONS=1
fi

# How many seconds before checking if and ad is playing.
# Setting this to a lower value will increase CPU usage
INTERVAL_CHECK_TIME_SEC=0.5

# Set vars to prevent double print on alerts
MSG_AD_ECHOED=0
MSG_SONG_PLAYING_ECHOED=0

CURRENT_VOLUME=$(osascript -e 'tell application "Spotify" to set A to sound volume')

cat <<EOM
Muting Spotify desktop ads.

For more information, see https://gdi3d.github.io/mute-spotify-ads-mac-osx
If you experienced any issue, please open an issue at https://github.com/gdi3d/mute-spotify-ads-mac-osx/issues/new

Press Ctrl-C to exit.

EOM

while :; do
  # osascript to get the current track url
  AD_DETECTED=$(osascript -e 'tell application "Spotify" to get spotify url of current track' | cut -d ":" -f 2)

  # prevent 'if unary operator expected' error
  # in case spotify is closed
  if [ -z "${AD_DETECTED:-}" ]; then
    sleep 5
    continue
  fi

  if [ "${AD_DETECTED:-}" == "ad" ]; then
    if [ $MSG_AD_ECHOED -eq 0 ]; then
      # Ad found! Lower volume
      osascript -e 'tell application "Spotify" to set sound volume to 1'
      MSG_AD_ECHOED=1
      MSG="🔇 Ad found, muting until the next song"
      echo "$MSG"
      if [ $SHOW_SYSTEM_NOTIFICATIONS -eq 1 ]; then
        osascript -e "display notification '$MSG' with title 'Muting Spotify Ad'"
      fi
      # start counting. This will be added to the stats.txt file later on
      AD_TIME_START=$(date +%s)
    fi
    MSG_SONG_PLAYING_ECHOED=0
  else
    if [ $MSG_SONG_PLAYING_ECHOED -eq 0 ]; then
      # Ad is gone. Restore volume!
      # Related to https://github.com/gdi3d/mute-spotify-ads-mac-osx/issues/25
      osascript -e 'tell application "Spotify" to set sound volume to '$((CURRENT_VOLUME + 1))
      MSG_SONG_PLAYING_ECHOED=1
      echo "🔈 Songs are playing, restoring volume"
      # add seconds to stats file
      if [ -n "${AD_TIME_START:-}" ]; then
        AD_TIME_END=$(date +%s)
        AD_ELAPSED_TIME=$((AD_TIME_END - AD_TIME_START))
        echo $(($(cat "$STATS_FULLPATH") + AD_ELAPSED_TIME)) >"$STATS_FULLPATH"
        SILENCE_STATS=$(cat "$STATS_FULLPATH")
        rendertimer "$SILENCE_STATS"
        if [ "${SHOW_SYSTEM_NOTIFICATIONS:-}" == "1" ]; then
          STAT_NOT=$(rendertimer "$SILENCE_STATS")
          osascript -e "display notification '$STAT_NOT' with title 'Songs are playing'"
        fi
      fi
    fi
    CURRENT_VOLUME=$(osascript -e 'tell application "Spotify" to set A to sound volume')
    MSG_AD_ECHOED=0
  fi

  # Wait before check again
  sleep $INTERVAL_CHECK_TIME_SEC
done
