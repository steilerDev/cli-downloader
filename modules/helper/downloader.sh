#!/bin/bash 

MAX_PARALLEL_DL=6
TOTAL_FILE_COUNT=0
RETRY_COUNT=0

load "helper/log.sh"

main () {
    # Load the stated module
    load "hoster/$1"
    shift

    while getopts "ehl:" opt; do
        case $opt in
            h)
                hoster
                ;;
            l)
                init
                download_file_list $OPTARG
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

#
# Download the file list using curl from $1, expected format: <URL> <File Size> <File Name>
# After the download is finished, the file specified in $1 will contain a list of all succesfully downloaded files
#
FINISHED_LIST=".downloader.$$.finished"
download_file_list () {
    DOWNLOAD_LIST_FILE=$1

    if [ ! -e $DOWNLOAD_LIST_FILE ] ; then
        log_error "Unable to retrieve links!"
        return
    else 
        log_start "Initiating file download..."
        > $FINISHED_LIST
        TOTAL_FILE_COUNT=$(cat $DOWNLOAD_LIST_FILE | wc -l)
        CURRENT_FILE_COUNT=0

        init_ui "Downloading"

        while read -u 3 OURL ; do
            debug "$(date +%T) Next file $OURL"

            while [ "$(jobs | wc -l)" -ge "$MAX_PARALLEL_DL" ] ; do
                show_download_status $(pwd)
            done

            ((CURRENT_FILE_COUNT++))
            get_link $OURL
            download_file "$CURRENT_FILE_COUNT" "$TOTAL_FILE_COUNT" "$SIZE" "$URL" "$FILENAME" &
            show_download_status $(pwd)
        done 3< "${DOWNLOAD_LIST_FILE}"

        debug "All Downloads started, waiting for them to finish..."
        while jobs %% > /dev/null 2>&1 ; do
            show_download_status $(pwd)
        done

        wait

        # Remove progress files
        find . -name '*.progress' -type f 2> /dev/null | xargs rm
        # Move list files
        rm $DOWNLOAD_LIST_FILE
        mv $FINISHED_LIST $DOWNLOAD_LIST_FILE
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

    curl $CURL_ARGS $URL -o $NAME -# >> $PROGRESS_FILE 2>&1

    ACTUAL_SIZE=$(stat --printf="%s" $NAME)
    if [ "$ACTUAL_SIZE" -ne "$SIZE" ] ; then
        echo "! Failed downloading ${CFC}/${TFC} (${NAME}), because size is not as expected (${SIZE} vs. ${ACTUAL_SIZE})" > $PROGRESS_FILE
        echo -n "########################################################################### ERR " >> $PROGRESS_FILE
        debug "! Failed downloading ${CFC}/${TFC} (${NAME}), because size is not as expected (${SIZE} vs. ${ACTUAL_SIZE})"
        # The remaining data that was downloaded will be removed
        rm $FILENAME
    else
        echo "- Finished downloading ${CFC}/${TFC} (${NAME})!" > $PROGRESS_FILE
        echo -n "######################################################################## 100.0% " >> $PROGRESS_FILE
        debug "- Finished downloading ${CFC}/${TFC} (${NAME})!"
        echo "$FILENAME" >> $FINISHED_LIST
    fi

    mv $PROGRESS_FILE ".downloader.$$.X$(printf "%05d" ${CFC}).progress"
}

main $@
