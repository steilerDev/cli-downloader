#!/bin/bash 

# Settings
DLC_DECRYPT_MODULE="dcrypt.sh"
DOWNLOAD_DIR="/media/files/Downloads"
FINISHED_FOLDER="_finished"

export INSTALL_DIR="/opt/cli-downloader"

DOWNLOAD_HELPER="$INSTALL_DIR/modules/helper/downloader.sh"
EXTRACT_HELPER="$INSTALL_DIR/modules/helper/extract.sh"
LINK_FILE=".downloader.$$.links"
TEMP_FILE=".downloader.$$.tmp"

main () {
    while getopts "he" opt; do
        case $opt in
            e)
                EDIT=true
                ;;
            h)
                show_help
                ;;
            \?)
                echo "Invalid option: -$OPTARG" >&2
                show_help
                ;;
        esac
    done

    load "helper/log.sh"
    savelog -q $DEBUG_LOG_FILE
    > $WINDOW_LOG
    ui_setup

    debug "$(date)"
    if [ $# -eq 0 ]; then
        log "No dlc container or file list provided!"
        show_help
    fi
    debug "Got the following files: $@"
    if [ "$EDIT" = true ] ; then
        debug "Edit mode on"
    fi
    
    # Create $LINK_FILE 
    create_link_file $@

    # Consume $LINK_FILE
    start_download
    
    log_finish "All done, thanks for using cli-downloader"
    ui_destroy
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
            log_finish "Finished processing ${INPUT}, renaming file!"
            if [ ! -e "$FINISHED_FOLDER" ] ; then
                mkdir "$FINISHED_FOLDER"
            fi
            mv "$INPUT" "$FINISHED_FOLDER/"
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

    for MOD in $INSTALL_DIR/modules/hoster/*; do
        if [ -d $MOD ]; then
            debug "$MOD is folder, skipping"
            continue
        fi
        if [ ! -x $MOD ]; then
            debug "$MOD is not executable"
            continue
        fi

        debug "$MOD is module"
        MOD_BASE=$(basename $MOD)
        MODULE_LINK_FILE=".downloader.$$.${MOD_BASE}.links"
        > $MODULE_LINK_FILE
        for HOST in $($DOWNLOAD_HELPER $MOD_BASE -h); do
            debug "Matching host $HOST for module $MOD"
            grep -E "^$HOST" $LINK_FILE >> $MODULE_LINK_FILE
            SED_HOST=$(echo $HOST | sed -e 's/[]\/$*.^[]/\\&/g')
            sed -i "/^$SED_HOST/d" $LINK_FILE
        done

        if [ "$(wc -l < $MODULE_LINK_FILE)" -gt 0 ]; then
            log_start "We have $(wc -l < $MODULE_LINK_FILE) links for this module, starting download..."

            
            CURR_DIR="$(pwd)"
            FQ_LINK=$(readlink -e $MODULE_LINK_FILE)

            PACKAGE_DIR="$DOWNLOAD_DIR/clid-$MOD_BASE-$$"
            if [ ! -d $PACKAGE_DIR ]; then
                mkdir -p $PACKAGE_DIR
            fi

            cd $PACKAGE_DIR
            log "Saving files to $PACKAGE_DIR"

            $DOWNLOAD_HELPER $MOD_BASE -l $FQ_LINK
            ui_reset

            extract_files $FQ_LINK
            cd $CURR_DIR 

        fi
        if [ -e $MODULE_LINK_FILE ]; then
            rm $MODULE_LINK_FILE
        fi
    done
    rm $LINK_FILE
}

extract_files () {
    if [ -e $EXTRACT_HELPER ]  ; then
        $EXTRACT_HELPER -l $1
    else
        log_error "Unable to find extract module ($EXTRACT_HELPER)"
        exit
    fi
}

show_help () {
    echo 
    echo "This is the cli-downloader by steilerDev, an extensible cli command line skript to download various files from different sharehoster"
    echo
    echo "Usage:"
    echo "   downloader <one ore more *.dlc, or *.links file>"
    echo "Optional arguments:"
    echo "   -e  Edit the link list before starting the download"
    echo "   -h  Show this help"
    echo 
    echo "Currently loaded module:"
    echo "    DLC decrypt:  $DLC_DECRYPT_MODULE"
    echo 
    echo "Loaded hoster:"
    for MOD in $INSTALL_DIR/modules/download/*; do
        if [ -d $MOD ]; then
            continue
        fi
        if [ ! -x $MOD ]; then
            continue
        fi
        echo "    $(basename $MOD) ($($MOD -h | tr $'\n' $'|' | rev | cut -c2- | rev))"
    done
    echo 
    echo "Downloader folder: $DOWNLOAD_DIR"
    exit
}

# Loads external modules based on $INSTALL_DIR/modules/$1
load () {
    if [ -e $INSTALL_DIR/modules/$1 ]; then
        source $INSTALL_DIR/modules/$1
    else
        echo "Unable to load module ($INSTALL_DIR/modules/$1), aborting!"
        exit
    fi
}
export -f load
main $@
