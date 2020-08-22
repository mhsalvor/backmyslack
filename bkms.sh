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
#               BackMySlack - incremental backups made easy using rsync and
#                             hardlinks.
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
# Most of this code has been taken/adapted/inspired by his script:
# "rotating-filesystem-snapshot utility"
# Many thanks to all the people who contribued to his original script
# too (list on the Handy's webpage).

###---= Program maning and verion =---###

NAME="backMySlack"
SNAME="bkms"
VERSION="0.3b1 beta"

# Licence Informations:
GPLSPLASH="\nCopyright (C) 2020  Giuseppe Molinaro (mhsalvor)\n\n
  This program is distributed in the hope that it will be useful,\n
  but WITHOUT ANY WARRANTY; without even the implied warranty of\n
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.\n
  This is free software, and you are welcome to\n
  redistribute it under certain conditions;\n
  See the LICENSE files provided with this script\n
  Ot the GNU General Public Licence for more details.\n"

###---= Defaults =---###

ORIGIN="${PWD}"
DESTDIR=" "
CONFDIR="${XDG_CONFIG_HOME}/backmyslack"
CONFIG_FILE="${CONFDIR}/config"
LOG_FILE="${CONFDIR}/bkms.log"
EXCLUSION_FILE="${CONFDIR}/exclude"

BEGIN=$(date +"%Y%m%d-%H%M")
CURRENT=${BEGIN}

IsSimulation=0
IsFirstBackup=0

###---= User Preferences =---###

# Check if the config directory exist, if not create one:
[[ -d "${CONFDIR}" ]] || mkdir -p ${CONFDIR}

# If present, source the "config" file and overwrite the defaults
[[ -f "${CONFIG_FILE}" ]] && source ${CONFIG_FILE}

###---= Command line Flags =---###

function show_help() {
    cat << EOF
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

while getopts ":C:c:e:ho:l:sVv" option; do
    case ${option} in
        C) CONFDIR=${OPTARG};;          # Set custom config dir
        c) CONFIG_FILE=${OPTARG};;      # Set custom config file
        e) EXCLUSION_FILE=${OPTARG};;   # Set custom exlusion file
        h) show_help                    # Display the help message
            exit 0;;
        o) ORIGIN=${OPTARG};;           # Set custom backup origin
        l) LOG_FILE=${OPTARG};;         # Set custom logfile
        s) IsSimulation=1;;             # Simulation: rsync dry run
        V) echo -e "${NAME}: ${SNAME} "v"${VERSION}\n" ${GPLSPLASH}
            exit 0;;                   # Display version and License short blurp
        v) show_help                    #TODO : Implement "verbose" mode.
            exit 0;;
        \?) printf "%s: invalid option: -%c\n", ${SNAME}, ${OPTARG}
            exit 1;;
        :) printf "%s: option -%c requires and argument.\n ", ${SNAME}, ${OPTARG}
            exit 1;;
    esac
done
# The destination is mandatory unless it's set in the config file.
shift $(( $OPTIND - 1 ))
[[ "$1" ]] && DESTDIR=$1

###---= Configuration and Initializiation =---###

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
/var" > ${EXCLUSION_FILE}

# Find the older backups
[[ -f "${DESTDIR}/old" ]] && OLD="${DESTDIR}/old"
[[ -f "${DESTDIR}/archived" ]] && ARCHIVE="${DESTDIR}/archived"

###---= Rsync set up =---###

RSYNC_CMD="ionice -c3 rsync"    # Don't stress the system
RSYNC_OPT="-azhv --info=progress2,stats --info=name0 --del --exclude-from=${EXCLUSION_FILE}"
RSYNC_SIM="${RSYNC_OPT} --dry-run"


#TODO=$($RSYNC_CMD $RSYNC_SYM "$ORIG"/ "$DESTDIR"/$NEW/ \
#       |grep "^Number of regular files transferred:" | awk '{print $6}' )
#TODO=$(du -s $ORIG | cut -f1)
#echo $TODO
#exit
  $RSYNC_CMD $RSYNC_OPT "$ORIG"/ "$DESTDIR"/"$NEW"/
