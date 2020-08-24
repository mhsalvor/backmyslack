CONFDIR="./confdir"

if [[ ! -d "${CONFDIR}" ]] ; then
    echo "${CONFDIR} does not exist or is not a directory."
    read -p " Do you wan to create it? (y/N) " answer
    case ${answer:0:1} in
        y|Y) mkdir -p "${CONFDIR}"
            echo "creating confdir";;
        * ) echo " Leaving..." ;;
    esac
fi

echo
ls -a
echo
