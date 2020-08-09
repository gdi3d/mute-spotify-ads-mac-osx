# Automatically mute Spotify Ads

I hate hearing the Spotify Ads. This small script detects when Ads gets loaded and mutes the system audio until a song it's loaded again. 


# How does it work

1. Using OSX log system we can listen to Spotify events.
2. Read the events and check if an Ad is about to be played using a regex.
3. If the event is an Ad about to be played **automatically mute system audio**.
4. If the next event is a song, **unmute system audio**.

# How to Install

1. Open a new terminal (use Spotlight search and type **terminal.app**)
2. Inside the new window paste this command and then hit enter
   `mkdir -p ~/MuteSpotifyAds && curl https://raw.githubusercontent.com/gdi3d/mute-spotify-ads-mac-osx/master/NoAdsSpotify.sh > ~/MuteSpotifyAds/NoAdsSpotify.sh`
3. This will create a new folder inside your **Home** folder called **MuteSpotifyAds** and will place a new file called **NoAdsSpotify.sh**
4. To run the program just copy and paste `sh ~/MuteSpotifyAds/NoAdsSpotify.sh` this command in the terminal and hit enter
5. To exit the program just close the **terminal app** or press **Ctrl+c**

# Why not blocking Ads instead???

I used to have all the Spotify Ads DNS blocked but that stopped working.

Besides, I was bored that Saturday noon and I wanted to give it a try.

