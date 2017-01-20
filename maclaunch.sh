#!/usr/bin/env bash

#set -e
#set -x

startup_files=(/Library/LaunchAgents/*.plist /Library/LaunchDaemons/*.plist)

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'
BOLD='\033[1m'

function join_by { local IFS="$1"; shift; echo "$*"; }

for f in ${startup_files[@]}; do

	if [ ! -f $f ]; then
		echo "!ERROR: Broken startup item: $f"
		continue
	fi

	content=$(cat "$f")

    startup_name=$(echo "$content" | grep -C1 '<key>Label</key>' | tail -1 | cut -d '>' -f 2 | cut -d '<' -f 1)

    load_items=()
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

    if [ ${#load_items[@]} == 0 ]; then
    	load_str="${YELLOW}Unknown"
    else
    	load_str=$(join_by ',' ${load_items[@]})
    fi

    echo -e "${BOLD}> ${startup_name}${NC}"
    echo -e "  Launch: $load_str ${NC}"
    echo "  $f"


done
