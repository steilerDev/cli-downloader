#!/bin/bash 
load "helper/log.sh"

# File variables
DELETE_FILE=".unrar.$$.delete"
UNRAR_STATUS=".unrar.$$.status"
UNRAR_TEMP_FILE=".unrar.$$.tmp"

main () {
    while getopts "l:" opt; do
        case $opt in
            l)
                prepare_file_list $OPTARG
                init_ui "Extracting"
                extract_file_list $OPTARG
                ;;
            \?)
                echo "Invalid option: -$OPTARG" >&2
                exit
                ;;
        esac
    done
}

prepare_file_list () {
    if [ ! -e $1 ]; then
        log_error "Cannot find file ($1)"
        exit
    fi

    log "- Preparing extraction..." 

    # Sorting files by filename, means we will start with the first archive, subsequential archives do not contain inforamtion about preceding archives, resulting in re-doing the extraction when not starting with the first archive
    debug "Sorting $1..."
    sort $1 -o ${UNRAR_TEMP_FILE}
    mv $UNRAR_TEMP_FILE $1
    debug "$1 sorted!"
}

extract_file_list () {
    while [ -s $1 ] ; do
        read FILENAME < $1
        log_start "- Processing $FILENAME"
        if [ ! -e $FILENAME ] ; then
            log_error "-- $FILENAME does not exist, unable to extract"
            remove_file_from_list $FILENAME $1
        elif [[ $FILENAME == *".rar" ]] ; then
            log "-- Extracting ${FILENAME}..."

            # Check if all volumes are there
            if unrar l -v $FILENAME 2>&1 | grep -q "Cannot find volume" ; then
                log_error "--- Archive not complete, aborting"
                remove_files_from_list $FILENAME $1
                continue
            else
                unrar_file $FILENAME &
                while jobs %% > /dev/null 2>&1 ; do
                    show_unrar_status $(readlink -e $UNRAR_STATUS)
                done

                wait

                if [ ! $? ] ; then
                    log_error "--- Extraction of $FILENAME failed!"
                    remove_files_from_list $FILENAME $1
                    continue
                fi
            fi

            remove_files_from_list $FILENAME $1 $DELETE_FILE
            log_finish "- Finished processing $FILENAME"
        else
            log_error "- Archive (${FILENAME}) is not rar"
            remove_file_from_list $FILENAME $1
        fi
    done

    log_finish "Finished extraction!"
    rm $UNRAR_STATUS

    while read DELETE_CANDIDATE ; do
        if [ -e $DELETE_CANDIDATE ] ; then
            log "Deleting $DELETE_CANDIDATE"
            rm $DELETE_CANDIDATE
        else
            log_error "Unable to delete $DELETE_CANDIDATE, no such file"
        fi
    done < $DELETE_FILE

    rm $DELETE_FILE
}

unrar_file () {
    >$UNRAR_STATUS
    unrar x -o+ $1 >> $UNRAR_STATUS 2>$DEBUG_LOG_FILE
    return "${PIPESTATUS[0]}"
}

# $1: The filename of the first archive
# $2: The filename of the list
# $3: Optional, the list of files, marked for deletion
remove_files_from_list () {
    # Getting all files belonging to archive, in order to delete them later and not process them again
    unrar l -v $FILENAME 2>&1 | \
        grep '^Archive' | \
        sed -e 's/Archive: //g' | \
        while read line; do
            log "--- $line is part of ${FILENAME}'s archive"

            # If a deletion list is provided, add the archives to it
            if [ ! -z "$3" ] ; then
                # Adding the filename to the temp file will mark it for removal later, only doing so, if the extraction was successful
                echo ${line} >> ${DELETE_FILE}
            fi
            # Removing line from links file means, that the file will not be processed during extraction again
            remove_file_from_list ${line} $2
        done
}

remove_file_from_list () {
    debug "Removing $1 from file $2"
    sed -i '/'"${1}"'/d' ${2}
}
    
main $@
