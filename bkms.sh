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
# Author: Giuseppe (mhsalvor) Molinaro - g.molinaro@linuxmail.org
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

# Propmt creation helper
# usage: confirm "message" || exit 1
confirm() {
    local propmpt="$1"
    read -r -p "${prompt} (y/N)" answer
    [[ ${answer,,} =~ ^(y|Y|s|S)$ ]]
}

require_root() {
    ((EUID == 0)) || {
        error_box "Only root can do this"
        exit 1
    }
}


log_line() {
    printf "%s | %s | %s\n" "$BEGIN" "END" "$1" >>"$LOG_FILE"
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
line()      { printf '+%*s+\n' "$(( $(tput cols) -2 ))" '' | tr ' ' '='; }
subline()   { printf '+%*s+\n' "$(( $(tput cols) -2 ))" '' | tr ' ' '-'; }
errline()   { printf '!!>%*s<!!\n' "$(( $(tput cols) -6 ))" '' | tr ' ' '-';}
blankline() {printf '\n';}

# Takes in a text input and writes it on stdout, centered in respect to the terminal
ctext() {
    local text="$1"
    local cols len pad 
    len=${#text} # the number of characthers of text
    cols=$(tput cols)
    pad=$(( (cols - len) / 2 ))
    printf "|%*s%s%*s|\n" "$pad" "" "$text" "$pad" ""
}

title_box()     { line; ctext "$*"; line; }
subtitle_box()  { subline; ctext "$*"; subline; }
error_box()     { errline; ctext "$*"; errline; }

###---= Help =---###

show_help {
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
        C)  CONFDIR="${OPTARG}" # Set custom config dir
            CONFIG_FILE="${CONFDIR}/config"
            LOG_FILE="${CONFDIR}/bkms.log" ;;
        c)  CONFIG_FILE="${OPTARG}" ;;    # Set custom config file
        e)  EXCLUSION_FILE="${OPTARG}" ;; # Set custom exlusion file
        h)  show_help # Display the help message
            exit 0 ;;
        o)  ORIGIN="${OPTARG}" ;;   # Set custom backup origin
        l)  LOG_FILE="${OPTARG}" ;; # Set custom logfile
        s)  IsSimulation=1 ;;       # Simulation: rsync dry run
        V)  printf "%s (%s) v%s\n%s\n" ${NAME} ${SNAME} "${VERSION}" "${GPLSPLASH}"
            exit 0 ;; # Display version and License short blurp
        *)  show_help; exit 1 ;;
    esac
done

shift $((OPTIND - 1))
# The destination is mandatory unless it's set in the config file.
# If Destdir is set in the configs, and not specified in the options, this
# preserves the default.
DESTDIR="${1:-}"

# If DESTDIR os a zero-lenght string something went wrong and we must exit.
[[ -z "${DESTDIR}" ]] && { echo " Destination required"; exit 1; }

--------------------------------------------------------------------------------
###---= Add trap to catch Errors
trap 'error_box "unexpected error at line $LINENO"; close_destdir || true' ERR

readonly PREV_DIR="previous"
readonly OLD_DIR="old"
readonly ARCHIVE_DIR="archived"


# Now we can be sure that DESTDIR is set and we can chesk if it's a valid dir
if [[ ! -d "${DESTDIR}" ]]; then
    printf "%s does not exist or is not a directory.\n" "${DESTDIR}"
    read -r -p " Do you want to create it? (y/N) " answer
    case ${answer,,} in
    y | Y | s | S) mkdir -p -- "${DESTDIR}" ;;
    *)
        printf "Nothing to do."
        exit 1
        ;;
    esac
fi

###---= Configuration and Initializiation =---###

# Check if the config directory exist, if not ask the user if he wants to create one:
if [[ ! -d "${CONFDIR}" ]]; then
    printf " %s does not exist or is not a directory.\n" "${CONFDIR}"
    read -r -p " Do you want to create it? (y/N) " answer
    case ${answer:0:1} in
    y | Y | s | S) mkdir -p "${CONFDIR}" ;;
    *)
        echo " Leaving..."
        exit 1
        ;;
    esac
