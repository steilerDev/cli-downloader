#!/bin/bash 

# The config needs to hold the following variables:
#   USER_ID=""
#   USER_PIN=""
if [ -e $INSTALL_DIR/modules/download/conf/premiumize.conf ]; then
    source $INSTALL_DIR/modules/download/conf/premiumize.conf
else
    echo "Unable to load log module ($INSTALL_DIR/modules/download/conf/premiumize.conf)!"
fi

if [ -e $INSTALL_DIR/modules/log/log.sh ]; then
    source $INSTALL_DIR/modules/log/log.sh
else
    echo "Unable to load log module ($INSTALL_DIR/modules/log/log.sh)!"
fi

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

main () {
    while getopts "ehl:" opt; do
        case $opt in
            h)
                echo "http://ul.to"
                echo "http://uploaded.net"
                echo "https://openload.co"
                ;;
            l)
                start_download $OPTARG
                ;;
            e)
                exit 0
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

        # Putting the file names of the downloaded files into the LINKS_FILE, in order to be extracted by the downloader later
        > ${LINKS_FILE} 
        while read -r URL SIZE FILENAME; do
            echo $FILENAME >> ${LINKS_FILE}
        done < "${TEMP_LINK_FILE}"
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

main $@
