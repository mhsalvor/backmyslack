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
CONFDIR="./confdir"
CONFIG_FILE="${CONFDIR}/config"
LOG_FILE="${CONFDIR}/bkms.log"
EXCLUSION_FILE="${CONFDIR}/exclude"

BEGIN=$(date +"%Y%m%d-%H%M")
CURRENT=${BEGIN}

IsSimulation=0
IsFirstBackup=0

echo "======================DEFAULTS============================================"
printf "\n"
printf " Questi sono i valori iniziali di :\n"
printf " NAME = %s\n" ${NAME}
printf " SNAME = %s\n" ${SNAME}
printf " VERSION = %s\n" ${VERSION}
echo -e " GPLSPLASH = " ${GPLSPLASH}
printf "\n"
printf " ORIGIN = %s\n" ${ORIGIN}
printf " DESTDIR = %s\n" ${DESTDIR}
printf " CONFDIR = %s\n" ${CONFDIR}
printf " CONFIG_FILE = %s\n" ${CONFIG_FILE}
printf " LOG_FILE = %s\n" ${LOG_FILE}
printf " EXCLUSION_FILE = %s\n" ${EXCLUSION_FILE}
printf "\n"
printf " BEGIN = %s\n" ${BEGIN}
printf " CURRENT = %s\n" ${CURRENT}
printf "\n"
printf " IsFirstBackup = %c\n" ${IsFirstBackup}
printf " IsSimulation = %c\n" ${IsSimulation}
printf "\n"
echo "=========================================================================="

###---= User Preferences =---###
echo "===================USER Preferences======================================="
printf "\n"
# Check if the config directory exist, if not create one:
( [[ -d "${CONFDIR}" ]] && echo " confdir found" ) || ( mkdir -p ${CONFDIR} && echo " confdir created" )

# If present, source the "config" file and overwrite the defaults
[[ -f "${CONFIG_FILE}" ]] && ( source ${CONFIG_FILE} && echo " config file found" ) || echo " no config file"
printf "\n"
echo "=========================================================================="

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

while getopts ":C:c:e:ho:l:sV" option; do
    case ${option} in
        C) CONFDIR=${OPTARG};;          # Set custom config dir
        c) CONFIG_FILE=${OPTARG};;      # Set custom config file
        e) EXCLUSION_FILE=${OPTARG};;   # Set custom exlusion file
        h) show_help                    # Display the help message
            exit 0 ;;
        o) ORIGIN=${OPTARG};;           # Set custom backup origin
        l) LOG_FILE=${OPTARG};;         # Set custom logfile
        s) IsSimulation=1;;             # Simulation: rsync dry run
        V) echo -e "${NAME}: ${SNAME} "v"${VERSION}\n" ${GPLSPLASH}
            exit 0 ;;                   # Display version and License short blurp
        \?) printf "%s: invalid option: -%c\n" ${SNAME} ${OPTARG}
            exit 1 ;;
        :) printf "%s: option -%c requires and argument.\n " ${SNAME} ${OPTARG}
            exit 1;;
    esac
done
# The destination is mandatory unless it's set in the config file.
shift $(( $OPTIND - 1 ))
#( [[ "$1" ]] && DESTDIR=$1 ) || ( echo " Destdir not found"; exit 1 )
if [[ -d "$1" ]] ; then
    DESTDIR="$1"
else
    printf "%s: %s is not a valid directory\n" ${SNAME} "$1"
    exit 1
fi

echo "======================Final values========================================"
printf "\n"
printf " Questi sono i valori finali di :\n"
printf " NAME = %s\n" ${NAME}
printf " SNAME = %s\n" ${SNAME}
printf " VERSION = %s\n" ${VERSION}
echo -e " GPLSPLASH = " ${GPLSPLASH}
printf "\n"
printf " ORIGIN = %s\n" ${ORIGIN}
printf " DESTDIR = %s\n" ${DESTDIR}
printf " CONFDIR = %s\n" ${CONFDIR}
printf " CONFIG_FILE = %s\n" ${CONFIG_FILE}
printf " LOG_FILE = %s\n" ${LOG_FILE}
printf " EXCLUSION_FILE = %s\n" ${EXCLUSION_FILE}
printf "\n"
printf " BEGIN = %s\n" ${BEGIN}
printf " CURRENT = %s\n" ${CURRENT}
printf "\n"
printf " IsFirstBackup = %c\n" ${IsFirstBackup}
printf " IsSimulation = %c\n" ${IsSimulation}
printf "\n"
echo "=========================================================================="

