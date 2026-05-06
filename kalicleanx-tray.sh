#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════════
# KaliCleanX Tray — system-tray icon that launches the GUI
# Requires: yad
# ═══════════════════════════════════════════════════════════════════

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GUI="${SCRIPT_DIR}/kalicleanx-gui.sh"

if [[ $EUID -ne 0 ]]; then
    echo "[!] Run as root: sudo $(basename "$0")"
    exit 1
fi

if ! command -v yad &>/dev/null; then
    echo "[!] yad is required. Install with: sudo apt install yad"
    exit 1
fi

if [[ ! -x "$GUI" ]]; then
    chmod +x "$GUI" 2>/dev/null || true
fi

# Tray icon with right-click menu
yad --notification \
    --image=utilities-system-monitor \
    --text="KaliCleanX v1.2.0" \
    --menu="Open GUI!bash -c '${GUI}'|Run ALL (headless)!bash -c '${SCRIPT_DIR}/kalicleanx-final.sh --all'|View Log!bash -c '${SCRIPT_DIR}/kalicleanx-logviewer.sh'|Quit!quit" \
    --command="bash -c '${GUI}'" \
    2>/dev/null
