#!/bin/bash
CURRENT_VER=21

set -e

# check if version is up-to-date
INSTALLATION_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

# check that curl is present in the system
if ! [ -x "$(command -v curl)" ]; then
    echo "curl command is not present. Auto Update function is disabled"
else
    LATEST_VER=$(curl -s https://raw.githubusercontent.com/gdi3d/mute-spotify-ads-mac-osx/master/NoAdsSpotify.sh | grep "CURRENT_VER=" | head -n1 | awk -F '=' '{print $2}')
    
    if [ $CURRENT_VER -ne $LATEST_VER ]; then
        read -n 1 -p "A new version is available, will you like to update? [y/N]" update
        if [ -n "$update" ]; then
            if [ $update == "y" ]; then
                curl https://raw.githubusercontent.com/gdi3d/mute-spotify-ads-mac-osx/master/NoAdsSpotify.sh > $INSTALLATION_DIR/NoAdsSpotify.sh
                echo "Update finish. 🥳"
                RELAUNCH="/bin/bash ${INSTALLATION_DIR}/NoAdsSpotify.sh {$1}"
                exec ${RELAUNCH}
            else
                echo
                echo "Skiping update... ☹️"
            fi
        else
            echo
            echo "Skiping update... ☹️"
        fi
    fi
fi

sec2min() { printf ">> ⏳ %d mins %02d secs of ads silenced so far 😎\r\n" "$((10#$1 / 60))" "$((10#$1 % 60))"; }

# create stats file
# this file stores the amount of seconds of ads blocked by the script
STATS_PATH=""
if [ ! -z ${MUTE_SPOTIFY_STATS_PATH+x} ]; then
    STATS_PATH=$MUTE_SPOTIFY_STATS_PATH
fi

if [ -z "$STATS_PATH" ]; then
    STATS_PATH="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
fi

STATS_FILENAME="stats.txt"
STATS_FULLPATH=$(echo $STATS_PATH"/"$STATS_FILENAME | tr -s /)
if ! test -f $STATS_FULLPATH; then
    echo 0 > $STATS_FULLPATH
fi

# show notifications on desktop
SHOW_SYSTEM_NOTIFICATIONS=0
if ! [ -z $1  ] && [ $1 == "show" ]; then
    SHOW_SYSTEM_NOTIFICATIONS=1
fi

# How many seconds before checking if and ad is playing.
# Setting this to a lower value will increase CPU usage
INTERVAL_CHECK_TIME_SEC=0.5

# Set vars to prevent double print on alerts
MSG_AD_ECHOED=0
MSG_SONG_PLAYING_ECHOED=0

CURRENT_VOLUME=$(osascript -e 'tell application "Spotify" to set A to sound volume')

echo
echo "Spotify Ads will be silenced while this program is running!. (This works ONLY with the Spotify App, not the web version)"
echo "This program was downloaded from https://gdi3d.github.io/mute-spotify-ads-mac-osx/ (check for documentation)"
echo
echo "If the program is not working properly please open an issue at: https://github.com/gdi3d/mute-spotify-ads-mac-osx/issues/new"
echo
echo "Press control+c to close this program or close the terminal window"
echo

while :
    do 

        # Thanks to @bbbco for this cool tip on how to use 
        # osascript to get the current track url
        AD_DETECTED=$(osascript -e 'tell application "Spotify" to get spotify url of current track'|cut -d ":" -f 2)
        
        # prevent 'if unary operator expected' error
        # in case spotify is closed
        if [ -z $AD_DETECTED ]; then
            sleep 5
            continue
        fi

        if [ $AD_DETECTED == 'ad' ]; then

            if [ $MSG_AD_ECHOED -eq 0 ]; then
                
                # Ad found! Lower volume
                osascript -e 'tell application "Spotify" to set sound volume to 1'

                MSG_AD_ECHOED=1
                
                echo ">> 🔇 Ad found! Your volume will be set all the way down now until the next song!"

                if [ $SHOW_SYSTEM_NOTIFICATIONS -eq 1 ]; then
                    osascript -e "display notification \"🔇 Ad found! Your volume will be set all the way down now until the next song!\" with title \"Muting Spotify Ad\""
                fi

                # start counting. This will be added to the stats.txt file later on
                AD_TIME_START=$(date +%s)
            fi

            MSG_SONG_PLAYING_ECHOED=0

        else

            if [ $MSG_SONG_PLAYING_ECHOED -eq 0 ]; then
                    
                # Ad is gone. Restore volume!
                # Related to https://github.com/gdi3d/mute-spotify-ads-mac-osx/issues/25
                osascript -e 'tell application "Spotify" to set sound volume to '$(($CURRENT_VOLUME+1))

                MSG_SONG_PLAYING_ECHOED=1
                echo ">> 🔈 Songs are playing 😀🕺💃. Audio back to normal"
                
                # add seconds to stats file
                if ! [ -z $AD_TIME_START ]; then 
                    AD_TIME_END=$(date +%s)
                    AD_ELAPSED_TIME=$(($AD_TIME_END-$AD_TIME_START))
                    echo $(($(cat $STATS_FULLPATH)+$AD_ELAPSED_TIME)) > $STATS_FULLPATH
                    SILENCE_STATS=$(cat $STATS_FULLPATH)
                    sec2min $SILENCE_STATS

                    if [ $SHOW_SYSTEM_NOTIFICATIONS -eq 1 ]; then
                        STAT_NOT=$(sec2min $SILENCE_STATS)
                        osascript -e "display notification \"$STAT_NOT\" with title \"Songs are playing 😀🕺💃\""
                    fi
                fi
            fi
            
            CURRENT_VOLUME=$(osascript -e 'tell application "Spotify" to set A to sound volume')
            MSG_AD_ECHOED=0

        fi

        # Wait before check again
        sleep $INTERVAL_CHECK_TIME_SEC
    done

# echo an error message before exiting on error
trap 'echo ">>> ⛔️ 👎 Oops! Something failed and the program is not running. Please open a new issue at: https://github.com/gdi3d/mute-spotify-ads-mac-osx/issues/new and copy and paste the whole output of this window into so I can fix it."' EXIT