#!/bin/sh
# vim: set sw=4 sts=2 et:

# ============================
# vars azure account/zone
# define them in ./azenv or
# as environment variables
[ -e ./azenv ] && . ./azenv
RESOURCE_GROUP=${RESOURCE_GROUP:=""}
ZONE_NAME=${ZONE_NAME:=""}
SUBSCRIPTION=${SUBSCRIPTION:=""}

# ============================
# vars program related
OUTSIDE_PROG=azure_acme_cleanup.sh
INSIDE_PROG=cleanup.sh
CONTAINER_NAME=azcli


outside_usage(){
cat << EOM
==============================================================================

    usage: ${0} [-e|-r]
        -e show azure related vars
        -r run this script

    The script will start a docker container with the azcli tool.
    As soon the container is started a shell inside the container
    will be opened.

    Please follow the instruction provided in the new shell

==============================================================================

EOM
exit 0
}


inside_usage(){
cat << EOM
==============================================================================

    usage: ${0} [-d|-e|-g]
        -e show azure related vars
        -d delete all DNS TXT records containing _acme
        -g generate list and script with DNS TXT record names containing _acme

==============================================================================
EOM
exit 0
}


#=============================================================================
# everything running outside the container
#=============================================================================
outside_prepare_container(){

    # check if variable is empty or undefined
    [ -n "${RESOURCE_GROUP}" ] || err_defined  "RESOURCE_GROUP"
    [ -n "${ZONE_NAME}" ]      || err_defined  "ZONE_NAME"
    [ -n "${SUBSCRIPTION}" ]   || err_defined  "SUBSCRIPTION"

    docker run -it --rm --name ${CONTAINER_NAME} \
        -e RESOURCE_GROUP=${RESOURCE_GROUP} \
        -e ZONE_NAME=${ZONE_NAME} \
        -e SUBSCRIPTION=${SUBSCRIPTION} \
        -d mcr.microsoft.com/azure-cli

    until [ $( docker inspect ${CONTAINER_NAME} -f {{.State.Running}} ) = "true" ]; do
        sleep 1
    done

    docker cp ${0} ${CONTAINER_NAME}:${INSIDE_PROG}
    clear

cat << EOM
==============================================================================

  You have now a shell inside the container
  Please run the following command:

    /${INSIDE_PROG} [-g|-d]

    -g generate list and script with DNS TXT record names containing _acme
    -d delete all DNS TXT records containing _acme

==============================================================================

EOM

    docker exec -it ${CONTAINER_NAME} bash
    docker stop ${CONTAINER_NAME}
}


#=============================================================================
# everything running inside the container
#=============================================================================
ACME_TXT_NAMES=/root/acme_records
DEL_SCRIPT=/root/delete_acme_txt_records.sh
LOGIN_DONE=/root/.login_done

inside_genlist(){

    # make sure work-list is empty
    cat /dev/null > ${ACME_TXT_NAMES}

    # azure login:
    #  A message with URL and token will be generated.
    #  The `az login' command will wait until the URL is opened and the token insert by the OP
    [ -e ${LOGIN_DONE} ] || az login
    [ $? -eq 0 ] && touch ${LOGIN_DONE}

    if [ -e ${LOGIN_DONE} ]; then
        printf "generate TXT record list, please stand by this takes a while ...\n"

        # generate a list of TXT records containing _acme
        #   required parameters:
        #     --resource-group
        #     --zone-name
        #     --subscription
        az network dns record-set txt list \
            --resource-group ${RESOURCE_GROUP} \
            --zone-name ${ZONE_NAME} \
            --subscription ${SUBSCRIPTION} \
            -o json --query "[].{name:name}" \
            | awk '/_acme/{print $2}' | tr -d ':,"' \
            | tee ${ACME_TXT_NAMES}
    fi

    # reset working counter
    NUM=0
    TOTAL=0

    # check if we have entry's in the working list
    if [ -s ${ACME_TXT_NAMES} ]; then

    # int total counter
    TOTAL=$( wc -l ${ACME_TXT_NAMES} | awk '{print $1}' )

    # add shell header
    printf "#!/bin/sh\n\n" | tee ${DEL_SCRIPT}
    echo "echo start delete TXT records" | tee -a ${DEL_SCRIPT}

    grep -h _acme ${ACME_TXT_NAMES} | while read NAME; do
        NUM=$(( ${NUM} + 1 ))
        echo "echo \"${NUM}/${TOTAL}: delete ${NAME}\"" | tee -a ${DEL_SCRIPT}
        echo az network dns record-set txt delete --resource-group ${RESOURCE_GROUP} --zone-name ${ZONE_NAME} --subscription ${SUBSCRIPTION} --name \'${NAME}\' --yes | tee -a ${DEL_SCRIPT}
    done

    echo "echo finished delete TXT records" | tee -a ${DEL_SCRIPT}

    chmod +x ${DEL_SCRIPT}

cat << EOM

==============================================================================

    Found ${TOTAL} TXT records containing _acme

    To delete the records execute the following command:
        ${0} -d

==============================================================================
EOM
    fi
}


inside_rm_records(){
    if [ -s ${DEL_SCRIPT} -o -x ${DEL_SCRIPT} ]; then
        exec sh ${DEL_SCRIPT}
    else
        printf "\nERROR: \"%s\" script not found or not executable\n" ${DEL_SCRIPT}
    fi
}


print_env(){
    printf "\n\nazure account/zone vars:\n"
    printf "%-15s: %s\n" "RESOURCE_GROUP" ${RESOURCE_GROUP:-"-- missing --"}
    printf "%-15s: %s\n" "ZONE_NAME" ${ZONE_NAME:-"-- missing --"}
    printf "%-15s: %s\n" "SUBSCRIPTION" ${SUBSCRIPTION:-"-- missing --"}
    printf "\n\n"
}


err_defined(){
    printf "\nERROR:\tvariable \"%s\" has no value assigned or is not defined.\n" "${1}"
    printf "\tPlease define RESOURCE_GROUP, ZONE_NAME and SUBSCRIPTION\n\tin file ./azenv or set them as env vars\n\n"
    exit 1
}


#=============================================================================
# program flow
#=============================================================================

PROG=$( basename ${0} )
INSIDE=0

# are we running inside or outside?
case ${PROG} in
    ${OUTSIDE_PROG}) INSIDE=0 ;;
    ${INSIDE_PROG})  INSIDE=1 ;;
    *) printf "\n\nERROR: undefined script ${0}\n" ; exit 1 ;;
esac

# we run outside
if [ ${INSIDE} -eq 0 ]; then
    if [ $# -eq 1 ]; then
        while getopts er arg; do
        case ${arg} in
            r) outside_prepare_container ;;
            e) print_env ;;
            *) outside_usage ;;
        esac
        done
    else
        outside_usage
    fi

# we run inside
elif [ ${INSIDE} -eq 1 ]; then
    printf "INFO: running inside container\n"

    if [ $# -eq 1 ]; then
        while getopts deg arg; do
        case ${arg} in
            d) inside_rm_records ;;
            g) inside_genlist ;;
	    e) print_env ;;
            *) inside_usage ;;
        esac
        done
    else
        inside_usage
    fi

# undefined
else
    printf "\n\nERROR: running in undefined universe ...\n"
    exit 1
fi


