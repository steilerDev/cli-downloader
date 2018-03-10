#!/bin/bash 
source /opt/cli-downloader/modules/download/conf/premiumize.conf
# The config needs to hold the following variables:
#   USER_ID=""
#   USER_PIN=""

MAX_PARALLEL_DL=6

# Variables required for http requests
BOUNDARY="---------------------------312412633113176"
SEED="2or48h"
CSRF_TOKEN=""

# File variables
TEMP_FILE=".premiumize.$$.tmp"
TEMP_LINK_FILE=".premiumize.$$.link"

TOTAL_FILE_COUNT=0
RETRY_COUNT=0

# Color variables
GREEN='\033[0;32m'
CYAN='\033[0;36m'
RED='\033[1;31m'
NC='\033[0m'

main () {
    while getopts "hl:" opt; do
        case $opt in
            h)
                echo "http://ul.to"
                echo "http://uploaded.net"
                echo "https://openload.co"
                ;;
            l)
                start_download $OPTARG
                ;;
            \?)
                echo "Invalid option: -$OPTARG" >&2
                ;;
        esac
    done

}

start_download () {
    LINKS_FILE=$1
    # Refreshing CSRF Token 
    get_csrf_token

    get_premium_links

    download_file_list

    debug "Killing all eventually running jobs..."
    jobs -l | \
        grep -oE '[0-9]+ Running' | \
        grep -oE '[0-9]+' | \
        while read -r pid ; do
            kill -9 $pid
        done

    rm $TEMP_FILE
    rm $TEMP_LINK_FILE
}

# Dynamically setting the csrf token, since this is something premiumize.me now needs.
get_csrf_token () {
    log_start "Getting XSS token..."
    CSRF_TOKEN=$(curl -s 'https://www.premiumize.me/account' \
                    -H 'accept: */*;' \
                    -H 'authority: www.premiumize.me' \
                    -H 'cookie: login=846260004%3Aww2ajd4scbxe65w6' \
                    -H 'referer: https://www.premiumize.me/login' --head | \
                grep -Eo "xss-token=[^;]*" | \
                sed -e 's/^xss-token=//g'
    )
    log_finish "Got XXS token: $CSRF_TOKEN"
}


get_premium_links () {
    > $TEMP_LINK_FILE
    while read URL; do
        ((TOTAL_FILE_COUNT++))
        > $TEMP_FILE
        log_start "- Getting premium link (#${TOTAL_FILE_COUNT}) for ${URL}..."
        curl -s "https://www.premiumize.me/api/transfer/create" \
                    -H "Host: www.premiumize.me" \
                    -H "Accept: */*" \
                    -H "Referer: https://www.premiumize.me/downloader" \
                    -H "Connection: keep-alive" \
                    -H "Cookie: login=${USER_ID}%3A${USER_PIN}; xss-token=$CSRF_TOKEN" \
                    -H "x-csrf-token: $CSRF_TOKEN" \
                    -H "Content-Type: application/x-www-form-urlencoded; charset=UTF-8" \
                    --data "src=${URL}&seed=$SEED" > $TEMP_FILE

        debug "Got response for link #${TOTAL_FILE_COUNT} (${URL}): "
        debug "$(cat $TEMP_FILE)"

    
        if [[ "$(cat $TEMP_FILE | jq '.status')" == *"success"* ]] ; then
            echo -n "$URL " >> $LINKS_FILE
            cat $TEMP_FILE | \
                jq '.location' | \
                sed -e 's/^"//g' | sed -e 's/"$//g' | tr '\n' ' ' >> $TEMP_LINK_FILE

            cat $TEMP_FILE | \
                jq '.filesize' | \
                sed -e 's/^"//g' | sed -e 's/"$//g' | tr '\n' ' ' >> $TEMP_LINK_FILE

            cat $TEMP_FILE | \
                jq '.filename' | \
                sed -e 's/^"//g' | sed -e 's/"$//g' >> $TEMP_LINK_FILE
        else
            log_error "! Unable to get premium link (#${TOTAL_FILE_COUNT}) for ${URL}!"
            return 1
        fi
    done < $LINKS_FILE
}


#
# Iterating over links file (if it exists), downloading each file and extracting them
# Todo: Spawn curl process with `&` and wait for them to finish
#
# Removes single line from LINKS_FILE and appends it to TEMP_FAILED_FILE (in case download did not succeed)
download_file_list () {
    if [ ! -e $TEMP_LINK_FILE ] ; then
        log_error "Unable to retrieve premium links!"
        return
    else 
        log "Downloading files..."

        TOTAL_FILE_COUNT=$(cat $TEMP_LINK_FILE | wc -l)
        CURRENT_FILE_COUNT=0

        while read -r URL SIZE FILENAME; do
            while [ "$(jobs | wc -l)" -ge "$MAX_PARALLEL_DL" ] ; do
                sleep 10
            done

            ((CURRENT_FILE_COUNT++))
            download_file "$CURRENT_FILE_COUNT" "$TOTAL_FILE_COUNT" "$SIZE" "$URL" "$OURL" "$FILENAME" &

        done < "${TEMP_LINK_FILE}"
        debug "All Downloads started, waiting for them to finish..."
        wait

        extract_files
    fi
}

