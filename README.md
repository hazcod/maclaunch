
# maclaunch

Lists and controls your macOS startup items and their startup policy.

Take back control of your macOS system!

```shell
% maclaunch list microsoft
> com.microsoft.update.agent
  Type  : user
  User  : hazcod
  Launch: disabled
  File  : /Library/LaunchAgents/com.microsoft.update.agent.plist
> com.microsoft.teams.TeamsUpdaterDaemon
  Type  : system
  User  : root
  Launch: disabled
  File  : /Library/LaunchDaemons/com.microsoft.teams.TeamsUpdaterDaemon.plist
> com.microsoft.office.licensingV2.helper
  Type  : system
  User  : root
  Launch: disabled
  File  : /Library/LaunchDaemons/com.microsoft.office.licensingV2.helper.plist
> com.microsoft.autoupdate.helper
  Type  : system
  User  : root
  Launch: disabled
  File  : /Library/LaunchDaemons/com.microsoft.autoupdate.helper.plist
```

## How does it work?

Lists XML/json/binary plist files in LaunchAgents and LaunchDaemons folders which are loaded by launchctl.
When disabling an item, it uses launchctl to natively stop loading that service.
It does **not** alter the contents in any way or moves the file, so it should work with practically any service.

The name you provide can either be specific to that service or function as a filter to work on multiple services simultaneously.

## Installation

Installation can be done straight from [my Homebrew tap](https://github.com/hazcod/homebrew-hazcod) via `brew install hazcod/homebrew-hazcod/maclaunch` or just copy `maclaunch.sh` to  your filesystem.

## Usage

`Usage: maclaunch <list|disable|enable> (filter|system)`

To list all your services: `maclaunch list`

To list all enabled services: `maclaunch list enabled`

To list all disabled services: `maclaunch list disabled`

To list all your services including system services: `maclaunch list system`

To list all microsoft services: `maclaunch list microsoft`

To enable plex player-helper: `maclaunch enable tv.plex.player-helper`

To disable everything related to plex: `maclaunch disable plex`
