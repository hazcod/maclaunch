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
    echo "Usage: $0 <list|disable|enable> (item name|system)"
    exit 1
}

function error {
    echo -e "${RED}ERROR:${N} ${1}${NC}"
    exit 1
}

function findStartupPath {
    local name
    local found
    name="$1"
    found=""
    for path in "${startup_dirs[@]}"; do
        if [ -f "${path}/${name}.plist" ] || [ -f "${path}/${name}.plist.disabled" ]; then
            if [ -n "$found" ]; then
                error "${name}.plist exists in multiple startup directories"
            fi
            found="${path}/${name}.plist"
            break
        fi
    done
    echo "$found"
}

function isSystem {
    [[ $1 == /System/* ]]
}

function listItems {
    itemDirectories=("${startup_dirs[@]}")

    # add system dirs if necessary
    if [ "$2" == "system" ]; then
        itemDirectories=("${itemDirectories[@]}" "${system_dirs[@]}")
    fi

    # login hooks
    if loginhooks=$(defaults read com.apple.loginwindow LoginHook 2>/dev/null); then
        echo -e "${RED}${BOLD}Warning: you have Login Hooks!${NC}"
        echo -e "${RED}Remove them (with sudo) from /var/root/Library/Preferences/com.apple.loginwindow"
        echo -e "${loginhooks}${NC}"
        echo
        echo
    fi

    # regular startup directories
    for dir in "${itemDirectories[@]}"; do

        if [ ! -d "$dir" ]; then
            continue
        fi

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

            type="system" ; [[ "$f" =~ .*LaunchAgents.* ]] && type="user"

            startup_name=$(basename "$f" | sed -E 's/\.plist(\.disabled)*$//')

            local load_items=()
            if [[ $f =~ \.disabled$ ]]; then
                load_items=("${GREEN}${BOLD}disabled")
            else
                if echo "$content" | awk '/Disabled<\/key>/{ getline; if ($0 ~ /<true\/>/) { f = 1; exit } } END {exit(!f)}'; then
                    load_items+=("${GREEN}disabled")
                else
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
            fi

            if [ ${#load_items[@]} == 0 ]; then
                load_str="${YELLOW}Unknown"
            else
                load_str=$(join_by ',' "${load_items[@]}")
            fi

            if isSystem "$f"; then
                startup_type=" (core)"
            fi

            echo -e "${BOLD}> ${startup_name}${NC}${startup_type}"
            echo    "  Type  : ${type}"
            echo -e "  Launch: ${load_str}${NC}"
            echo    "  File  : $f"

        done < <(find "${dir}" -name '*.plist*' -type f -print0)
    done
}

function enableItem {
    startupFile=$(findStartupPath "$1")
    disabledFile="${startupFile}.disabled"

    if [ ! -f "$disabledFile" ]; then
        if [ -f "$startupFile" ]; then
            error "This item is already enabled${NC}"
        else
            error "$1 does not exist"
        fi
    fi

    if mv "$disabledFile" "$startupFile" && [ -f "$startupFile" ]; then
        echo -e "${GREEN}Enabled ${STRONG}$1${NC}"
    else
        error "Could not enable ${STRONG}$1${NC}"
    fi
}

function disableItem {
    startupFile=$(findStartupPath "$1")
    
    if [ ! -f "$startupFile" ]; then
        if [ -f "${startupFile}.disabled" ]; then
            error "This item is already disabled${NC}"
        else
            error "$1 does not exist"
        fi
    fi

    if mv "$startupFile" "${startupFile}.disabled" && [ -f "${startupFile}.disabled" ]; then
        echo -e "${GREEN}Disabled ${STRONG}$1${NC}"
    else
        error "Could not disable ${STRONG}$1${NC}"
    fi 
}


if [ $# -lt 1 ] || [ $# -gt 2 ]; then
    usage
fi

case "$1" in
    "list")
        if [ $# -ne 1 ]; then
            if [ $# -ne 2 ] || [ "$2" != "system" ]; then
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
