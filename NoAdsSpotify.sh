#!/bin/bash
CURRENT_VER=16

set -e

# Detect OSX version
OSX_VERSION=$(defaults read loginwindow SystemVersionStampAsString)
# Add leading zero to make all version have 
# the same length of 6 characters
pat_1="([0-9]{1,2})\.([0-9]{1,2})\.([0-9]{1,2})"
pat_2="([0-9]{1,2})\.([0-9]{1,2})"
[[ $OSX_VERSION =~ $pat_1 ]] # $pat must be unquoted
if [[ ${BASH_REMATCH[0]} == $OSX_VERSION ]]; then
    OSX_VERSION=$(printf %02d "${BASH_REMATCH[1]}" "${BASH_REMATCH[2]}" "${BASH_REMATCH[3]}")
else
    [[ $OSX_VERSION =~ $pat_2 ]] # $pat must be unquoted
    OSX_VERSION=$(printf %02d "${BASH_REMATCH[1]}" "${BASH_REMATCH[2]}" "00")
fi
# Version are written down using
# zero padding %02d to normalize length
# to 6 characters
OS_BIGSUR_3=110203
OS_BIGSUR_2=110201
OS_BIGSUR=110001
OS_CATALINA=101507
OS_MOJAVE=101406
OS_HIGH_SIERRA=101306
OS_SIERRA=101206
OS_EL_CAPITAN=101106
OS_YOSEMITE=101005
OS_MAVERICKS=100905
OS_MOUNTAIN_LION=100805
OS_LION=100705
OS_SNOW_LEOPARD=100608
OS_LEOPARD=100508
OS_TIGER=100411
OS_PANTHER=100309
OS_JAGUAR=100208
OS_PUMA=100105
OS_CHEETAH=100004

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

echo
echo "Spotify Ads will be silenced while this program is running!. (This works ONLY with the Spotify App, not the web version)"
echo "This program was downloaded from https://gdi3d.github.io/mute-spotify-ads-mac-osx/ (check for documentation)"
echo
echo "If the program is not working properly please open an issue at: https://github.com/gdi3d/mute-spotify-ads-mac-osx/issues/new"
echo
echo "Press control+c to close this program or close the terminal window"
echo

sec2min() { printf ">> ⏳ %d mins %02d secs of ads silenced so far 😎\r\n" "$((10#$1 / 60))" "$((10#$1 % 60))"; }

# create stats file
if ! test -f "stats.txt"; then
    echo 0 > stats.txt
fi

# Regex of events that will tell us that a new song/ad is playing
SPOTIFY_EVENT_CATALINA="com\.spotify\.client.+nowPlayingItem.+{"
SPOTIFY_EVENT_MOJAVE="com\.spotify\.client.+playbackQueue.+{"

# Regex to detec ads
AD_REG="albumName = \"\";"
SONG_REG="albumName = (\w+|\".+\");"

EVENT_PRESENT=0 # switch to 1 when a the regex SPOTIFY_EVENT_xxxx matches
CURRENT_VOLUME=$(osascript -e "output volume of (get volume settings)")
AD_DETECTED=0 # switch to 1 when an ad is playing

# Set vars to prevent double print on alerts
MSG_AD_ECHOED=0
MSG_SONG_PLAYING_ECHOED=0

LOG_ARGUMENTS_PROCESS=--process="mediaremoted"
LOG_ARGUMENTS_TYPE=--type="log"
LOG_ARGUMENTS_COLOR=--color="none"
LOG_ARGUMENTS_STYLE=--style="compact"
LOG_ARGUMENTS_PREDICATE=--predicate='eventMessage contains[cd] "spotify.client"'
LOG_ARGUMENTS=( "$LOG_ARGUMENTS_PROCESS" "$LOG_ARGUMENTS_COLOR" "$LOG_ARGUMENTS_TYPE" "$LOG_ARGUMENTS_STYLE" "$LOG_ARGUMENTS_PREDICATE" )

