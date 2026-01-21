#!/usr/bin/env bash
#  ______            _   _____  ___      _____ _            _
#  | ___ \          | | / /|  \/  |     /  ___| |          | |
#  | |_/ / __ _  ___| |/ / | .  . |_   _\ `--.| | __ _  ___| | __
#  | ___ \/ _` |/ __|    \ | |\/| | | | |`--. \ |/ _` |/ __| |/ /
#  | |_/ / (_| | (__| |\  \| |  | | |_| /\__/ / | (_| | (__|   <
#  \____/ \__,_|\___\_| \_/\_|  |_/\__, \____/|_|\__,_|\___|_|\_\
#                                   __/ |
#                                  |___/
#
#   BackMySlack - incremental backups made easy using rsync and hardlinks.
#
#
############################# LICENSE ##########################################
#
#           Copyright (C) 2020  Giuseppe Molinaro (mhsalvor)
#
#      This program is free software; you can redistribute it and/or modify
#      it under the terms of the GNU General Public License as published by
#      the Free Software Foundation; either version 2 of the License, or
#      any later version.
#
#      This program is distributed in the hope that it will be useful,
#      but WITHOUT ANY WARRANTY; without even the implied warranty of
#      MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#      GNU General Public License for more details.
#
#      You should have received a copy of the GNU General Public License along
#      with this program; if not, write to the Free Software Foundation, Inc.,
#      51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
#
################################################################################
#
## Author: Giuseppe (mhsalvor) Molinaro - g.molinaro@linuxmail.org
#
## Acknowledgements:
#
# Thanks to Mikes Handy and his webpage
# http://www.mikerubel.org/computers/rsync_snapshots/
# Part of this code has been taken/adapted/inspired by his script:
# "rotating-filesystem-snapshot utility"
# Many thanks to all the people who contribued to his original script
# too (list on the Handy's webpage).
#
################################################################################

###---= Privilege and enviroment handling =---###
#
# Never allow running the whole script as root
if [[ $EUID -eq 0 && -z "$BKMS_ALLOW_ROOT" ]]; then
    echo "Do not run bkms.sh with sudo."
    echo "It will request privileges automatically when needed."
    exit 1
fi

# Resolve real user and home directory
REAL_USER="${SUDO_USER:-$USER}"
REAL_HOME="$(getent passwd "$REAL_USER" | cut -d: -f6)"

export HOME="$REAL_HOME"
export XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
export XDG_CACHE_HOME="${XDG_CACHE_HOME:-$HOME/.cache}"
export XDG_DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"

# Run commands as root only when needed
sudo_run() {
    if [[ $EUID -ne 0 ]]; then
        sudo --preserve-env=HOME,XDG_CONFIG_HOME,XDG_CACHE_HOME,XDG_DATA_HOME "$@"
    else
        "$@"
    fi
}

# One-time sudo authentication + keepalive
ensure_sudo() {
    sudo -v || exit 1
    while true; do
        sudo -n true
        sleep 60
        kill -0 "$$" || exit
    done 2>/dev/null &
}

# Ensure sudo credentials are dropped immediately on exit
cleanup_sudo() {
    sudo -K 2>/dev/null || true
}

# Authenticate once, early
ensure_sudo
# nukes sudo credentials immediately on exit
trap cleanup_sudo EXIT

###---= Strict mode + sane defaults =---###
set -Eeuo pipefail
IFS=$'\n\t'

###---= Program info =---###
readonly NAME="backMySlack"
readonly SNAME="bkms"
readonly VERSION="0.1.4-beta"

###---= Defaults =---###
readonly BEGIN=$(date +"%Y%m%d-%H%M")

ORIGIN="${PWD}"
DESTDIR=""
CONFDIR="${XDG_CONFIG_HOME:-$HOME/.config}/backmyslack"
CONFIG_FILE="${CONFDIR}/config"
LOG_FILE="${CONFDIR}/bkms.log"
EXCLUSION_FILE="${CONFDIR}/exclude.list"