fi

# Check if there is an exclude file, if not, let the script know we need one.
[[ -f "${EXCLUSION_FILE}" ]] || printf \
    "/bin
/dev
/home/*/.gvfs
/home/*/.cache
/lib
/lib64
/lost+found
/*/lost+found
/media
/mnt
/opt
/proc
/root
/run
/sbin
/srv
/sys
/tmp
/usr
/var" >"${EXCLUSION_FILE}"

# Check if ORIGIN exists, it can be either a directory or a regular file.
[[ ! -e "${ORIGIN}" ]] && (echo -e "${ORIGIN} does not exist.\n Leaving ..." && exit 1)

###---= Rsync set up =---###
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

rsync_run() {
    "${RSYNC_BASE[@]}" "$@"
}

# Exambple: simulation
# rsync_run --dry-run "$ORIGIN" "$CURRENT"



# Check if a previous backup is present in DESTDIR. If none is found, mark the current one.
function check_last {
    if [[ -f "${DESTDIR}/.last" ]]; then
        PREV=$(cat "${DESTDIR}/.last")
    else
        echo "${BEGIN}" >"${DESTDIR}/.last"
    fi

}

# Change permissions of DESTDIR.
# To preserve the backup form tampering and accidental data loss, only Root should
# have write permissions here. And only While the script is running.
# I will revoke every w permission at the end.
function check_destdir {
    if [[ -d ${DESTDIR} ]]; then
        printf "> Your data will be saved inside %s\n" "${DESTDIR}"
        printf "> Root should have ownership and exclusive write permission on this container...\n"
        blankline
        chown root:root "${DESTDIR}" && chmod 705 "${DESTDIR}"
    else
        blankline
        error_box "Destination not found. Exiting..."
        blankline
        exit 1
    fi
}

# After we finish, the write permission should be revoked
function close_destdir {
    echo "> Nobody should be able nor need to write on this..."
    blankline
    chown root:root "${DESTDIR}" && chmod 505 "${DESTDIR}"
}

# TODO -- Find a better way to identify directories.
# CURRENT : =BEGIN - is the new backup being made
# PREV : =DESTDIR/.last Is the previous backup, likely the one we want to hardlink to.
# OLD :  =DESTDIR/old The second oldest backup. PREV will be moved to this when a new backup is created
# ARCHIVE : =DESTDIR/archived The oldest kept backup. OLD will be moved here and the last archive will be deleted
#           when a new backup is created.
#
# if PREV exist, check for OLD
#   if OLD exist, check for ARCHIVE
#       if ARCHIVE exist
#       remove it
#   move OLD to ARCHIVE
# move PREV to OLD
# create CURRENT with hardlinks to PREV
#else
# create a new CURRENT.

function rotate_backups {
    check_last
    if [[ -d "${PREV}" ]]; then
        if [[ -d "${OLD}" ]]; then
            if [[ -d "${ARCHIVE}" ]]; then
                ageArch=$(cat "${ARCHIVE}/.age")
                printf "> Removing archived %s backup...\n" "${ageArch}"
                rm -rf "${ARCHIVE}" &
                spinner $!
            fi
            ageOld=$(cat "${OLD}/.age")
            printf "> Moving old %s backup to archived...\n" "${ageOld}"
            mv "${OLD}" "${ARCHIVE}" &
            spinner $!
        fi
        agePrev=$(cat "${PREV}/.age")
        printf "> Previous backup was made on %s\n Moving it to old...\n" "${agePrev}"
        echo "${PREV}" >"${PREV}/.age"
        mv "${PREV}" "${OLD}" &
        spinner $!
        IsFirstBackup=0
    else
        printf "> No previous backups found in %s\n> A full backup will be created." "${DESTDIR}"
        IsFirstBackup=1
    fi
}

function make_linkedBk {
    printf "> Creating Incremental backup: %s\n" "${CURRENT}"
    blankline
    ${RSYNC_CMD} --link-dest="../${OLD}" "${ORIGIN}" "${CURRENT}" #link-dest is relative to target
    EXIT=$?
}

function make_newBk {
    printf "> No previous backups found."
    printf "> A full backup will be created.\n"
    blankline
    ${RSYNC_NEW} "${ORIGIN}" "${CURRENT}"
    EXIT=$?

}

function make_simBk {
    ${RSYNC_SIM} "${ORIGIN}" "${CURRENT}"
    EXIT=$?
}

function make_Bk {
    if ((IsFirstBackup == 0)); then
        make_linkedBk
    else
        make_newBk
    fi
}

###==== MAIN ====####

# Let the user know when the backup process is starting
blankline
title_box "Welcome to ${NAME}"
blankline
subtitle_box "Backup starting on: ${BEGIN}"
blankline

# make sure we're running as root
echo -e "> Checking for root..."
check_root

# Change permissions and move to workdir:
echo -e "> Checking target...\n"
check_destdir

# Check for previous backups, and populate the history.
# Also, register the exit status of rsync for the logfile and error detection.
echo -e "> Looking for previous backups..."
CURRENT="${BEGIN}"
OLD="previous"
ARCHIVE="archived"
cd "${DESTDIR}" || exit 1
rotate_backups
blankline

# Starting proper backup procedure:
if ((IsSimulation == 1)); then
    printf " This is a simulation, no data will be tranfered and no backup will be created\n"
    make_simBk
else
    total=$(${RSYNC_SIM} "${ORIGIN}" "${CURRENT}" | grep "total size" | awk '{print $4}')
    printf " %s of data will be copied to %s\n" "${total}" "${CURRENT}"
    read -r -p " Do you want to proceed? (y/N) " answer
    case ${answer:0:1} in
    y | Y | s | S) make_Bk ;;
    *)
        echo " Leaving ..."
        exit 1
        ;;
    esac
fi

# Update the last backup file.
echo -e "${BEGIN}" >"${DESTDIR}/.last"
echo -e "${BEGIN}" >"${CURRENT}/.age"
blankline
echo -e "> Closing Backup container..."
close_destdir

# Prafaring for final feedback and logging
END=$(date +"%Y%m%d-%H%M")
subtitle_box "Backup procedure ended at ${END}"
blankline

###---= Feedback and Logfile =---###

# Interprets the rsync exit code
case "$EXIT" in
0) ES="Success" ;;
1) ES="ERROR: 1 - Syntax or usage error" ;;
2) ES="ERROR: 2 - Protocol incompatibility" ;;
3) ES="ERROR: 3 - Errors selecting input/output files, dirs" ;;
4) ES="ERROR: 4 - Requested  action  not supported" ;;
5) ES="ERROR: 5 - Error starting client-server protocol" ;;
6) ES="ERROR: 6 - Daemon unable to append to log-file" ;;
10) ES="ERROR: 10 - Error in socket I/O" ;;
11) ES="ERROR: 11 - Error in file I/O" ;;
12) ES="ERROR: 12 - Error in rsync protocol data stream" ;;
13) ES="ERROR: 13 - Errors with program diagnostics" ;;
14) ES="ERROR: 14 - Error in IPC code" ;;
20) ES="ERROR: 20 - Received SIGUSR1 or SIGINT" ;;
21) ES="ERROR: 21 - Some error returned by waitpid()" ;;
22) ES="ERROR: 22 - Error allocating core memory buffers" ;;
23) ES="ERROR: 23 - Partial transfer due to error" ;;
24) ES="ERROR: 24 - Partial transfer due to vanished source files" ;;
25) ES="ERROR: 25 - The --max-delete limit stopped deletions" ;;
30) ES="ERROR: 30 - Timeout in data send/receive" ;;
35) ES="ERROR: 35 - Timeout waiting for daemon connection" ;;
*) ES="ERROR: ?? - An Unknown Error as occurred" ;;
esac

# Appends a new line to the logfile:
printf "%s | %s | %s\n" "${BEGIN}" "${END}" "${ES}" >>"${LOG_FILE}"

# ----------- real time feedback ----------------------------------------------#
# shows last logfile lines.
MSG=$(tail -n1 "${LOG_FILE}")
title_box "Operation completed: %s" "${MSG}"
# and that's it
exit 0
