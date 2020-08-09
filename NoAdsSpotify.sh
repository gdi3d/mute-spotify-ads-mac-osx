#!/bin/bash
AD_REG="albumName = \"\";"
SONG_REG="albumName = (\w+|\".+\");"

echo
echo "Spotify Ads will be muted while this program is running!"
echo "Press Ctrl+c to close this program or close the terminal window"

log stream --process "mediaremoted" --type "log" | \
    while read STREAM
    do
        if grep -q -E "$AD_REG" <<< "$STREAM"; then
            # We found and Ad OMG!! Let mute this shit!
            echo ">> 🔇 Ad found! Your audio is muted now!."
            osascript -e 'set volume output muted true'
        
        elif grep -q -E "$SONG_REG" <<< "$STREAM"; then
            # Ad is gone. Unmute!
            echo ">> 🔈 Song is playing 😀. Audio is unmuted now."
			osascript -e 'set volume output muted false'
		fi
    done