# Removes single line from LINKS_FILE and appends it to TEMP_FAILED_FILE (in case download did not succeed)
download_file () {
    URL=$4
    CFC=$1
    TFC=$2
    SIZE=$3
    NAME=$6

    log_start "- Downloading file ${CFC}/${TFC} (${NAME})..."
    curl $URL -o $NAME -# > /dev/null 2>&1

    ACTUAL_SIZE=$(stat --printf="%s" $NAME)
    if [ "$ACTUAL_SIZE" -ne "$SIZE" ] ; then
        log_error "! Failed downloading ${CFC}/${TFC} (${NAME}), because size is not as expected (${SIZE} vs. ${ACTUAL_SIZE})"
        # If the download failed, the file will be removed from the link list (in order to not be respected during extraction later)
        sed -i '/'"${FILENAME}"'/d' ${TEMP_LINK_FILE}
        # The remaining data that was downloaded will be removed
        rm $FILENAME
    else
        log_finish "- Finished downloading ${CFC}/${TFC} (${NAME})!"
    fi
}

# Clears tempfile, replaces LINKS_FILE and empties it
extract_files () {
    log "Trying to extract files..."
  
    log "- Preparing extraction..." 
    # Sorting files by filename, means we will start with the first archive, subsequential archives do not contain inforamtion about preceding archives, resulting in re-doing the extraction when not starting with the first archive

    debug "Sorting ${TEMP_LINK_FILE}..."
    > ${TEMP_FILE} 
    while read -r OURL URL SIZE FILENAME; do
        echo $FILENAME >> ${TEMP_FILE}
    done < "${TEMP_LINK_FILE}"
    sort ${TEMP_FILE} -o ${TEMP_LINK_FILE}
    > ${TEMP_FILE} 
    debug "${TEMP_LINK_FILE} sorted!"

    while [ -s ${TEMP_LINK_FILE} ] ; do
        read -r FILENAME < ${TEMP_LINK_FILE}
        log_start "- Processing $FILENAME"
        if [ ! -e $FILENAME ] ; then
            log_error "-- $FILENAME does not exist, unable to extract"
            sed -i '/'"${FILENAME}"'/d' ${TEMP_LINK_FILE}
        elif [[ $FILENAME == *".rar" ]] ; then
            log "-- Extracting ${FILENAME}..."
            UNRAR_ERR=false

            # Check if all volumes are there
            if unrar l -v $FILENAME 2>&1 | grep -q "Cannot find volume" ; then
                log_error "--- Archive not complete, aborting"
                UNRAR_ERR=true
            else
                unrar x -o+ $FILENAME | tr $'\r' $'\n' >> $LOG_FILE 2>&1
                UNRAR_EXIT="${PIPESTATUS[0]}"
                if [ "$UNRAR_EXIT" -ne "0" ] ; then
                    log_error "--- Extraction of $FILENAME failed!"
                    UNRAR_ERR=true
                fi
            fi

            if [ "$UNRAR_ERR" = true ] ; then
                sed -i '/'"${FILENAME}"'/d' ${TEMP_LINK_FILE}
            fi

            # Getting all files belonging to archive, in order to delete them later and not process them again
            unrar l -v $FILENAME 2>&1 | \
                grep '^Archive' | \
                sed -e 's/Archive: //g' | \
                while read -r line; do
                    log "--- $line is part of ${FILENAME}'s archive"

                    if [ "$UNRAR_ERR" = false ] ; then
                        # Adding the filename to the temp file will mark it for removal later, only doing so, if the extraction was successful
                        echo ${line} >> ${TEMP_FILE}
                    fi
                    # Removing line from links file means, that the file will not be processed during extraction again
                    sed -i '/'"${line}"'/d' ${TEMP_LINK_FILE}
                done
            log_finish "- Finished processing $FILENAME"
        else
            log_error "- Archive (${FILENAME}) is not rar"
            sed -i '/'"${FILENAME}"'/d' ${TEMP_LINK_FILE}
        fi
    done
}

log_start () {
    echo -e "${CYAN}$@${NC}"
    debug $@
}

log_finish () {
    echo -e "${GREEN}$@${NC}"
    debug $@
}

log_error () {
    echo -e "${RED}$@${NC}"
    debug $@
}

log () {
    echo $@ | tee -a $LOG_FILE
}

debug () {
    echo $@ >> $LOG_FILE
}

main $@