IsSimulation=0
IsFirstBackup=0
EXIT=0

###---= License =---###
GPLSPLASH="
Copyright (C) 2020 Giuseppe Molinaro (mhsalvor)

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

This is free software; you can redistribuite it and/or modify it under the terms
of the GNU GPL v2 or later
"

###---= Helpers =---###
#
# Propmt creation helper
# usage: confirm "message" || exit 1
confirm() {
    local prompt="$1"
    read -r -p "${prompt} (y/N)" answer
    [[ ${answer,,} =~ ^(y|Y|s|S)$ ]]
}

log_line() {
    printf "%s | %s | %s\n" "$BEGIN" "$END" "$1" >>"$LOG_FILE"
}

# Since there are a few times this script moves things around with no output, here's a spinner
spinner() {
    local pid=$1
    local delay=0.1
    local spin='|/-\'

    tput civis
    while kill -0 "$pid" 2>/dev/null; do
        for i in {0..3}; do
            printf '\r [%c] ' "${spin:i:1}"
            sleep "$delay"
        done
    done
    printf '\r     \r'
    tput cnorm
}

###---= UI helpers =---###
line() { printf '+%*s+\n' "$(($(tput cols) - 2))" '' | tr ' ' '='; }
subline() { printf '+%*s+\n' "$(($(tput cols) - 2))" '' | tr ' ' '-'; }
errline() { printf '!!>%*s<!!\n' "$(($(tput cols) - 6))" '' | tr ' ' '-'; }
blankline() { printf '\n'; }

# Takes in a text input and writes it on stdout, centered in respect to the terminal
ctext() {
    local text="$1"
    local cols len pad
    len=${#text} # the number of characthers of text
    cols=$(tput cols)
    pad=$(((cols - len) / 2))
    printf "|%*s%s%*s|\n" "$pad" "" "$text" "$pad" ""
}

title_box() {
    line
    ctext "$*"
    line
}
subtitle_box() {
    subline
    ctext "$*"
    subline
}
error_box() {
    errline
    ctext "$*"
    errline
}

###---= Help =---###

show_help() {
    cat <<EOF
Usage: ${SNAME} [-Vhs] [-C CONFDIR || -c CONFIG_FILE] [-e EXCLUSION_FILE] [-o ORIGIN] [-l LOG_FILE] [DESTDIR]

Creates an incremental backup of ORIGIN in a directory under DESTDIR.

-C  Sets a custom configuration Directory. Default is \$XDG_CONFIG_HOME/backmyslack;
-c  Sets a custom configuration File. Default is \$XDG_CONFIG_HOME/backmyslack/config;
-e  Sets a custom exclusion file for the rsync command. A default and usually
    sufficient file is created in  \$XDG_CONFIG_HOME/backmyslack/exclude the first
    time this script is run;
-h  Displays this message amd exits;
-o  Sets a custom Origin. The value of PWD is used by default;
-l  Sets a custom logfile. Default is \$XDG_CONFIG_HOME/backmyslack/bkms.log;
-s  Simulation. Does not copy the files nor create the backup.
    Useful for testing (uses rsync dry run option);
-V  Displays version and License informations.

The Values of CONFDIR, CONFIG_FILE, EXCLUSION_FILE, ORIGIN, LOG_FILE and DESTDIR
can be changed in the config file.

Copyright (C) 2020  Giuseppe Molinaro (mhsalvor) - g.molinaro@linuxmail.org
Released under: GNU GPL v2+
EOF
}

###---= Load config if present =---###
[[ -f "${CONFIG_FILE}" ]] && source "${CONFIG_FILE}"

###---= Argument Parsing =---##
while getopts ":C:c:e:ho:l:sV" opt; do
    case ${opt} in
    C)
        CONFDIR="${OPTARG}" # Set custom config dir
        CONFIG_FILE="${CONFDIR}/config"
        LOG_FILE="${CONFDIR}/bkms.log"
        ;;
    c) CONFIG_FILE="${OPTARG}" ;;    # Set custom config file
    e) EXCLUSION_FILE="${OPTARG}" ;; # Set custom exlusion file
    h)
        show_help # Display the help message
        exit 0
        ;;
    o) ORIGIN="${OPTARG}" ;;   # Set custom backup origin
    l) LOG_FILE="${OPTARG}" ;; # Set custom logfile
    s) IsSimulation=1 ;;       # Simulation: rsync dry run
    V)
        printf "%s (%s) v%s\n%s\n" ${NAME} ${SNAME} "${VERSION}" "${GPLSPLASH}"
        exit 0
        ;; # Display version and License short blurp
    *)
        show_help
        exit 1
        ;;
    esac
