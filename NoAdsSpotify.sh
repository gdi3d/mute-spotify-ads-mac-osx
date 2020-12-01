#!/bin/bash
CURRENT_VER=9

set -e

# Detect OSX version
OSX_VERSION=$(defaults read loginwindow SystemVersionStampAsString)
OSX_VERSION="${OSX_VERSION//.}"

OS_BIGSUR=1101
OS_CATALINA=10157
OS_MOJAVE=10146
OS_HIGH_SIERRA=10136
OS_SIERRA=10126
OS_EL_CAPITAN=10116
OS_YOSEMITE=10105
OS_MAVERICKS=1095
OS_MOUNTAIN_LION=1085
OS_LION=1075
OS_SNOW_LEOPARD=1068
OS_LEOPARD=1058
OS_TIGER=10411
OS_PANTHER=1039
OS_JAGUAR=1028
OS_PUMA=1015
OS_CHEETAH=1004

# check for HDMI flag. In this case we will lower the volume of spotify application
# instead of system audio
HDMI=0
if [ "$1" == "hdmi" ]; then
    HDMI=1
fi

# check if version is up-to-date
INSTALLATION_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

# check that curl is present in the system
if ! [ -x "$(command -v curl)" ]; then
    echo "curl command is not present. Auto Update function is disabled"
else
    LATEST_VER=$(curl -s https://raw.githubusercontent.com/gdi3d/mute-spotify-ads-mac-osx/master/NoAdsSpotify.sh | grep "CURRENT_VER=" | head -n1 | awk -F '=' '{print $2}')
    
    if [ $CURRENT_VER -ne $LATEST_VER ]; then
        read -n 1 -p "A new version is available, will like to update? [y/N]" update
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
echo "Spotify Ads will be silenced while this program is running!."
echo "This program was downloaded from https://gdi3d.github.io/mute-spotify-ads-mac-osx/ (check for documentation here)"
echo "If you are using HDMI speakers please run this command like this: sh ~/MuteSpotifyAds/NoAdsSpotify.sh hdmi"
echo
echo "If the program is not working properly please open an issue at: https://github.com/gdi3d/mute-spotify-ads-mac-osx/issues/new"
echo
echo "Press control+c to close this program or close the terminal window"
echo

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
MSG_SONG_PLAYING_ECOHED=0

log stream --process="mediaremoted" --type="log" --color="none" --style="compact" | \
    while read STREAM_LINE
    do
        # check for OS version and look for the event that tell us that
        # a new song/ad is playing
        if [ $OSX_VERSION -eq $OS_CATALINA ] || [ $OSX_VERSION -eq $OS_BIGSUR ]; then
            if grep -q -E "$SPOTIFY_EVENT_CATALINA" <<< "$STREAM_LINE"; then
                EVENT_PRESENT=1
                
                # We should only store the volume value while a song is playing
                # otherwise we'll be storing the volume value setted for the ad playback (low volume)
                if [ $AD_DETECTED -eq 0 ]; then

                    if [ $HDMI -eq 1 ]; then
                        CURRENT_VOLUME=$(osascript -e 'tell application "Spotify" to set A to sound volume')
                    else
                        CURRENT_VOLUME=$(osascript -e "output volume of (get volume settings)")
                    fi
                fi
            fi
        elif [ $OSX_VERSION -eq $OS_MOJAVE ]; then
            if grep -q -E "$SPOTIFY_EVENT_MOJAVE" <<< "$STREAM_LINE"; then
                EVENT_PRESENT=1
                
                # We should only store the volume value while a song is playing
                # otherwise we'll be storing the volume value setted for the ad playback (low volume)
                if [ $AD_DETECTED -eq 0 ]; then
                    
                    if [ $HDMI -eq 1 ]; then
                        CURRENT_VOLUME=$(osascript -e 'tell application "Spotify" to set A to sound volume')
                    else
                        CURRENT_VOLUME=$(osascript -e "output volume of (get volume settings)")
                    fi
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
                
                if [ $HDMI -eq 1 ]; then
                    CURRENT_VOLUME=$(osascript -e 'tell application "Spotify" to set A to sound volume')
                else
                    CURRENT_VOLUME=$(osascript -e "output volume of (get volume settings)")
                fi
            fi
        fi
        
        # Check if it's a song or an Ad and change the volume when needed
        if [ $EVENT_PRESENT -eq 1 ]; then
            if grep -q -E "$AD_REG" <<< "$STREAM_LINE"; then

                if [ $MSG_AD_ECHOED -eq 0 ]; then
                    MSG_AD_ECHOED=1
                    # We found and Ad OMG!! Let turn the volume way down!
                    echo ">> 🔇 Ad found! Your volume will be set all the way down now until the next song!"
                fi

                if [ $HDMI -eq 1 ]; then
                    osascript -e 'tell application "Spotify" to set sound volume to 1'
                else
                    osascript -e "set volume without output muted output volume 0.1 --100%"
                fi

                AD_DETECTED=1
                EVENT_PRESENT=0
                MSG_SONG_PLAYING_ECOHED=0
        
            elif grep -q -E "$SONG_REG" <<< "$STREAM_LINE"; then
                
                if [ $MSG_SONG_PLAYING_ECOHED -eq 0 ]; then
                    # Ad is gone. Restore volume!
                    MSG_SONG_PLAYING_ECOHED=1
                    echo ">> 🔈 Songs are playing 😀🕺💃. Audio back to normal"
                    
                fi

                if [ $HDMI -eq 1 ]; then
                    osascript -e 'tell application "Spotify" to set sound volume to '$CURRENT_VOLUME
                else
                    osascript -e 'set volume output volume '$CURRENT_VOLUME' --100%'
                fi

                AD_DETECTED=0
                EVENT_PRESENT=0
                MSG_AD_ECHOED=0
            fi
        
        fi
    done

# echo an error message before exiting on error
trap 'echo ">>> 👎 Oops! Something failed and the program is not running. Please open a new issue at: https://github.com/gdi3d/mute-spotify-ads-mac-osx/issues/new and copy and paste the whole output of this window into yet so I can fix it."' EXIT
