#!/usr/bin/env bash

#set -e
#set -x

startup_dirs=(/Library/LaunchAgents /Library/LaunchDaemons ~/Library/LaunchAgents ~/Library/LaunchDaemons)
system_dirs=(/System/Library/LaunchAgents /System/Library/LaunchDaemons)

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'
BOLD='\033[1m'

function join_by { local IFS="$1"; shift; echo "$*"; }

function usage {
    # show command cli usage help
    echo "Usage: $0 <list|disable|enable> (item name|system)"
    exit 1
}

function error {
    # show an error message and exit
    echo -e "${RED}ERROR:${N} ${1}${NC}"
    exit 1
}

function findStartupPath {
    local name="$1"

    # try to find out where the plist resides
    paths=()
    while IFS=  read -r -d $'\0'; do
        paths+=("$REPLY")
    done < <(find "${startup_dirs[@]}" "${system_dirs[@]}" \( -iname "${name}.plist" -o -iname "${name}.plist.disabled" \) -print0 2>/dev/null)

    # if the plist has the same name in multiple directories, error out
    # we might want to revert to maclaunch dump-state, but that's very resource expensive
    #if [ ${#paths[@]} -gt 1 ]; then
    #    error "Multiple paths for '$name':\n${paths[*]}"
    #fi

    echo "${paths[0]}"
}

