#!/bin/bash 

# Color variables
GREEN='\033[0;32m'
CYAN='\033[0;36m'
RED='\033[1;31m'
NC='\033[0m'

LOG_FILE="/tmp/log"

LINK_FILE=".downloader.$$.links"
TEMP_FILE=".downloader.$$.tmp"

INSTALL_DIR="/opt/cli-downloader"
DLC_DECRYPT_MODULE="dcrypt.it.sh"

DOWNLOAD_DIR="/media/files/Downloads"

main () {
    savelog -q $LOG_FILE

    debug "$(date)"
    if [ $# -eq 0 ]; then
        log "No files provided, scanning current directory for '.dlc' or '.links' files..."
        set -- "$(ls *.dlc *.links)"
    fi
    debug "Got the following files: $@"
    
    
    while getopts "e" opt; do
        case $opt in
            e)
                debug "Edit mode on"
                EDIT=true
                ;;
            \?)
                echo "Invalid option: -$OPTARG" >&2
                ;;
        esac
    done
    
    # Create $LINK_FILE 
    create_link_file $@

    # Consume $LINK_FILE
    start_download
    
    log_finish "All done, thanks for using cli-downloader"
}

create_link_file () {
    > $LINK_FILE
    for INPUT in "$@" ; do
        if [[ $INPUT != "-"* ]] ; then
            log_start "Starting processing $INPUT"

            # Filling $LINK_FILE at this point
            if [ ! -e $INPUT ] ; then
                log_error "Unable to process ${INPUT}: File does not exist"
                continue
            elif [[ $INPUT == *".dlc" ]] ; then
                decrypt_dlc $INPUT
            elif [[ $INPUT == *".links" ]] ; then
                cat $INPUT >> $LINK_FILE 
            else
                log_error "\"$INPUT\" is neither a DLC nor a links file, can not process it!"
                continue
            fi
            log_finish "Finished processing ${INPUT}, removing file!"
            rm $INPUT
        fi
    done
    if [ "$EDIT" = true ] ; then
        vim $LINK_FILE
    fi
}

# Clears TEMP_FILE, appends LINKS_FILE
decrypt_dlc () {
    if [ -e $INSTALL_DIR/modules/decrypt/$DLC_DECRYPT_MODULE ] ; then
        $INSTALL_DIR/modules/decrypt/$DLC_DECRYPT_MODULE -l $(readlink -e $LINK_FILE) -d $(readlink -e $1)
    else
        log_error "Unable to find specified module ($DLC_DECRYPT_MODULE)"
        exit
    fi
}

start_download () {
    # We need to split the link file for the respective hosts

    for MOD in $INSTALL_DIR/modules/download/*; do
        if [ -d $MOD ]; then
            debug "$MOD is folder, skipping"
            continue
        fi
        if [ ! -x $MOD ]; then
            debug "$MOD is not executable"
            continue
        fi

        debug "$MOD is module"
        MODULE_LINK_FILE=".downloader.$$.$(basename $MOD).links"
        > $MODULE_LINK_FILE
        for HOST in $($MOD -h); do
            log "Matching host $HOST for module $MOD"
            grep -E "^$HOST" $LINK_FILE >> $MODULE_LINK_FILE
            SED_HOST=$(echo $HOST | sed -e 's/[]\/$*.^[]/\\&/g')
            sed -i "/^$SED_HOST/d" $LINK_FILE
        done

        if [ "$(wc -l < $MODULE_LINK_FILE)" -gt 0 ]; then
            log "We have $(wc -l < $MODULE_LINK_FILE) links for this module, starting download..."
            
            CURR_DIR="$(pwd)"
            FQ_MOD=$(readlink -e $MOD)
            FQ_LINK=$(readlink -e $MODULE_LINK_FILE)

            cd $DOWNLOAD_DIR
            $FQ_MOD -l $FQ_LINK
            cd $CURR_DIR 
        fi
        rm $MODULE_LINK_FILE
    done
    rm $LINK_FILE
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
