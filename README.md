# maclaunch
List your macOS startup items and their startup policy.

How does it work?
-------------
Lists plist files in LaunchAgents and LaunchDaemons folders.
When disabling an item, it moves it to .disabled so launchctl does not read them anymore.
It does **not** alter the contents in any way. It does not support JSON plists (for now).

Installation
-------------
Installation is preferred via [my Homebrew tap](https://github.com/hazcod/homebrew-hazcod): `brew tap hazcod/homebrew-hazcod && brew install maclaunch`.

Usage
-------------

`Usage: maclaunch <list|disable|enable> (item name|system)`

![Example output](https://i.imgur.com/VhHTJXJ.png)
