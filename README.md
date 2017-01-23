# maclaunch
List your macOS startup items and their startup policy.

How does it work?
-------------
Lists plist files in /Library/LaunchAgents and /Library/LaunchDaemons. It moves it to ${file}.disabled to launchctl does not read them anymore.
It does **not** alter the contents in any way. It does not support JSON plists (for now).

Usage
-------------

`Usage: maclaunch <list|disable|enable> (item name)`

![Example output](https://i.imgur.com/VhHTJXJ.png)
