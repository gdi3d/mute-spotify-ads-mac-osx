#!/bin/bash
CURRENT_VER=1

# Detect OSX version
OSX_VERSION=$(defaults read loginwindow SystemVersionStampAsString)
OSX_VERSION="${OSX_VERSION//.}"

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
                RELAUNCH="/bin/bash ${INSTALLATION_DIR}/NoAdsSpotify.sh"
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
echo "Spotify Ads will be silenced while this program is running!"
echo "This program was downloaded from https://gdi3d.github.io/mute-spotify-ads-mac-osx/"
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

log stream --process "mediaremoted" --type "log" --color none --style compact | \
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
                    CURRENT_VOLUME=$(osascript -e "output volume of (get volume settings)")
                fi
            fi
        elif [ $OSX_VERSION -ge $OS_MOJAVE ]; then
            if grep -q -E "$SPOTIFY_EVENT_MOJAVE" <<< "$STREAM_LINE"; then
                EVENT_PRESENT=1
                
                # We should only store the volume value while a song is playing
                # otherwise we'll be storing the volume value setted for the ad playback (low volume)
                if [ $AD_DETECTED -eq 0 ]; then
                    CURRENT_VOLUME=$(osascript -e "output volume of (get volume settings)")
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
                CURRENT_VOLUME=$(osascript -e "output volume of (get volume settings)")
            fi
        fi
        
        # Check if it's a song or an Ad and change the volume when needed
        if [ $EVENT_PRESENT -eq 1 ]; then
            if grep -q -E "$AD_REG" <<< "$STREAM_LINE"; then
                # We found and Ad OMG!! Let turn the volume way down!
                echo ">> 🔇 Ad found! Your volume will be set all the way down now!"
                osascript -e "set volume without output muted output volume 1 --100%"
                
                AD_DETECTED=1
                EVENT_PRESENT=0
        
            elif grep -q -E "$SONG_REG" <<< "$STREAM_LINE"; then
                # Ad is gone. Restore volume!
                echo ">> 🔈 Song is playing 😀🕺💃. Audio back to normal"
                osascript -e 'set volume output volume '$CURRENT_VOLUME' --100%'

                AD_DETECTED=0
                EVENT_PRESENT=0
            fi
        
        fi
    done