#| pv -s "$TODO"
  EXIT=$($ECHO_CMD $?)
fi
# Update the last backup file.
$ECHO_CMD $NEW>"$LOGDIR"/last
blankline

#BUFFER_CMD="stdbuf -oL awk 'BEGIN { RS="\r" } /%/ { print $1" " $2 }' > /tmp/progress.txt"
# columns 2 and 3
#rsync --info=progress2,stats /path/to/source /path/to/target/ | stdbuf -oL awk 'BEGIN { RS="\r" } /%/ { print $1" "$2 }' > /tmp/progress.txt
# example output
#2% 100.08MB/s

 # RSYNC="ionice -c3 rsync"
 # # don't use --progress
 # RSYNC_ARGS="-vrltD --delete --stats --human-readable"
 # SOURCES="/dir1 /dir2 /file3"
 # TARGET="storage::storage"
# echo "Executing dry-run to see how many files must be transferred..."
# TODO=$(${RSYNC} --dry-run ${RSYNC_ARGS} ${SOURCES} ${TARGET}|grep "^Number of files transferred"|awk '{print $5}')
# ${RSYNC} ${RSYNC_ARGS} ${SOURCES} ${TARGET} | pv -l -e -p -s "$TODO"

# progress = current_transfered*100/total_transfer(sim)

