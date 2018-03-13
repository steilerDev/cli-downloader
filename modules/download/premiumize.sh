#!/bin/bash 

# The config needs to hold the following variables:
#   USER_ID=""
#   USER_PIN=""

if [ -e $INSTALL_DIR/modules/download/conf/premiumize.conf ]; then
    source $INSTALL_DIR/modules/download/conf/premiumize.conf
else
    echo "Unable to load log module ($INSTALL_DIR/modules/download/conf/premiumize.conf)!"
    exit
fi

if [ -e $INSTALL_DIR/modules/helper/log.sh ]; then
    source $INSTALL_DIR/modules/helper/log.sh
else
    echo "Unable to load log module ($INSTALL_DIR/modules/log/log.sh)!"
fi

if [ -e $INSTALL_DIR/modules/helper/download.sh ]; then
    source $INSTALL_DIR/modules/helper/download.sh
else
    echo "Unable to load log module ($INSTALL_DIR/modules/helper/download.sh)!"
fi

# Variables required for http requests
BOUNDARY="---------------------------312412633113176"
SEED="2or48h"
CSRF_TOKEN=""

# File variables
TEMP_FILE=".premiumize.$$.tmp"
TEMP_LINK_FILE=".premiumize.$$.link"
PACKAGE_DIR="premiumize-$$"

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
                exit 1
                ;;
            \?)
                echo "Invalid option: -$OPTARG" >&2
                ;;
        esac
    done

}

start_download () {
    LINKS_FILE=$1
    if [ ! -d $PACKAGE_DIR ]; then
        mkdir $PACKAGE_DIR
    fi
    cd $PACKAGE_DIR

    # Refreshing CSRF Token 
    get_csrf_token

    get_premium_links

    download_file_list $TEMP_LINK_FILE

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

main $@
