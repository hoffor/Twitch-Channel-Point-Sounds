# Twitch Channel Point Sounds

Play a sound file and/or read aloud a viewer's message with text-to-speech when they redeem a channel point reward

![GUI Screenshot](GUI_Screenshot.png?raw=true)

### Installation:
Unzip the "Twitch Channel Point Sounds" folder anywhere and run the .exe! If you want, you can right click the .exe and "Send to > Desktop (Create shortcut)".

### How to use: 

I recommend jumping right into using the program, but here are some instructions just in case.

1. Click "Add account" and you'll see an official Twitch webpage asking if you want to link your account. After confirming you'll get a code which you'll just copy-paste into the program.

2. Add your preferred sound file/text-to-speech entries to the list, each corresponding to the name of a given channel point redeem.

3. On the right side of the window, enter the channel name you want sound reactions for and click "Enable Monitor" to connect! Don't stress reading the technical console output, it's just there if you wanted clues about a connection error or something.

Done! You can just minimize to tray. Now when a user redeems something, its corresponding sound will play. Or if it's a text-to-speech redeem, the TTS will read aloud their message. Have fun!

### Reporting a bug:

Be sure you have the latest version. Currently it is NOT a good idea to paste the console output here or anywhere, since it will contain your access token, which is not meant to be shared. If you're 100% sure you've scrubbed that out of your post, go for it.

### Building your own .exe from source code:
Install [AutoHotkey](https://www.autohotkey.com) v1.1 (not v2). Then right click your .ahk file and do "Compile Script (GUI)...". From there you can choose the icon file (twitch_channel_point_sounds.ico).

### Contributing:

Contributors are all welcome! I'm more likely to accept pull requests that address something in the todo list. If you have a suggestion or criticism, feel free to create a github issue about it.

### Why AutoHotkey?

This program doesn't actually use hotkeys at all, I'm just most comfortable with this language, and its GUI system is very straightforward.

Disclaimer: This software is in no way affiliated with twitch.tv