#### # # % rsync -avvz --times --stats --checksum --human-readable --acls \
#### # #     --itemize-changes --progress \
#### # #     --out-format='[%t] [%i] (Last Modified: %M) (bytes: %-10l) %-100n' \
#### # #     /usr/include/glib-2.0 my-glib-copy/
#### # he switches breakdown as follows:
####     -avvz = archive, verbose x 2, compress
####     --times = preserve modification times
####     --stats = give some file-transfer stats
####     --checksum = skip based on checksum, not mod-time & size
####     --human-readable = output numbers in a human-readable format
####     --acls = preserve ACLs (implies -p)
####     --itemize-changes = output a change-summary for all updates
####     --progress = show progress during transfer
####     --out-format='[%t] [%i] (Last Modified: %M) (bytes: %-10l) %-100n'
####         %t = current date time
####         %i = an itemized list of what is being updated
####         %M = the last-modified time of the file
####         %-10l = the length of the file in bytes (-10 is for alignment and precision)
####         %-100n = the filename (short form; trailing "/" on dir) (-100 is for alignment and precision)
####
#### NOTE: See the man pages for rsync and rsyncd.conf for full details on the above switches.
####
###The above command produces the following transcript:
###sending incremental file list
###delta-transmission disabled for local transfer or --whole-file
###[2012/12/23 21:34:46] [cd+++++++++] (Last Modified: 2010/12/19-08:13:31) (bytes: 4096      ) glib-2.0/
###[2012/12/23 21:34:46] [>f+++++++++] (Last Modified: 2010/09/30-15:02:30) (bytes: 1511      ) glib-2.0/glib-object.h
###       1.51K 100%    0.00kB/s    0:00:00
###       1.51K 100%    0.00kB/s    0:00:00 (xfer#1, to-check=181/183)
###[2012/12/23 21:34:46] [>f+++++++++] (Last Modified: 2010/09/30-15:02:30) (bytes: 2910      ) glib-2.0/glib.h
###       2.91K 100%    2.78MB/s    0:00:00
###       2.91K 100%    2.78MB/s    0:00:00 (xfer#2, to-check=180/183)
###[2012/12/23 21:34:46] [>f+++++++++] (Last Modified: 2010/09/30-15:02:31) (bytes: 3613      ) glib-2.0/gmodule.h
###       3.61K 100%    3.45MB/s    0:00:00
###       3.61K 100%    3.45MB/s    0:00:00 (xfer#3, to-check=179/183)
###...
###...
###[2012/12/23 21:34:46] [>f+++++++++] (Last Modified: 2010/09/30-15:02:31) (bytes: 8431      ) glib-2.0/gobject/gvaluecollector.h
###       8.43K 100%  141.96kB/s    0:00:00
###       8.43K 100%  141.96kB/s    0:00:00 (xfer#178, to-check=1/183)
###[2012/12/23 21:34:46] [>f+++++++++] (Last Modified: 2010/09/30-15:02:31) (bytes: 8507      ) glib-2.0/gobject/gvaluetypes.h
###       8.51K 100%  143.23kB/s    0:00:00
###       8.51K 100%  143.23kB/s    0:00:00 (xfer#179, to-check=0/183)
###total: matches=0  hash_hits=0  false_alarms=0 data=1305506
###
##rsync[2996] (sender) heap statistics:
##  arena:         540672   (bytes from sbrk)
##  ordblks:            3   (chunks not in use)
##  smblks:             7
##  hblks:              2   (chunks from mmap)
##  hblkhd:        401408   (bytes from mmap)
##  allmem:        942080   (bytes from sbrk + mmap)
##  usmblks:            0
##  fsmblks:          592
##  uordblks:      404784   (bytes used)
##  fordblks:      135888   (bytes free)
##  keepcost:      134240   (bytes in releasable chunk)
##
#rsync[2999] (server receiver) heap statistics:
#  arena:         286720   (bytes from sbrk)
#  ordblks:            2   (chunks not in use)
#  smblks:             8
#  hblks:              3   (chunks from mmap)
#  hblkhd:        667648   (bytes from mmap)
#  allmem:        954368   (bytes from sbrk + mmap)
#  usmblks:            0
#  fsmblks:          672
#  uordblks:      174480   (bytes used)
#  fordblks:      112240   (bytes free)
#  keepcost:      102352   (bytes in releasable chunk)
##
#rsync[2998] (server generator) heap statistics:
#  arena:         233472   (bytes from sbrk)
#  ordblks:            4   (chunks not in use)
#  smblks:             6
#  hblks:              2   (chunks from mmap)
#  hblkhd:        401408   (bytes from mmap)
#  allmem:        634880   (bytes from sbrk + mmap)
#  usmblks:            0
#  fsmblks:          448
#  uordblks:       83152   (bytes used)
#  fordblks:      150320   (bytes free)
#  keepcost:      131120   (bytes in releasable chunk)
##
#Number of files: 183
#Number of files transferred: 179
#Total file size: 1.31M bytes
#Total transferred file size: 1.31M bytes
#Literal data: 1.31M bytes
#Matched data: 0 bytes
#File list size: 6.30K
#File list generation time: 0.001 seconds
#File list transfer time: 0.000 seconds
#Total bytes sent: 350.39K
#Total bytes received: 3.43K
##
#sent 350.39K bytes  received 3.43K bytes  707.64K bytes/sec
#total size is 1.31M  speedup is 3.69
#--------------------------------------------------------------------
# Generates a thick line for the main banners, detects terminal width at creation
function line {
  local ncol=$($TPUT_CMD cols)
  local count=2
  printf "+"
    while [  $count -lt $ncol ]; do
      printf "="
      let count++
    done
  printf "+\n"
}

# Generates a thin line for secondary banners, detects terminal width at creation
function subline {
  local ncol=$($TPUT_CMD cols)
  local count=2
  printf "+"
    while [ $count -lt $ncol ]; do
      printf "-"
      let count++
    done
  printf "+\n"
}

# Generates a special frame for error banners, detects terminal width at creation
function errline {
  local ncol=$($TPUT_CMD cols)
  local count=6
  printf "!!>"
    while [ $count -lt $ncol ]; do
     printf "-"
     let count++
    done
  printf "<!!\n"
}

# Just a void line: yes, I'm lazy this way.
function blankline {
  $ECHO_CMD ""
}

