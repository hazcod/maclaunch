# maclaunch
List your macOS startup items and their startup policy.

How does it work?
-------------
Lists plist files in LaunchAgents and LaunchDaemons folders.
When disabling an item, it moves it to .disabled so launchctl does not read them anymore.
It does **not** alter the contents in any way. It does not support JSON plists (for now).

Usage
-------------

`Usage: maclaunch <list|disable|enable> (item name|system)`

![Example output](https://i.imgur.com/VhHTJXJ.png)
