ORIGIN=./origin
DESTDIR=./destdir
EXCLUSION_FILE=./exclude
LOG_FILE=./bkms.log

BEGIN=$(date +"%Y%m%d-%H%M")
CURRENT=${BEGIN}

IsSimulation=0
IsFirstBackup=0

RSYNC_CMD="ionice -c3 rsync"
RSYNC_OPT="-azhv --info=progress2,stats --info=name0 --del --exclude-from=${EXCLUSION_FILE}"
RSYNC_SIM="${RSYNC_OPT} --dry-run"
echo
echo ${RSYNC_CMD}
echo ${RSYNC_OPT}
echo ${RSYNC_SIM}
echo

tot="$( ${RSYNC_CMD} ${RSYNC_SIM}  "${ORIGIN}" "${DESTDIR}/${CURRENT}"| grep "total size" | awk '{print $4}' )"
echo ${tot}
# ${RSYNC_CMD} ${RSYNC_OPT} "${ORIGIN}" "${DESTDIR}/${CURRENT}"

