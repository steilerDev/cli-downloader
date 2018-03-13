#!/bin/bash 

# The config needs to hold the following variables:
#   USER_ID=""
#   USER_PIN=""

if [ -e $INSTALL_DIR/modules/download/conf/share-online.conf ]; then
    source $INSTALL_DIR/modules/download/conf/share-online.conf
else
    echo "Unable to load log module ($INSTALL_DIR/modules/download/conf/share-online.conf)!"
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

# File variables
TEMP_FILE=".share-online.$$.tmp"
TEMP_LINK_FILE=".share-online.$$.link"
PACKAGE_DIR="premiumize-$$"

main () {
    while getopts "ehl:" opt; do
        case $opt in
            h)
                echo "https://share-online.biz"
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

    get_metadata

    download_file_list $TEMP_LINK_FILE

    rm $TEMP_FILE
    rm $TEMP_LINK_FILE
}


get_metadata () {
    > $TEMP_LINK_FILE
    while read URL; do
        LINK_ID
        ((TOTAL_FILE_COUNT++))
        > $TEMP_FILE
        log_start "- Getting metadata (#${TOTAL_FILE_COUNT}) for ${URL}..."
        curl -s "http://api.share-online.biz/cgi-bin?q=linkdata&username=$USERNAME&password=$PASSWORD&lid=$LINK_ID" > $TEMP_FILE

        debug "Got response for link #${TOTAL_FILE_COUNT} (${URL}): "
        debug "$(cat $TEMP_FILE)"
    
        if grep -Fxq "STATUS: online" $TEMP_FILE ; then
            grep "URL: " $TEMP_FILE | cut -c 6- | tr '\n' ' ' >> $TEMP_LINK_FILE
            grep "SIZE: " $TEMP_FILE | cut -c 7- | tr '\n' ' ' >> $TEMP_LINK_FILE
            grep "NAME: " $TEMP_FILE | cut -c 7- >> $TEMP_LINK_FILE
        else
            log_error "! Unable to get metadata (#${TOTAL_FILE_COUNT}) for ${URL}!"
            return 1
        fi
    done < $LINKS_FILE
}

main $@
