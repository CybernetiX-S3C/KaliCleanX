#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════════
# KaliCleanX Log Viewer — view, tail, search, or clear the activity log
#
# Usage:
#   kalicleanx-logviewer.sh              # interactive pager (less)
#   kalicleanx-logviewer.sh --tail [N]   # last N lines (default 25)
#   kalicleanx-logviewer.sh --search STR # grep for a string
#   kalicleanx-logviewer.sh --clear      # truncate the log
#   kalicleanx-logviewer.sh --help       # this message
# ═══════════════════════════════════════════════════════════════════

LOG_FILE="/var/log/kalicleanx.log"
GREEN="\e[32m"; YELLOW="\e[33m"; RED="\e[31m"; BLUE="\e[34m"; RESET="\e[0m"

usage() {
    echo "KaliCleanX Log Viewer"
    echo
    echo "Usage: $(basename "$0") [OPTION]"
    echo
    echo "Options:"
    echo "  (no args)          Open the full log in an interactive pager"
    echo "  --tail [N]         Show the last N log entries (default: 25)"
    echo "  --search <string>  Search for a string in the log"
    echo "  --clear            Truncate the log file (requires root)"
    echo "  --help, -h         Show this help message"
    exit 0
}

check_log() {
    if [[ ! -f "$LOG_FILE" ]]; then
        echo -e "${YELLOW}[~] Log file not found: ${LOG_FILE}${RESET}"
        echo -e "${YELLOW}    Run KaliCleanX at least once to create it.${RESET}"
        exit 1
    fi
}

case "${1:-}" in
    --help|-h)
        usage
        ;;
    --tail)
        check_log
        local_n="${2:-25}"
        echo -e "${BLUE}[*] Last ${local_n} log entries:${RESET}"
        echo
        tail -n "$local_n" "$LOG_FILE"
        ;;
    --search)
        check_log
        if [[ -z "${2:-}" ]]; then
            echo -e "${RED}[!] Please provide a search string.${RESET}"
            echo "    Example: $(basename "$0") --search \"APT\""
            exit 1
        fi
        echo -e "${BLUE}[*] Searching for: ${2}${RESET}"
        echo
        grep -i --color=auto "$2" "$LOG_FILE" || echo -e "${YELLOW}[~] No matches found.${RESET}"
        ;;
    --clear)
        if [[ $EUID -ne 0 ]]; then
            echo -e "${RED}[!] Clearing the log requires root.${RESET}"
            exit 1
        fi
        check_log
        read -rp "Clear the KaliCleanX log? [y/N]: " confirm
        if [[ "$confirm" =~ ^[Yy]$ ]]; then
            : > "$LOG_FILE"
            echo -e "${GREEN}[+] Log file cleared.${RESET}"
        else
            echo -e "${YELLOW}[~] Cancelled.${RESET}"
        fi
        ;;
    "")
        check_log
        echo -e "${BLUE}[*] Opening log: ${LOG_FILE}${RESET}"
        less "$LOG_FILE" 2>/dev/null || cat "$LOG_FILE"
        ;;
    *)
        echo -e "${RED}[!] Unknown option: ${1}${RESET}"
        usage
        ;;
esac
