#!/bin/bash 

# The config needs to hold the following variables:
#   USER_ID=""
#   USER_PWD=""
load "hoster/conf/share-online.conf"
load "helper/log.sh"



hoster () {
    echo "https://share-online.biz"
    echo "http://share-online.biz"
    echo "http://www.share-online.biz"
}

init () {
    log_start "Getting cookie for share-online..."
    COOKIE=$(curl -s "http://api.share-online.biz/cgi-bin?q=userdetails&username=$USERNAME&password=$USER_PWD" | \
                grep "^a=" | \
                cut -c 3-)
    log_finish "Got cookie ($COOKIE)"
    CURL_ARGS="--cookie a=$COOKIE"
}

# This function has a URL as argument and should set the following variables:
#   URL: The url, that can be used by curl to download the file
#   SIZE: The filesize
#   FILENAME: The filename
# 
#   Optional:
#       CURL_ARGS: Additional arguments for curl
TEMP_FILE=".share-online.$$.tmp"
get_link () {
    > $TEMP_FILE
    OURL=$1
    LINK_ID=$(echo $OURL | sed 's/http:\/\/www\.share-online\.biz\/dl\///')
    debug "- Getting metadata for ${OURL}..." 
    curl -s "http://api.share-online.biz/cgi-bin?q=linkdata&username=$USERNAME&password=$USER_PWD&lid=$LINK_ID" > $TEMP_FILE

    debug "Got response for link ${URL}: "
    debug "$(cat $TEMP_FILE)"
    
    if grep -Fxq "STATUS: online" $TEMP_FILE ; then
        URL=$(grep "URL: " $TEMP_FILE | cut -c 6-)
        SIZE=$(grep "SIZE: " $TEMP_FILE | cut -c 7-)
        FILENAME=$(grep "NAME: " $TEMP_FILE | cut -c 7-)
    else
        log_error "! Unable to get metadata for ${URL}!"
        return 1
    fi
    rm $TEMP_FILE
}
