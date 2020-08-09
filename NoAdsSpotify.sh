#!/bin/bash
AD_REG="albumName = \"\";"
SONG_REG="albumName = (\w+|\".+\");"

SPOTIFY_EVENT="com\.spotify\.client.+nowPlayingItem.+{"

echo
echo "Spotify Ads will be muted while this program is running!"
echo "Press Ctrl+c to close this program or close the terminal window"

event_present=0

log stream --process "mediaremoted" --type "log" --color none --style compact --no-backtrace | \
    while read STREAM_LINE
    do
        if grep -q -E "$SPOTIFY_EVENT" <<< "$STREAM_LINE"; then
            event_present=1
        fi

        if [ $event_present -eq 1 ]; then
            if grep -q -E "$AD_REG" <<< "$STREAM_LINE"; then
                # We found and Ad OMG!! Let mute this shit!
                echo ">> 🔇 Ad found! Your audio is muted now!."
                osascript -e 'set volume output muted true'
                event_present=0
        
            elif grep -q -E "$SONG_REG" <<< "$STREAM_LINE"; then
                # Ad is gone. Unmute!
                echo ">> 🔈 Song is playing 😀. Audio is unmuted now."
			    osascript -e 'set volume output muted false'
                event_present=0
            fi
        
        fi
    done
