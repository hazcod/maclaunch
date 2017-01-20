#!/usr/bin/env bash

#set -e
#set -x

startup_dirs=(/Library/LaunchAgents /Library/LaunchDaemons)

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'
BOLD='\033[1m'

function join_by { local IFS="$1"; shift; echo "$*"; }

function usage {
    echo "Usage: maclaunch <list|disable|enable> (item name)"
    exit 1
}

function error {
    echo -e "${RED}ERROR:${N} $1"
    exit 1
}

function findStartupPath {
    local name="$1"
    local found=""
    for path in ${startup_dirs[@]}; do
        if [ -f "${path}/${name}.plist" ] || [ -f "${path}/${name}.plist.disabled" ]; then
            if [ ! -z "$found" ]; then
                error "${name}.plist exists in multiple startup directories"
            fi
            found="${path}/${name}.plist"
            break
        fi
    done
    echo "$found"
}

function listItems {
    for dir in ${startup_dirs[@]}; do
        for f in $(find "${dir}" -name "*.plist" -type f -o -name "*.plist.disabled"); do

        	local content=$(cat "$f")
            local startup_name=$(echo "$content" | grep -C1 '<key>Label</key>' | tail -1 | cut -d '>' -f 2 | cut -d '<' -f 1)

            local load_items=()
            if [[ $f =~ \.disabled$ ]]; then
                load_items=("${GREEN}${BOLD}disabled")
            else
                if echo "$content" | awk '/Disabled<\/key>/{ getline; if ($0 ~ /<true\/>/) { f = 1; exit } } END {exit(!f)}'; then
                    load_items+=("${GREEN}Disabled")
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
                fi
            fi

            if [ ${#load_items[@]} == 0 ]; then
                load_str="${YELLOW}Unknown"
            else
                load_str=$(join_by ',' ${load_items[@]})
            fi

            echo -e "${BOLD}> ${startup_name}${NC}"
            echo -e "  Launch: ${load_str}${NC}"
            echo "  $f"

        done
    done
}

function enableItem {
    local startupFile=$(findStartupPath "$1")
    local disabledFile="${startupFile}.disabled"

    if [ ! -f "$disabledFile" ]; then
        error "This item is not disabled${NC}"
    fi

    if mv "$disabledFile" "$startupFile"; then
        echo -e "${GREEN}Enabled ${STRONG}$1${NC}"
    else
        error "Could not enable ${STRONG}$1${NC}"
    fi
}

function disableItem {
    local startupFile=$(findStartupPath "$1")
    
    if [ ! -f "$startupFile" ]; then
        error "This item is already disabled${NC}"
    fi

    if mv "$startupFile" "${startupFile}.disabled"; then
        echo -e "${GREEN}Disabled ${STRONG}$1${NC}"
    else
        error "Could not disable ${STRONG}$1${NC}"
    fi 
}


if [ $# -lt 1 ]; then
    usage
fi

case "$1" in
    "list")
        listItems
    ;;
    "disable")
        if [ -z $2 ]; then
            usage
        fi
        disableItem "$2"
    ;;
    "enable")
        if [ -z $2 ]; then
            usage
        fi
        enableItem "$2"
    ;;
    *)
        usage
    ;;
esac