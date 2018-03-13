#!/bin/bash 
if [ -e $INSTALL_DIR/modules/log/log.sh ]; then
    source $INSTALL_DIR/modules/log/log.sh
else
    echo "Unable to load log module ($INSTALL_DIR/modules/log/log.sh)!"
fi

# File variables
TEMP_FILE=".unrar.$$.tmp"
DELETE_FILE=".unrar.$$.delete"

while getopts "l:" opt; do
    case $opt in
        l)
            FILES="$OPTARG"
            ;;
        \?)
            echo "Invalid option: -$OPTARG" >&2
            ;;
    esac
done

if [ ! -e $FILES ]; then
    log_error "Cannot find file ($FILES)"
    exit
fi

log_start "Trying to extract files..."
log "- Preparing extraction..." 

# Sorting files by filename, means we will start with the first archive, subsequential archives do not contain inforamtion about preceding archives, resulting in re-doing the extraction when not starting with the first archive
debug "Sorting $FILES..."
sort $FILES -o ${TEMP_FILE}
debug "$FILES sorted!"

while [ -s ${TEMP_FILE} ] ; do
    read -r FILENAME < ${TEMP_FILE}
    log_start "- Processing $FILENAME"
    if [ ! -e $FILENAME ] ; then
        log_error "-- $FILENAME does not exist, unable to extract"
        sed -i '/'"${FILENAME}"'/d' ${TEMP_FILE}
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
            sed -i '/'"${FILENAME}"'/d' ${TEMP_FILE}
        fi

        # Getting all files belonging to archive, in order to delete them later and not process them again
        unrar l -v $FILENAME 2>&1 | \
            grep '^Archive' | \
            sed -e 's/Archive: //g' | \
            while read -r line; do
                log "--- $line is part of ${FILENAME}'s archive"

                if [ "$UNRAR_ERR" = false ] ; then
                    # Adding the filename to the temp file will mark it for removal later, only doing so, if the extraction was successful
                    echo ${line} >> ${DELETE_FILE}
                fi
                # Removing line from links file means, that the file will not be processed during extraction again
                sed -i '/'"${line}"'/d' ${TEMP_FILE}
            done
        log_finish "- Finished processing $FILENAME"
    else
        log_error "- Archive (${FILENAME}) is not rar"
        sed -i '/'"${FILENAME}"'/d' ${TEMP_FILE}
    fi
done

log_finish "Finished extraction!"
