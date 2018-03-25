#!/bin/bash
UI_RESET="tput sgr0"
UI_FRONT="tput setaf"
UI_BACK="tput setab"

UIC_BLACK="7"
UIC_WHITE="0"
UIC_YELLOW=3

update_win_log () {
    tput cup 2 0
    cat $WINDOW_LOG | tail | \
        while read -r line ; do
            tput el
            echo "    $line"
        done
}

ui_setup () {
    clear
    $UI_FRONT $UIC_WHITE
    $UI_BACK $UIC_BLACK
    echo "    CLI-Downloader by steilerDev, v0.1    "
    $UI_RESET
    $UI_FRONT $UIC_YELLOW
    echo "Log:"
    $UI_RESET
    echo 
    tput cup 12 0
    $UI_FRONT $UIC_WHITE
    $UI_BACK $UIC_BLACK
    echo "                                          "
    $UI_RESET
}

show_download_status () {
    tput cup 12 0
    $UI_FRONT $UIC_WHITE
    $UI_BACK $UIC_BLACK
    tput el
    echo " Downloading...                           "
    $UI_RESET
    LINE_INDEX=$(($(tput lines)-13))
    for stat_file in $(find $1 -name '*.progress' -type f 2> /dev/null | sort); do
        if [ $LINE_INDEX -gt 0 ] ; then
            tput el
            head -n 1 $stat_file
            tput el
            tail -c 80 $stat_file
            echo
            ((LINE_INDEX -= 2))
        fi
    done
    sleep 1
}


