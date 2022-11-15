#!/usr/bin/env bash

startup_dirs=(/Library/LaunchAgents /Library/LaunchDaemons ~/Library/LaunchAgents ~/Library/LaunchDaemons /etc/emond.d/rules/)
system_dirs=(/System/Library/LaunchAgents /System/Library/LaunchDaemons)

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'
BOLD='\033[1m'

#
#--------------------------------------------------------------------------------------------------------------------------------------
#

function isSystemItemsEnabled() {
    [[ "${ML_SYSTEM}" == "1" ]]
}

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

function isSystem {
    # if it's in /System, it's part of the (protected) system partition
    [[ $1 == /System/* ]]
}

function getScriptUser {
    local scriptPath="$1"

    # if it's in LaunchAgents, it's ran as the user
    if echo "$scriptPath" | grep -sqi "LaunchAgent"; then
        whoami
        return
    fi

    # if there is no UserName key, it's ran as root
    if ! grep -sqi '<key>UserName</key>' "$scriptPath"; then
        echo "root"
        return
    fi

    # if UserName key is present, return the custom user
    grep -si '<key>UserName</key>' -C1 "$scriptPath" | tail -n1 | cut -d '>' -f 2 | cut -d '<' -f 1
}

function getKernelExtensions {
    kmutil showloaded --no-kernel-components --list-only --sort --show loaded 2>/dev/null | tr -s ' ' | grep -v 'com\.apple\.'
}

function getCronjobs {
    crontab -l 2>/dev/null | grep -v '^#' | cut -d ' ' -f 6
}

function listCronJobs {
    local filter="$1"

    getCronjobs | while IFS= read -r name; do

        if [ -n "$filter" ] && ! [[ "$name" =~ $filter ]]; then
            continue
        fi

        echo -e "${BOLD}> ${name}${NC}"
        echo -e "  Type  : cronjob"
        echo -e "  User  : $(whoami)"
        echo -e "  Launch: ${ORANGE}enabled${NC}"
        echo    "  File  : n/a"
    done
}

function listPeriodic() {
    local filter="$1"

    if ! isSystemItemsEnabled; then
        return
    fi

    find /etc/periodic -type f | while IFS= read -r name; do
        mode="daily"
        
        if [[ ${name} =~ /etc/periodic/weekly ]]; then
            mode="weekly"
        elif [[ ${name} =~ /etc/periodic/monthly ]]; then
            mode="monthly"
        fi

        if [ -n "$filter" ] && ! [[ "$name" =~ $filter ]]; then
            continue
        fi

        echo -e "${BOLD}> ${name}${NC}"
        echo -e "  Type  : periodic"
        echo -e "  User  : $(whoami)"
        echo -e "  Launch: ${YELLOW}${mode}${NC}"
        echo    "  File  : ${name}"
    done
}

function enablePeriodic() {
    local filter="$1"

    find /etc/periodic -type f | while IFS= read -r name; do

        if [ -n "$filter" ] && ! [[ "$name" =~ $filter ]]; then
            continue
        fi

        echo -e "${BOLD}${YELLOW}Warning: enable individual periodic scripts in /etc/defaults/periodic.conf${NC}"
        return
    done
}

function disablePeriodic() {
    local filter="$1"

    find /etc/periodic -type f | while IFS= read -r name; do

        if [ -n "$filter" ] && ! [[ "$name" =~ $filter ]]; then
            continue
        fi

        echo -e "${BOLD}${YELLOW}Warning: disable individual periodic scripts in /etc/defaults/periodic.conf${NC}"
        return
    done
}

function listKernelExtensions {
    local filter="$1"

    if ! isSystemItemsEnabled; then
        return
    fi

    getKernelExtensions | while IFS= read -r kextLine; do

        kextLoaded="$(echo "$kextLine" | cut -d ' ' -f 3)"
        kextName="$(echo "$kextLine" | cut -d ' ' -f 7)"
        kextVersion="$(echo "$kextLine" | grep -o '\((.*)\)')"

        if [ "$filter" == "disabled" ] && [ "$kextLoaded" != "0" ]; then
            continue
        fi

        if [ "$filter" == "enabled" ] && [ "$kextLoaded" == "0" ]; then
            continue
        fi

        if [ -n "$filter" ] && [ "$filter" != "system" ] && [ "$filter" != "enabled" ] && [ "$filter" != "disabled" ]; then
            if [[ "$kextName" != *"$filter"* ]]; then
                continue
            fi
        fi

        kernelPath="$(kextfind -system-extensions "$kextName" 2>/dev/null)"
        if [ -z "$kernelPath" ]; then
            kernelPath="n/a"
        fi
        
        local loaded
        if [ "$kextLoaded" == "0" ]; then
            loaded="${GREEN}${BOLD}disabled${NC}"
        else
            loaded="${RED}Always${NC}"
        fi

        echo -e "${BOLD}> ${kextName}${NC} ${kextVersion}"
        echo -e "  Type  : ${RED}kernel extension${NC}"
        echo -e "  User  : ${RED}root${NC}"
        echo -e "  Launch: ${loaded}"
        echo    "  File  : ${kernelPath}"

    done
}

function disableKernelExtensions {
    local filter="$1"

    getKernelExtensions | while IFS= read -r kextLine; do

        kextLoaded="$(echo "$kextLine" | cut -d ' ' -f 3)"
        kextName="$(echo "$kextLine" | cut -d ' ' -f 7)"
        
        if ! [[ "$kextName" =~ $filter ]]; then
            continue
        fi

        if [ "$kextLoaded" == "0" ]; then
            #error "kernel extension is already unloaded"
            continue
        fi

        if ! kmutil load -b "$kextName" 1>/dev/null; then
            error "could not disable kernel extension"
        fi

        echo -e "${GREEN}Disabled ${STRONG}${kextName}${NC}"
    done
}

function enableKernelExtensions {
    local filter="$1"

    getKernelExtensions | while IFS= read -r kextLine; do

        kextLoaded="$(echo "$kextLine" | cut -d ' ' -f 3)"
        kextName="$(echo "$kextLine" | cut -d ' ' -f 7)"
        
        if ! [[ "$kextName" =~ $filter ]]; then
            continue
        fi

        if ! [ "$kextLoaded" == "0" ]; then
            #error "kernel extension is already loaded"
            continue
        fi

        if ! kmutil unload -b "$kextName" 1>/dev/null; then
            error "could not disable kernel extension"
        fi

        echo -e "${GREEN}Enabled ${STRONG}${kextName}${NC}"
    done
}

function getSystemExtensions {
    systemextensionsctl list 2>/dev/null | tail -n+2 | grep -v '^---' | grep -v '^enabled' | tr -s ' '
}

function listSystemExtensions {
    local filter="$1"

    getSystemExtensions | while IFS= read -r extLine; do

        fullName="$(echo "$extLine" | cut -d$'\t' -f 4)"
        extName="$(echo "$fullName" | cut -d ' ' -f 1)"
        extVersion="$(echo "$fullName" | grep -o '\((.*)\)')"

        if [ -n "$filter" ] && ! [[ "$extName" =~ $filter ]]; then
            continue
        fi

        local loaded
        if [ "$(echo "$extLine" | cut -d$'\t' -f 2)" == "*" ]; then
            loaded="${ORANGE}enabled${NC}"
        else
            loaded="${GREEN}disabled${NC}"
        fi

        echo -e "${BOLD}> ${extName}${NC} ${extVersion}"
        echo -e "  Type  : system extension"
        echo -e "  User  : $(whoami)"
        echo -e "  Launch: ${loaded}"
        echo    "  File  : n/a"
    done
}

function enableSystemExtensions {
    local filter="$1"

    getSystemExtensions | while IFS= read -r extLine; do

        extName="$(echo "$extLine" | cut -d$'\t' -f 4 | cut -d ' ' -f 1)"

        if ! [[ "$extName" =~ $filter ]]; then
            continue
        fi

        if [ "$(echo "$extLine" | cut -d$'\t' -f 2)" == "*" ]; then
            # error "this system extension is already enabled"
            continue
        fi

        #TODO: implement load system extension via CLI
        error "enabling system extensions is not yet implemented"
    done
}

function disableSystemExtensions {
    local filter="$1"

    getSystemExtensions | while IFS= read -r extLine; do

        extName="$(echo "$extLine" | cut -d$'\t' -f 4 | cut -d ' ' -f 1)"

        if ! [[ "$extName" =~ $filter ]]; then
            continue
        fi

        if ! [ "$(echo "$extLine" | cut -d$'\t' -f 2)" == "*" ]; then
            # error "this system extension is already disabled"
            continue
        fi

        if ! systemextensionsctl uninstall '-' "$extName"; then
            error "could not disable system extension"
        fi

        echo -e "${GREEN}Enabled ${STRONG}${extName}${NC}"
    done
}

function getDisabledLoginItems {
    cat /var/db/com.apple.xpc.launchd/disabled.*  | grep -is '<key>' -A1 | grep -is '<true' -B1 | grep -is '<key>' | cut -d '>' -f 2 | cut -d '<' -f 1
}

function listLoginItems {
    local filter="$1"

    runAsUser="$(whoami)"

    disabledLoginItems=$(getDisabledLoginItems)
    
    # for every plist found
    while IFS= read -r -d '' plistPath; do

        loginItems=$(cat "$plistPath" | grep key | cut -d '>' -f 2 | cut -d '<' -f 1)

        for loginItem in ${loginItems[@]}; do

            if [ -n "$filter" ] && [ "$filter" != "enabled" ] && [ "$filter" != "disabled" ]; then
                if [[ "$loginItem" != *"$filter"* ]]; then
                    continue
                fi
            fi

            local launchState=""
            for disabledLoginItem in ${disabledLoginItems[@]}; do
                if [[ "$loginItem" == "$disabledLoginItem" ]]; then
                    launchState="${GREEN}${BOLD}disabled"
                    break
                fi
            done

            if [ -z "" ]; then
                launchState="${YELLOW}LoginItem"
            fi
        
            echo -e "${BOLD}> ${loginItem}${NC}${startup_type}"
            echo    "  Type  : LoginItem"
            echo -e "  User  : ${runAsUser}"
            echo -e "  Launch: ${launchState}${NC}"
            echo    "  File  : ${plistPath}"

        done

    done< <(find /var/db/com.apple.xpc.launchd -iname "loginitems.*.plist" -print0 2>/dev/null)
}

function listLaunchItems {
    local filter="$2"

    itemDirectories=("${startup_dirs[@]}")

    # get disabled services
    disabled_services="$(launchctl print-disabled user/"$(id -u)")"

    # add system dirs too if we supplied the system parameter
    if [ "$filter" == "system" ]; then
        if isSystemItemsEnabled; then
            itemDirectories=("${itemDirectories[@]}" "${system_dirs[@]}")
            filter=""
        fi
    fi

    # login hooks
    if loginHooks=$(defaults read com.apple.loginwindow LoginHook 2>/dev/null); then
        echo -e "${RED}${BOLD}Warning: you have Login Hooks!${NC}"
        echo -e "${RED}Remove them (with sudo) from /var/root/Library/Preferences/com.apple.loginwindow"
        echo -e "${loginHooks}${NC}"
        echo
        echo
    fi

    # logout hooks
    if logoutHooks=$(defaults read com.apple.loginwindow LogoutHook 2>/dev/null); then
        echo -e "${RED}${BOLD}Warning: you have Login Hooks!${NC}"
        echo -e "${RED}Remove them (with sudo) from /var/root/Library/Preferences/com.apple.loginwindow"
        echo -e "${logoutHooks}${NC}"

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
        elif echo "$disabled_services" | grep -iF "$startup_name" | grep -Eqi '(true|disabled)'; then
            # skip it if we only want enabled items
            if [ -n "$filter" ] && [ "$filter" == "enabled" ]; then
                continue
            fi

            load_items=("${GREEN}${BOLD}disabled")

        # check if enabled is set to false in the plist
        elif echo "${content}" | tr -d '\n' | tr -d '\t' | tr -d ' ' | grep -q 'enabled</key><false'; then
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

            if echo "$content" | grep -qE 'Start(Calendar)*Interval'; then
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

function enableLaunchItems {
    disabled_items="$(launchctl print-disabled user/"$(id -u)")"

    while IFS= read -r -d '' startupFile; do

        # error out if we didn't find a plist
        if [ -z "$startupFile" ]; then
            error "Could not read $1"
        fi

        # fix legacy .disabled behavior
        startupFile="$(echo "$startupFile" | sed -E 's/(\.disabled)$//')"
        disabledFile="${startupFile}.disabled"
        if [ -f "$disabledFile" ] && ! mv "$disabledFile" "$startupFile"; then
            error "could not move '$startupFile' to '$disabledFile'. Try to run with sudo?"
        fi

        name="$(basename "$startupFile" | sed -E 's/\.plist(\.disabled)*$//')"

        # check if it's disabled
        if ! echo "$disabled_items" | grep -iF "$name" | grep -q true; then
            error "$name is already enabled"
        fi

        # try to enable it
        if ! launchctl enable user/"$(id -u)"/"${name}"; then
            error "Could not enable ${STRONG}$name${NC}"
        fi

        echo -e "${GREEN}Enabled ${STRONG}${name}${NC}"

    done< <(find "${startup_dirs[@]}" "${system_dirs[@]}" \( -iname "*$1*.plist" -o -iname "*$1*.plist.disabled" \) -print0 2>/dev/null)
}

function disableLaunchItems {
    disabled_items="$(launchctl print-disabled user/"$(id -u)")"

    while IFS= read -r -d '' startupFile; do

        # error out if we didn't find a plist
        if [ -z "$startupFile" ]; then
            error "Could not find plist for $1"
        fi
        
        # fix legacy .disabled behavior
        startupFile="$(echo "$startupFile" | sed -E 's/(\.disabled)$//')"
        disabledFile="${startupFile}.disabled"
        if [ -f "$disabledFile" ] && ! mv "$disabledFile" "$startupFile"; then
            error "could not move '$startupFile' to '$disabledFile'. Try to run with sudo?"
        fi

        name="$(basename "$startupFile" | sed -E 's/\.plist(\.disabled)*$//')"

        # check if it's enabled
        if echo "$disabled_items" | grep -iF "$name" | grep -q true; then
            error "$name is already disabled"
        fi

        # try to disable it
        if ! launchctl disable user/"$(id -u)"/"${name}"; then
            error "Could not disable ${STRONG}$name${NC}"
        fi

        echo -e "${GREEN}Disabled ${STRONG}${name}${NC}"

    done< <(find "${startup_dirs[@]}" "${system_dirs[@]}" \( -iname "*$1*.plist" -o -iname "*$1*.plist.disabled" \) -print0 2>/dev/null)
}

#
#--------------------------------------------------------------------------------------------------------------------------------------
#

if [ $# -lt 1 ] || [ $# -gt 2 ]; then
    usage
fi

case "$1" in
    "list")
        if [ $# -ne 1 ] && [ $# -ne 2 ]; then
            usage
        fi

        listLoginItems "$2"
        listCronJobs "$2"
        listLaunchItems "$1" "$2"
        listKernelExtensions "$2"
        listSystemExtensions "$2"
        listPeriodic "$2"
    ;;

    "disable")
        if [ $# -ne 2 ]; then
            usage
        fi

        disableLoginItems "$2"
        disableLaunchItems "$2"
        disableKernelExtensions "$2"
        disableSystemExtensions "$2"
        disablePeriodic "$2"
    ;;

    "enable")
        if [ $# -ne 2 ]; then
            usage
        fi

        enableLaunchItems "$2"
        enableKernelExtensions "$2"
        enableSystemExtensions "$2"
        enablePeriodic "$2"
    ;;

    *)
        usage
    ;;
esac