# Takes in a text input and writes it on stdout, centered in respect to the terminal
function ctext() {
  local text=$1
  local tlen=${#text}
  local ncol=$($TPUT_CMD cols)
  local head=$((($tlen+$ncol-1)/2))
  local tail=$((($ncol-$tlen)/2))
  $PRINTF_CMD "|%*s" $head "$text"
  $PRINTF_CMD "%*s\n" $tail "|"
}

# Since there are a few times this script moves things around with no output, here's a spinner
function spinner() {
  $TPUT_CMD civis; # turns the cursor invisible
  local pid=$1
  local delay=0.05
    while [ $($PS_CMD -eo pid | $GREP_CMD $pid) ]; do
      for i in \| / - \\; do
       $PRINTF_CMD ' [%c]\b\b\b\b' $i
       $SLEEP_CMD $delay
      done
    done
  $PRINTF_CMD '\b\b\b\b'
  $TPUT_CMD cnorm; #turns the cursor visible again
}

#------------------Script's Body ----------------------------------------------#

# Let the user know when the backup process is starting
BEGIN=$($DATE_CMD "+%a %x %X")
line
ctext "Backup starting on: $BEGIN"
line
blankline
$ECHO_CMD "# $SNAME-$VERSION"
blankline

# make sure we're running as root
$ECHO_CMD "# Checking for root..."
if [[ $($ID_CMD -u) != 0 ]]; then
  {
    blankline
    errline
    ctext "!! Sorry, must be root.  Aborting !!";
    errline
    blankline
    exit
  }
else
  $ECHO_CMD " > OK"
  blankline
fi

# Change permissions and move to workdir:
if [ -d $DESTDIR ]; then
  $ECHO_CMD "# Fixing permissions..."
  $CHOWN_CMD root:root $DESTDIR && $CHMOD_CMD 705 $DESTDIR
  $ECHO_CMD "# Moving to workdir: $DESTDIR ..."
  cd $DESTDIR
  blankline
else
  blankline
  errline
  ctext "!! $DESTDIR Not Found. Aborting !!"
  errline
  blankline
  exit
fi

# Starting proper backup procedure:

# Check for previous backups, and populate the history.
#  If a previos, non "old", backup exist,
#  rename it to old and make a hard-link-only (except for dirs)
#  copy to Initialize the current back up.
#  If No previous backup exist, create an empy dir for the current one.
# Also, register the exit status of rsync for the logfile and error detection.
$ECHO_CMD "# Looking for previous backups..."
if [ -d "$OLDDIR" ]; then
  if [ -d old ]; then
    if [ -d archive ]; then
     AGE=$($CAT_CMD archive/AGE.TXT)
     $ECHO_CMD -e " > Obsolete archive found: $AGE\n    removing it..."
     $RM_CMD -r archive & spinner $!
    fi
   AGE=$($CAT_CMD old/AGE.TXT)
   $ECHO_CMD -e " > Old backup found: $AGE\n    moving it to archive..."
   $MV_CMD old archive & spinner $!
  fi
 $ECHO_CMD " > Last backup: $OLDBK"
 $MV_CMD "$OLDDIR" old & spinner $!
 $ECHO_CMD $OLDBK>old/AGE.TXT
 $ECHO_CMD " > Creating Incremental backup in: $NEW ..."
 blankline
 $RSYNC_CMD $RSYNC_OPT --link-dest="$DESTDIR"/old "$ORIG"/ "$DESTDIR"/$NEW/
 EXIT=$($ECHO_CMD $?)
else
  $ECHO_CMD " > No previous backups found."
  $ECHO_CMD " > A full backup will be created."
  blankline
  $RSYNC_CMD $RSYNC_OPT "$ORIG"/ "$DESTDIR"/$NEW/
  EXIT=$($ECHO_CMD $?)
fi
# Update the last backup file.
$ECHO_CMD $NEW>"$LOGDIR"/last
blankline

$ECHO_CMD "# Fixing Permissions..."
$CHOWN_CMD root:root $DESTDIR && $CHMOD_CMD 505 $DESTDIR
END=$($DATE_CMD +%X)
$ECHO_CMD "# Backup procedure ended, preparing for feedback..."
blankline


function line {
  local ncol=$($TPUT_CMD cols)
  local count=2
  printf "+"
    while [  $count -lt $ncol ]; do
      printf "="
      let count++
    done
  printf "+\n"
}

function subline {
  local ncol=$($TPUT_CMD cols)
  local count=2
  printf "+"
    while [ $count -lt $ncol ]; do
      printf "-"
      let count++
    done
  printf "+\n"
}

function errline {
  local ncol=$($TPUT_CMD cols)
  local count=6
  printf "!!>"
    while [ $count -lt $ncol ]; do
     printf "-"
     let count++
    done
  printf "<!!\n"
}

function blankline {
  $ECHO_CMD ""
}


function ctext() {
  local text=$1
  local tlen=${#text}
  local ncol=$($TPUT_CMD cols)
  local head=$((($tlen+$ncol-1)/2))
  local tail=$((($ncol-$tlen)/2))
  $PRINTF_CMD "|%*s" $head "$text"
  $PRINTF_CMD "%*s\n" $tail "|"
}

function spinner() {
  $TPUT_CMD civis;
  local pid=$1
  local delay=0.05
    while [ $($PS_CMD -eo pid | $GREP_CMD $pid) ]; do
      for i in \| / - \\; do
       $PRINTF_CMD ' [%c]\b\b\b\b' $i
       $SLEEP_CMD $delay
      done
    done
  $PRINTF_CMD '\b\b\b\b'
  $TPUT_CMD cnorm;
#debug entry, please remove
#  $PRINTF_CMD "PIPPO"
}



###---= Functions =---###

function line {
  COUNTER=0
  printf "+"
    while [  $COUNTER -lt 80 ]; do
      printf "="
      let COUNTER=COUNTER+1
    done
  printf "+\n"
}

function subline {
  COUNTER=0
  printf "+"
    while [ $COUNTER -lt 80 ]; do
      printf "-"
      let COUNTER=COUNTER+1
    done
  printf "+\n"
}

function errline {
  COUNTER=0
  printf "!!>"
    while [ $COUNTER -lt 76 ]; do
     printf "-"
     let COUNTER=COUNTER+1
    done
  printf "<!!\n"
}

function blankline {
  echo ""
}

# Check if a previous backup is present in DESTDIR. If none is found, mark the current one.
function check_last() {
    [[ ! -f "${DESTDIR}/.last" ]] && echo ${BEGIN}>"${DESTDIR}/.last"
    PREV=$(cat "${DESTDIR}/.last")
}

function check_root() {
    if (( $(id -u) != 0 )) ; then
        {
            blankline
            errline
            echo "!! Only Root can do this."
            errline
            blankline
            exit 1
        }
     else
        {
            echo "> OK"
            blankline
        }
    fi
}

# Change permissions of DESTDIR.
# To preserve the backup form tampering and accidental data loss, only Root should
# have write permissions here. And only While the script is running.
# I will revoke every w permission at the end.
function check_destdir() {
    if [[ -d ${DESTDIR} ]] ; then
        {
            printf "# Your data will be saved inside %s\n", ${DESTDIR}
            printf "# Root should have ownership and exclusive write permission on this container..."
            chown root:root ${DESTDIR} && chmod 705 ${DESTDIR}
        }
    else
        {
            blankline
            errline
            printf " !! Destination not found. Exiting..."
            blankline
            errline
            exit 1
        }
    fi
}

# After we finish, the write permission should be revoked
function close_destdir() {
    echo "# Nobody should be able nor need to write on this..."
    chown root:root ${DESTDIR} && chmod 505 ${DESTDIR}
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

function rotate_backups() {
    if [[ -d ${PREV} ]] ; then
        {
            if [[ -d ${OLD} ]] ; then
                {
                    if [[ -d ${ARCHIVE} ]] ; then
                        {
                            ageArch=$(cat "${ARCHIVE}/.age")
                            printf " > Removing archived %s backup...", ${ageArch}
                            rm -rf ${ARCHIVE}
                        }
                    fi

                    ageOld=$(cat "${OLD}/.age")
                    printf " > Moving old %s backup to archived...", ${ageOld}
                    mv ${OLD} ${ARCHIVE}
                }
            fi

            agePrev=$(cat "${PREV}/.age")
            printf " Previous backup was made on %s\n Moving it to old...", ${agePrev}
            echo ${PREV} > "${PREV}/.age"
            mv ${PREV} ${OLD}
            IsFirstBackup=0
        }
    else
        {
            printf " No previous backups found in %s\n> A full backup will be created.", ${DESTDIR}
            IsFirstBackup=1
        }
    fi
}

function make_linkedBk() {
    printf " > Creating Incremental backup: %s\n", ${CURRENT}
    blankline
    ${RSYNC_CMD} ${RSYNC_OPT} --link-dest="${OLD}" "${ORIGIN}" "${CURRENT}"
    EXIT=$(echo $?)
    return ${EXIT}
}

function make_newBk() {
  $ECHO_CMD "# No previous backups found."
  $ECHO_CMD " > A full backup will be created."
  blankline
  $RSYNC_CMD $RSYNC_OPT "$ORIG"/ "$DESTDIR"/$NEW/
  EXIT=$($ECHO_CMD $?)





###---= Main =---###
BEGIN=$($DATE_CMD "+%a %x %X")
line
ctext "Backup starting on: $BEGIN"
line
blankline
$ECHO_CMD "# $SNAME-$VERSION"
blankline
$ECHO_CMD "# Looking for previous backups..."
if [ -d "$OLDDIR" ]; then
  if [ -d old ]; then
    if [ -d archive ]; then
     AGE=$($CAT_CMD archive/AGE.TXT)
     $ECHO_CMD -e " > Obsolete archive found: $AGE\n    removing it..."
     $RM_CMD -r archive & spinner $!
    fi
   AGE=$($CAT_CMD old/AGE.TXT)
   $ECHO_CMD -e " > Old backup found: $AGE\n    moving it to archive..."
   $MV_CMD old archive & spinner $!
  fi
 $ECHO_CMD " > Last backup: $OLDBK"
 $MV_CMD "$OLDDIR" old & spinner $!
 $ECHO_CMD $OLDBK>old/AGE.TXT
 $ECHO_CMD " > Creating Incremental backup in: $NEW ..."
 blankline
 $RSYNC_CMD $RSYNC_OPT --link-dest="$DESTDIR"/old "$ORIG"/ "$DESTDIR"/$NEW/
 EXIT=$($ECHO_CMD $?)
else
  $ECHO_CMD " > No previous backups found."
  $ECHO_CMD " > A full backup will be created."
  blankline
  $RSYNC_CMD $RSYNC_OPT "$ORIG"/ "$DESTDIR"/$NEW/
  EXIT=$($ECHO_CMD $?)
fi
# Update the last backup file.
$ECHO_CMD $NEW>"$LOGDIR"/last
blankline

$ECHO_CMD "# Fixing Permissions..."
$CHOWN_CMD root:root $DESTDIR && $CHMOD_CMD 505 $DESTDIR
END=$($DATE_CMD +%X)
$ECHO_CMD "# Backup procedure ended, preparing for feedback..."
blankline

# make sure we're running as root
$ECHO_CMD "# Checking for root..."
if [[ $($ID_CMD -u) != 0 ]]; then
  {
    blankline
    errline
    ctext "!! Sorry, must be root.  Aborting !!";
    errline
    blankline
    exit
  }
else
  $ECHO_CMD " > OK"
  blankline
fi

# Change permissions and move to workdir:
if [ -d $DESTDIR ]; then
  $ECHO_CMD "# Fixing permissions..."
  $CHOWN_CMD root:root $DESTDIR && $CHMOD_CMD 705 $DESTDIR
  $ECHO_CMD "# Moving to workdir: $DESTDIR ..."
  cd $DESTDIR
  blankline
else
  blankline
  errline
  ctext "!! $DESTDIR Not Found. Aborting !!"
  errline
  blankline
  exit
fi

# Let the user know when the backup process is starting
BEGIN=$($DATE_CMD "+%a %x %X")
line
$ECHO_CMD "|   Backup starting on "$BEGIN" "
line
blankline
$ECHO_CMD "# "$SNAME"-"$VERSION
blankline

# Let the user know when the backup process is starting
check_last
# make sure we're running as root
echo "Checking for root..."
check_root
echo " Checking for destination..."
check_destdir
cd ${DESTDIR}

# Starting proper backup procedure:


# Check for pre vious backups, and populate the history.
#  If a previous, non "old", backup exist,
#  rename it to old and make a hard-link-only (except for dirs)
#  copy to Initialize the current back up.
#  If No previous backup exist, create an empy dir for the current one.
# Also, register the exit status of rsync for the logfile and error detection.
echo "# Looking for previous backups..."
if [ -d "$OLDDIR" ]; then
make_linkedBk

else
make_newBk
fi
# Update the last backup file.
$ECHO_CMD $NEW>"$DESTDIR"/last
blankline

close_destdir
END=$($DATE_CMD +%X)
$ECHO_CMD "# Backup procedure ended, preparing for feedback..."
blankline

#--------------- logfile creation ---------------------------------------------#

# let's check the meaning of that exit status...
case "$EXIT" in
	0) ES="Success";;
	1) ES="ERROR: 1 - Syntax or usage error";;
	2) ES="ERROR: 2 - Protocol incompatibility";;
	3) ES="ERROR: 3 - Errors selecting input/output files, dirs";;
	4) ES="ERROR: 4 - Requested  action  not supported";;
	5) ES="ERROR: 5 - Error starting client-server protocol";;
	6) ES="ERROR: 6 - Daemon unable to append to log-file";;
	10) ES="ERROR: 10 - Error in socket I/O";;
	11) ES="ERROR: 11 - Error in file I/O";;
	12) ES="ERROR: 12 - Error in rsync protocol data stream";;
	13) ES="ERROR: 13 - Errors with program diagnostics";;
	14) ES="ERROR: 14 - Error in IPC code";;
	20) ES="ERROR: 20 - Received SIGUSR1 or SIGINT";;
	21) ES="ERROR: 21 - Some error returned by waitpid()";;
	22) ES="ERROR: 22 - Error allocating core memory buffers";;
	23) ES="ERROR: 23 - Partial transfer due to error";;
	24) ES="ERROR: 24 - Partial transfer due to vanished source files";;
	25) ES="ERROR: 25 - The --max-delete limit stopped deletions";;
	30) ES="ERROR: 30 - Timeout in data send/receive";;
	35) ES="ERROR: 35 - Timeout waiting for daemon connection";;
	*) ES="ERROR: ?? - An Unknown Error as occurred";;
esac

# add a new line to the logfile:
$ECHO_CMD "|  ""$BEGIN | $END | $ES">>$LOGDIR/backup.log
# add a new line to the logfile:
printf "%s | %s | %s" "$BEGIN" "$END" "$ES">>$LOGDIR/backup.LOGDIR

# ----------- real time feedback ----------------------------------------------#
# shows last logfile lines.
line
ctext "Operation completed:"
ctext"%s" "$($TAIL_CMD -n1 $LOGDIR/backup.log)"
line
# and that's it
exit 0

# show me last logfile's lines.
line
ctext "Operation completed:"
subline
ctext "`$TAIL_CMD -n1 $LOGDIR/backup.log`"
line
# and that's it
exit 0

# show me last logfile's lines.
line
$ECHO_CMD "|  Operation completed."
subline
$TAIL_CMD -n1 $LOGDIR/backup.log
line
# and that's it
exit 0
