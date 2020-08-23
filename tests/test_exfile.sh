EXCLUSION_FILE=./exclude

[[ -f "${EXCLUSION_FILE}" ]] || printf \
"/bin
/dev
/home/*/.gvfs
/home/*/cache
/lib
/lib64
/lost+found
/*/lost+found
/media\n
/mnt\n
/opt\n
/proc\n
/root\n
/run\n
/sbin\n
/srv\n
/sys\n
/tmp\n
/usr\n
/var" > ${EXCLUSION_FILE}
echo " DONE"