function isSystem {
    # if it's in /System, it's part of the (protected) system partition
    [[ $1 == /System/* ]]
}

function getScriptUser {
    local scriptPath="$1"

    # if it's in LaunchAgents, it's ran as the user
    if echo "$scriptPath" | grep -q "LaunchAgent"; then
        whoami
        return
    fi

    # if there is no UserName key, it's ran as root
    if ! grep -q '<key>UserName</key>' "$scriptPath"; then
        echo "root"
        return
    fi

    # if UserName key is present, return the custom user
    grep '<key>UserName</key>' -C1 "$scriptPath" | tail -n1 | cut -d '>' -f 2 | cut -d '<' -f 1
}

function listItems {
    local filter="$2"

    itemDirectories=("${startup_dirs[@]}")

    # get disabled services
    disabled_services="$(launchctl print-disabled user/"$(id -u)")"

    # add system dirs too if we supplied the system parameter
    if [ "$filter" == "system" ]; then
        itemDirectories=("${itemDirectories[@]}" "${system_dirs[@]}")
        filter=""
    fi

    # login hooks
    if loginhooks=$(defaults read com.apple.loginwindow LoginHook 2>/dev/null); then
        echo -e "${RED}${BOLD}Warning: you have Login Hooks!${NC}"
        echo -e "${RED}Remove them (with sudo) from /var/root/Library/Preferences/com.apple.loginwindow"
        echo -e "${loginhooks}${NC}"
        echo
        echo
    fi

    # for every plist found
    while IFS= read -r -d '' f; do

        # check if file is readable
        if ! [ -r "$f" ]; then
            echo -e "\nSkipping unreadable file: $f\n"
            continue
        fi
        
        # convert plist to XML if it is binary
        if ! content=$(plutil -convert xml1 "${f}" -o -); then
            error "Unparseable file: $f"
        fi

        # detect the process type
        type="system" ; [[ "$f" =~ .*LaunchAgents.* ]] && type="user"

        # extract the service name
        startup_name="$(basename "$f" | sed -E 's/\.plist(\.disabled)*$//')"

        if [ -n "$filter" ] && [ "$filter" != "enabled" ] && [ "$filter" != "disabled" ]; then
            if [[ "$startup_name" != *"$filter"* ]]; then
                continue
            fi
        fi

        local load_items=()

        # check for legacy behavior
        if [[ $f =~ \.disabled$ ]]; then
            # skip it if we only want enabled items
            if [ -n "$filter" ] && [ "$filter" == "enabled" ]; then
                continue
            fi

            load_items=("${GREEN}${BOLD}disabled${NC}${YELLOW} (legacy)")

        # check if it's disabled natively via launchctl
        elif echo "$disabled_services" | grep -iF "$startup_name" | grep -qi true; then
            # skip it if we only want enabled items
            if [ -n "$filter" ] && [ "$filter" == "enabled" ]; then
                continue
            fi

            load_items=("${GREEN}${BOLD}disabled")
        
        # if it's not disabled, list the startup triggers
        else
            # skip it if we only want disabled items
            if [ -n "$filter" ] && [ "$filter" == "disabled" ]; then
                continue
            fi

            # ---

            if echo "$content" | grep -q 'OnDemand'; then
                load_items+=("${GREEN}OnDemand")
            fi

            if echo "$content" | grep -q 'RunAtLoad'; then
                load_items+=("${RED}OnStartup")
            fi

            if echo "$content" | grep -q 'KeepAlive'; then
                load_items+=("${RED}Always")
            fi

            if echo "$content" | grep -q 'StartOnMount'; then
                load_items+=("${YELLOW}OnFilesystemMount")
            fi

            if echo "$content" | grep -q 'StartInterval'; then
                load_items+=("${RED}Periodically")
            fi

            if echo "$content" | grep -q "MachServices"; then
                load_items+=("${RED}MachService")
            fi

            if echo "$content" | grep -q "WatchPaths"; then
                load_items+=("${YELLOW}WatchPaths")
            fi
        fi

        # if we did not detect anything, something weird happened
        if [ ${#load_items[@]} == 0 ]; then
            load_str="${YELLOW}Unknown"
        else
            load_str=$(join_by ',' "${load_items[@]}")
        fi

        # set the type to core if it's a system process (e.g. protected by SIP)
        if isSystem "$f"; then
            startup_type=" (core)"
        fi

        # print what user this process is run as
        runAsUser="$(getScriptUser "$f")"
        if [ "$runAsUser" = "root" ]; then
            runAsUser="${RED}root${NC}"
        elif [ "$runAsUser" = "custom" ]; then
            runAsUser="${YELLOW}custom${NC}"
        fi

        echo -e "${BOLD}> ${startup_name}${NC}${startup_type}"
        echo    "  Type  : ${type}"
        echo -e "  User  : ${runAsUser}"
        echo -e "  Launch: ${load_str}${NC}"
        echo    "  File  : $f"

    done< <(find "${itemDirectories[@]}" -type f -iname '*.plist*' -print0 2>/dev/null)
}

function enableItem {
    # find out where it's stored
    startupFile=$(findStartupPath "$1")

    # error out if we didn't find a plist
    if [ -z "$startupFile" ]; then
        error "Could not find plist for $1"
    fi

    # fix legacy .disabled behavior
    startupFile="$(echo "$startupFile" | sed -E 's/(\.disabled)$//')"
    disabledFile="$(echo "$startupFile" | sed -E 's/(\.disabled)$//').disabled"
    if [ -f "$disabledFile" ] && ! mv "$disabledFile" "$startupFile"; then
        error "could not move '$startupFile' to '$disabledFile'. Try to run with sudo?"
    fi

    # check if it's disabled
    if ! launchctl print-disabled user/"$(id -u)" | grep -qi "$1" | grep true; then
        error "This item is already enabled"
    fi

    # try to enable it
    if ! launchctl disable user/"$(id -u)"/"$1"; then
        error "Could not enable ${STRONG}$1${NC}"
    fi

    echo -e "${GREEN}Enabled ${STRONG}$1${NC}"
}

function disableItem {
    startupFile="$(findStartupPath "$1")"

    # error out if we didn't find a plist
    if [ -z "$startupFile" ]; then
        error "Could not find plist for $1"
    fi
    
    # fix legacy .disabled behavior
    startupFile="$(echo "$startupFile" | sed -E 's/(\.disabled)$//')"
    disabledFile="$(echo "$startupFile" | sed -E 's/(\.disabled)$//').disabled"
    if [ -f "$disabledFile" ] && ! mv "$disabledFile" "$startupFile"; then
        error "could not move '$startupFile' to '$disabledFile'. Try to run with sudo?"
    fi

    # check if it's enabled
    if launchctl print-disabled user/"$(id -u)" | grep -qi "$1" | grep true; then
        error "This item is already disabled"
    fi

    # try to disable it
    if ! launchctl disable user/"$(id -u)"/"$1"; then
        error "Could not disable ${STRONG}$1${NC}"
    fi

    echo -e "${GREEN}Disabled ${STRONG}$1${NC}"
}


if [ $# -lt 1 ] || [ $# -gt 2 ]; then
    usage
fi

case "$1" in
    "list")
        if [ $# -ne 1 ]; then
            if [ $# -ne 2 ]; then
                usage
            fi
        fi
        listItems "$1" "$2"
    ;;
    "disable")
        if [ $# -ne 2 ]; then
            usage
        fi
        disableItem "$2"
    ;;
    "enable")
        if [ $# -ne 2 ]; then
            usage
        fi
        enableItem "$2"
    ;;
    *)
        usage
    ;;
esac
