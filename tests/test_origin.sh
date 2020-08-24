ORIGIN="./origin"
[[ ! -e "${ORIGIN}" ]] && ( echo -e "${ORIGIN} does not exist.\n Leaving ..." && exit 1 )
echo " ${ORIGIN} found it"