done

shift $((OPTIND - 1))
# The destination is mandatory unless it's set in the config file.
# If Destdir is set in the configs, and not specified in the options, this
# preserves the default.
DESTDIR="${1:-}"

# If DESTDIR os a zero-lenght string something went wrong and we must exit.
[[ -z "${DESTDIR}" ]] && {
    echo " Destination required"
    blankline
    show_help
    exit 1
}

###---= Prepare direcories =---###
#
# Chesk if DESTDIR exist and is a directory, prompt the user before creating it
if [[ ! -d "${DESTDIR}" ]]; then
    printf "%s does not exist or is not a directory.\n" "${DESTDIR}"
    confirm "Create destination "${DESTDIR}"?" || exit 1
    mkdir -p -- "${DESTDIR}"
fi

# Check if the config directory exist, if not ask the user if he wants to create one:
if [[ ! -d "${CONFDIR}" ]]; then
    printf "%s does not exist or is not a directory.\n" "${CONFDIR}"
    confirm "Create configuration direcoty in ${CONFDIR}?" || exit 1
    mkdir -p -- "${CONFDIR}"
fi

# Check if there is an exclude file, if not, let the script know we need one.
if [[ ! -f "${EXCLUSION_FILE}" ]]; then
    cat >"${EXCLUSION_FILE}" <<EOF
/bin
/dev
/lib
/lib64
/media
/mnt
/opt
/proc
/sys
/root
/run
/sbin
/srv
/tmp
/usr
/var
gvfs-metadata
flatpack
/home/*/.gvfs
/home/*/.cache
cache
firefox-mpris
/lost+found
/*/lost+found
/home/*/Games
/games
EOF
fi

# Check if ORIGIN exists, it can be either a directory or a regular file.
[[ ! -e "${ORIGIN}" ]] && {
    echo "Origin does not exist.\n"
    exit 1
}

###---= Rsync setup =---###
#
# This will avoid word-splitting bugs
RSYNC_BASE=(
    ionice -c3 rsync
    --archive
    --human-readable
    --compress
    --delete-after
    --info=progress2,stats,name0
    --exclude-from="${EXCLUSION_FILE}"
)

RSYNC_DIFF_FLAGS=(
    --dry-run
    --itemize-changes
    --stats
    --out-format='%i|%l%n'
)

rsync_run() {
    sudo_run "${RSYNC_BASE[@]}" "$@"
}

###---= Dry-run Diff Summary =---#
dry_run_summary() {
    local tmpfile
    tmpfile="$(mktemp)"
    # confirm "Show full dry-run output?"
    # || rsync_run --dry-run "${ORIGIN}" "${CURRENT}"
    rsync_run "${RSYNC_DIFF_FLAGS[@]}" "${ORIGIN}" "${CURRENT}" >"$tmpfile"

    local create update delete bytes

    create=$(grep -cE '^\>f\+\+\+\+\+\+' "$tmpfile" || true)
    update=$(grep -cE '^\>f' "$tmpfile" || true)
    delete=$(grep -cE '^\*deleting' "$tmpfile" || true)
    bytes=$(grep -E 'total size is ' "$tmpfile" | awk '{print $4}')
    # TODO: short and configurable list of changed paths

    blankline
    subtitle_box "Dry-run"
    printf " Files to create : %s\n" "$create"
    printf " Files to update : %s\n" "$update"
    printf " Files to delete : %s\n" "$delete"
    printf " Data to transfer: %s\n" "${bytes:-0}"
    blankline

    rm -f "$tmpfile"
}

