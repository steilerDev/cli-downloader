#!/bin/bash
UI_RESET="tput sgr0"
UI_FRONT="tput setaf"
UI_BACK="tput setab"

UIC_BLACK="7"
UIC_WHITE="0"
UIC_YELLOW=3

HEADER='CLI-Downloader by steilerDev, v0.1'

WIDTH=$(tput cols)
HALF_WIDTH=$(($WIDTH/2))
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
    ui_reset
}

ui_reset () {
    tput cup 0 0
    $UI_FRONT $UIC_WHITE
    $UI_BACK $UIC_BLACK
    PAD=$(( ($WIDTH/2) ))
    printf "%${PAD}s%-${PAD}s" "$HEADER"
    $UI_RESET

    $UI_FRONT $UIC_YELLOW
    echo "Log:"
    $UI_RESET

    tput cup 12 0
    $UI_FRONT $UIC_WHITE
    $UI_BACK $UIC_BLACK
    printf "%-${WIDTH}s"
    echo
    $UI_RESET
    while ! last_line ; do
        tput el
        echo
    done

    tput cup $(( $(tput lines) - 1 )) 0
    $UI_FRONT $UIC_WHITE
    $UI_BACK $UIC_BLACK
    printf "%-${WIDTH}s"
    $UI_RESET
}

ui_destroy () {
    tput cup $(( $(tput lines) - 1 )) 0
    tput el
}

init_ui () {
    tput cup 12 0
    $UI_FRONT $UIC_WHITE
    $UI_BACK $UIC_BLACK
    tput el
    printf "%-${WIDTH}s" "$1..."
    $UI_RESET
}

show_download_status () {
    tput cup 13 0
    for stat_file in $(find $1 -name '*.progress' -type f 2> /dev/null | sort); do
        if ! last_line ; then
            tput el
            head -n 1 $stat_file
            tput el
            tail -c 80 $stat_file
            echo
        fi
    done
    sleep 1
}

show_unrar_status () {
    tput cup 13 0
    $UI_RESET
    tput el
    grep -E "^Extracting from " $1 | tail -1
    tput el
    tail -n 1 $1 | grep -E "^\.\.\.|^Extracting  " | sed 's/^\.\.\.[ ]*//' | sed 's/^Extracting  //'
    sleep 1
}

last_line () {
    exec < /dev/tty
    oldstty=$(stty -g)
    stty raw -echo min 0
    # on my system, the following line can be replaced by the line below it
    echo -en "\033[6n" > /dev/tty
    # tput u7 > /dev/tty    # when TERM=xterm (and relatives)
    IFS=';' read -r -d R -a pos
    stty $oldstty
    # change from one-based to zero based so they work with: tput cup $row $col
    CUR_LINE=${pos[0]:2} # strip off the esc-[
    TOT_LINE=$(($(tput lines)-1))
    if [ "$CUR_LINE" -lt "$TOT_LINE" ] ; then
        return 1
    else
        return 0
    fi
}
