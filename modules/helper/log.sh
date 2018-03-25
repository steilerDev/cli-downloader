#!/bin/bash 

# Color variables
GREEN='\033[0;32m'
CYAN='\033[0;36m'
RED='\033[1;31m'
NC='\033[0m'

export DEBUG_LOG_FILE="/tmp/debug.log"
export WINDOW_LOG="/tmp/window.log"

load "helper/ui.sh"

log_start () {
    echo -e "${CYAN}$@${NC}" >> $WINDOW_LOG
    debug $@
    update_win_log
}

log_finish () {
    echo -e "${GREEN}$@${NC}" >> $WINDOW_LOG
    debug $@
    update_win_log
}

log_error () {
    echo -e "${RED}$@${NC}" >> $WINDOW_LOG
    debug $@
    update_win_log
}

log () {
    echo $@  >> $WINDOW_LOG
    debug $@
    update_win_log
}

debug () {
    echo $@ >> $DEBUG_LOG_FILE
}