###---= Backup Rotation =---###
#
# TODO: -- Find a better way to identify directories.

readonly PREV_DIR="previous"
readonly ARCHIVE_DIR="archived"
CURRENT="${BEGIN}"

if [[ -f "$DESTDIR/.last" ]]; then
    LAST="$(cat "$DESTDIR/.last")"
else
    LAST=""
fi

rotate_backups() {
    cd "${DESTDIR}"

    if [[ -d "${LAST}" ]]; then
        if [[ -d "${PREV_DIR}" ]]; then
            if [[ -d "${ARCHIVE_DIR}" ]]; then
                sudo_run rm -rf "${ARCHIVE_DIR}" 2>/dev/null &
                spinner $!
            fi
            sudo_run mv "${PREV_DIR}" "${ARCHIVE_DIR}" &
            spinner $!
        fi
        sudo_run mv "${LAST}" "${PREV_DIR}" &
        spinner $!
        IsFirstBackup=0
    else
        IsFirstBackup=1
    fi
}

###---= Backup Execution =---###
make_backup() {
    cd "${DESTDIR}"
    if ((IsSimulation)); then
        printf "> This is a simulation\n"
        printf "  No data will be transfered and no backup will be created\n"
        blankline
        dry_run_summary &
        spinner $!
        EXIT=0
    elif ((IsFirstBackup)); then
        printf "> No previous backup found\n"
        printf "  A new backup will be created\n"
        blankline
        rsync_run "${ORIGIN}" "${CURRENT}"
        EXIT="$?"
    else
        printf "> Creating Incremental backup in %s\n" "$DESTDIR/$CURRENT"
        if [[ -d "${ARCHIVE_DIR}" ]]; then
            rsync_run --link-dest="$DESTDIR/$ARCHIVE_DIR" "${ORIGIN}" "${CURRENT}"
            EXIT="$?"
        else
            rsync_run --link-dest="$DESTDIR/$PREV_DIR" "${ORIGIN}" "${CURRENT}"
            EXIT="$?"
        fi
    fi
}

###---= MAIN =---###
#
# trap for unexpected errors
trap 'error_box "Unexpected error at line $LINENO" ' ERR

# Let the user know when the backup process is starting
blankline
title_box "Welcome to ${NAME}"
blankline
subtitle_box "Backup starting on: ${BEGIN}"
blankline

sudo_run chown root:root "${DESTDIR}"
sudo_run chmod 705 "${DESTDIR}"

if ! ((IsSimulation)); then
    confirm "Proceed with backup?" || exit 1
fi

rotate_backups

make_backup

if ! ((IsSimulation)); then
    echo "${BEGIN}" | sudo_run tee "$DESTDIR/.last" >/dev/null
    [[ -d $DESTDIR/$CURRENT ]] && echo "${BEGIN}" |
        sudo_run tee "$DESTDIR/$CURRENT/.age" >/dev/null
fi

sudo_run chmod 505 "${DESTDIR}"

END="$(date +'%Y%m%d-%H%M')"
subtitle_box "Backup finished at: $END"

###---= Exit Status Handling =---###
case "$EXIT" in
0) ES="Success" ;;
*) ES="ERROR ($EXIT)" ;;
esac

log_line "$ES"

title_box "Operation completed: $ES"
exit "$EXIT"

# TODO: add retention policy
