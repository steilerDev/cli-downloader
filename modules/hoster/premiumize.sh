#!/bin/bash 

# The config needs to hold the following variables:
#   USER_ID=""
#   USER_PIN=""

load "hoster/conf/premiumize.conf"

# Variables required for http requests
BOUNDARY="---------------------------312412633113176"
SEED="2or48h"

# File variables
TEMP_LINK_FILE=".premiumize.$$.link"

hoster () {
    echo "http://ul.to"
    echo "http://uploaded.net"
    echo "https://openload.co"
}

# Dynamically setting the csrf token, since this is something premiumize.me needs.
CSRF_TOKEN=""
init () {
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

# This function has a URL as argument and should set the following variables:
#   URL: The url, that can be used by curl to download the file
#   SIZE: The filesize
#   FILENAME: The filename
TEMP_FILE=".premiumize.$$.tmp"
get_link () {
    > $TEMP_FILE
    OURL=$1
    debug "- Getting metadata for ${OURL}..."
    curl -s "https://www.premiumize.me/api/transfer/create" \
                -H "Host: www.premiumize.me" \
                -H "Accept: */*" \
                -H "Referer: https://www.premiumize.me/downloader" \
                -H "Connection: keep-alive" \
                -H "Cookie: login=${USER_ID}%3A${USER_PIN}; xss-token=$CSRF_TOKEN" \
                -H "x-csrf-token: $CSRF_TOKEN" \
                -H "Content-Type: application/x-www-form-urlencoded; charset=UTF-8" \
                --data "src=${OURL}&seed=$SEED" > $TEMP_FILE

    debug "Got response for link (${OURL}): "
    debug "$(cat $TEMP_FILE)"

    if [[ "$(cat $TEMP_FILE | jq '.status')" == *"success"* ]] ; then
        URL=$(cat $TEMP_FILE | \
            jq '.location' | \
            sed -e 's/^"//g' | sed -e 's/"$//g')

        SIZE=$(cat $TEMP_FILE | \
            jq '.filesize' | \
            sed -e 's/^"//g' | sed -e 's/"$//g')

        FILENAME=$(cat $TEMP_FILE | \
            jq '.filename' | \
            sed -e 's/^"//g' | sed -e 's/"$//g')
    else
        log_error "! Unable to get metadata for ${URL}!"
        return 1
    fi
    rm $TEMP_FILE
}