log stream "${LOG_ARGUMENTS[@]}" | \
    while read STREAM_LINE
    do
        # check for OS version and look for the event that tell us that
        # a new song/ad is playing
        if [ $OSX_VERSION -ge $OS_CATALINA ]; then
            if grep -q -E "$SPOTIFY_EVENT_CATALINA" <<< "$STREAM_LINE"; then
                EVENT_PRESENT=1
                
                # We should only store the volume value while a song is playing
                # otherwise we'll be storing the volume value setted for the ad playback (low volume)
                if [ $AD_DETECTED -eq 0 ]; then
                    CURRENT_VOLUME=$(osascript -e 'tell application "Spotify" to set A to sound volume')
                fi
            fi
        elif [ $OSX_VERSION -eq $OS_MOJAVE ]; then
            if grep -q -E "$SPOTIFY_EVENT_MOJAVE" <<< "$STREAM_LINE"; then
                EVENT_PRESENT=1
                
                # We should only store the volume value while a song is playing
                # otherwise we'll be storing the volume value setted for the ad playback (low volume)
                if [ $AD_DETECTED -eq 0 ]; then
                    CURRENT_VOLUME=$(osascript -e 'tell application "Spotify" to set A to sound volume')
                fi
            fi
        else
            # We won't be searching for the event that's about to trigger
            # the ad since it's not present on this version of the OSX.
            # Related to: https://github.com/gdi3d/mute-spotify-ads-mac-osx/issues/2
            EVENT_PRESENT=1
              
            # We should only store the volume value while a song is playing
            # otherwise we'll be storing the volume value setted for the ad playback (low volume)
            if [ $AD_DETECTED -eq 0 ]; then
                CURRENT_VOLUME=$(osascript -e 'tell application "Spotify" to set A to sound volume')
            fi
        fi
        
        # Check if it's a song or an Ad and change the volume when needed
        if [ $EVENT_PRESENT -eq 1 ]; then
            if grep -q -E "$AD_REG" <<< "$STREAM_LINE"; then

                if [ $MSG_AD_ECHOED -eq 0 ]; then
                    MSG_AD_ECHOED=1
                    # We found and Ad OMG!! Let turn the volume way down!
                    echo ">> 🔇 Ad found! Your volume will be set all the way down now until the next song!"
                    # start counting. This will be added to the stats.txt file later on
                    AD_TIME_START=$(date +%s)
                fi

                osascript -e 'tell application "Spotify" to set sound volume to 1'

                AD_DETECTED=1
                EVENT_PRESENT=0
                MSG_SONG_PLAYING_ECHOED=0
        
            elif grep -q -E "$SONG_REG" <<< "$STREAM_LINE"; then
                
                if [ $MSG_SONG_PLAYING_ECHOED -eq 0 ]; then
                    # Ad is gone. Restore volume!
                    MSG_SONG_PLAYING_ECHOED=1
                    echo ">> 🔈 Songs are playing 😀🕺💃. Audio back to normal"
                    # add seconds to stats file
                    if ! [ -z $AD_TIME_START ]; then 
                        AD_TIME_END=$(date +%s)
                        AD_ELAPSED_TIME=$(($AD_TIME_END-$AD_TIME_START))
                        echo $(($(cat stats.txt)+$AD_ELAPSED_TIME)) > stats.txt
                        SILENCE_STATS=$(cat stats.txt)
                        sec2min $SILENCE_STATS
                    fi
                else
                    CURRENT_VOLUME=$(osascript -e 'tell application "Spotify" to set A to sound volume')
                fi

                osascript -e 'tell application "Spotify" to set sound volume to '$CURRENT_VOLUME

                AD_DETECTED=0
                EVENT_PRESENT=0
                MSG_AD_ECHOED=0
            fi
        fi
    done

# echo an error message before exiting on error
trap 'echo ">>> ⛔️ 👎 Oops! Something failed and the program is not running. Please open a new issue at: https://github.com/gdi3d/mute-spotify-ads-mac-osx/issues/new and copy and paste the whole output of this window into so I can fix it."' EXIT
