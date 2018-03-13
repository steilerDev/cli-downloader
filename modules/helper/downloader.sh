#!/bin/bash 

MAX_PARALLEL_DL=6
TOTAL_FILE_COUNT=0
RETRY_COUNT=0

#
# Download the file list using curl from $1, expected format: <URL> <File Size> <File Name>
# After the download is finished, the file specified in $1 will contain a list of all succesfully downloaded files
#
download_file_list () {
    DOWNLOAD_LIST_FILE=$1
    if [ ! -e $DOWNLOAD_LIST_FILE ] ; then
        log_error "Unable to retrieve premium links!"
        return
    else 
        log "Downloading files..."

        TOTAL_FILE_COUNT=$(cat $DOWNLOAD_LIST_FILE | wc -l)
        CURRENT_FILE_COUNT=0

        while read -r URL SIZE FILENAME; do
            while : ; do
                if [ "$(jobs | wc -l)" -lt "$MAX_PARALLEL_DL" ] ; then
                    ((CURRENT_FILE_COUNT++))
                    download_file "$CURRENT_FILE_COUNT" "$TOTAL_FILE_COUNT" "$SIZE" "$URL" "$FILENAME" &
                    break
                fi

                if jobs %% > /dev/null ; then
                    show_download_status
                fi
            done
        done < "${DOWNLOAD_LIST_FILE}"
        debug "All Downloads started, waiting for them to finish..."
        while jobs %% > /dev/null 2>&1 ; do
            show_download_status
        done
        wait

        # Remove progress files
        find . -name '*.progress' -type f 2> /dev/null | rm

        # Delete the first three words from each line (URL and Size)
        sed -i 's/^\S*[ ]\S*[ ]//' ${DOWNLOAD_LIST_FILE}
    fi

    debug "Killing all eventually running jobs..."
    jobs -l | \
        grep -oE '[0-9]+ Running' | \
        grep -oE '[0-9]+' | \
        while read -r pid ; do
            kill -9 $pid
        done
}

# Downloads file using curl. 
#   $1 Current file count
#   $2 Total file count
#   $3 Expected file size
#   $4 URL
#   $5 Filename of output file
#
# Optionally $COOKIE can be set to "--cookie "<sth>=<sth>"" if the provider requires it
download_file () {
    URL=$4
    CFC=$1
    TFC=$2
    SIZE=$3
    NAME=$5

    PROGRESS_FILE=".downloader.$$.$(printf "%05d" ${CFC}).progress"

    echo "- Downloading file ${CFC}/${TFC} (${NAME})..." > $PROGRESS_FILE
    echo -n "                                                                           0.0% " >> $PROGRESS_FILE
    debug "- Downloading file ${CFC}/${TFC} (${NAME})..."

    curl $COOKIE $URL -o $NAME -# >> $PROGRESS_FILE 2>&1

    ACTUAL_SIZE=$(stat --printf="%s" $NAME)
    if [ "$ACTUAL_SIZE" -ne "$SIZE" ] ; then
        echo "! Failed downloading ${CFC}/${TFC} (${NAME}), because size is not as expected (${SIZE} vs. ${ACTUAL_SIZE})" > $PROGRESS_FILE
        echo -n "########################################################################### ERR " >> $PROGRESS_FILE
        debug "! Failed downloading ${CFC}/${TFC} (${NAME}), because size is not as expected (${SIZE} vs. ${ACTUAL_SIZE})"
        # If the download failed, the file will be removed from the link list (in order to not be respected during extraction later)
        sed -i '/'"${FILENAME}"'/d' ${DOWNLOAD_LIST_FILE}
        # The remaining data that was downloaded will be removed
        rm $FILENAME
    else
        echo "- Finished downloading ${CFC}/${TFC} (${NAME})!" > $PROGRESS_FILE
        echo -n "######################################################################## 100.0% " >> $PROGRESS_FILE
        debug "- Finished downloading ${CFC}/${TFC} (${NAME})!"
    fi
}

show_download_status () {
    clear
    for stat_file in $(find . -name '*.progress' -type f 2> /dev/null | sort); do
        head -n 1 $stat_file
        tail -c 80 $stat_file
        echo
    done
    sleep 1
}

main $@
