#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════════
# KaliCleanX GUI — yad-based graphical wrapper for kalicleanx-final.sh
# ═══════════════════════════════════════════════════════════════════

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLEANER="${SCRIPT_DIR}/kalicleanx-final.sh"

# ── Root check ──────────────────────────────────────────────────────
if [[ $EUID -ne 0 ]]; then
    if command -v yad &>/dev/null; then
        yad --error --title="KaliCleanX" \
            --text="Please run this GUI as root:\n\nsudo $0" \
            --width=350 --center 2>/dev/null
    else
        echo "[!] Please run as root: sudo $0"
    fi
    exit 1
fi

# ── Dependency check ────────────────────────────────────────────────
if ! command -v yad &>/dev/null; then
    echo "[!] yad is required for the GUI."
    echo "    Install with:  sudo apt install yad"
    exit 1
fi

if [[ ! -x "$CLEANER" ]]; then
    chmod +x "$CLEANER" 2>/dev/null || true
fi

# ── Helper: run a cleaner action and display output in a dialog ─────
run_action() {
    local menu_num="$1"
    local label="$2"
    export KALICLEANX_NONINTERACTIVE=1
    bash "$CLEANER" <<< "$menu_num" 2>&1 | sed 's/\x1b\[[0-9;]*m//g' | \
        yad --text-info \
            --title="KaliCleanX — ${label}" \
            --width=720 --height=520 --center \
            --fontname="Monospace 10" \
            --button="Close:0" 2>/dev/null
    unset KALICLEANX_NONINTERACTIVE
}

# ── Main loop ───────────────────────────────────────────────────────
while true; do
    CHOICE=$(yad --width=480 --height=620 \
        --title="KaliCleanX GUI v1.2.0" \
        --center --window-icon=utilities-system-monitor \
        --list --column="Action" --column="Description" \
        "System Status"   "View CPU / RAM / disk / network" \
        "Log Sizes"       "View largest log files" \
        "RAM Clean"       "Drop filesystem caches" \
        "Swap Reset"      "Reset swap space" \
        "Apt Cache Clean" "Clean APT package cache" \
        "Journal Clean"   "Vacuum systemd journal logs" \
        "Rotated Logs"    "Remove rotated / compressed logs" \
        "DNS Flush"       "Flush DNS resolver cache" \
        "Temp Clean"      "Clean /tmp and /var/tmp" \
        "User Cache"      "Clean user caches / thumbnails / trash" \
        "Crash Reports"   "Clean /var/crash and coredumps" \
        "Pip Cache"       "Clean pip / pip3 cache" \
        "NPM Cache"       "Clean npm / yarn / pnpm cache" \
        "Flatpak Cache"   "Remove unused Flatpak runtimes" \
        "Snap Cache"      "Remove old Snap revisions" \
        "Check /boot"     "Show /boot usage and kernels" \
        "Run ALL"         "★ Run all safe cleaners ★" \
        "View Log"        "View KaliCleanX activity log" \
        "Quit"            "Exit KaliCleanX GUI" \
        --button="Close:1" 2>/dev/null)

    RET=$?
    [[ $RET -ne 0 ]] && exit 0

    ACTION=$(echo "$CHOICE" | cut -d'|' -f1)

    case "$ACTION" in
        "System Status")   run_action 1  "System Status" ;;
        "Log Sizes")       run_action 2  "Log Sizes" ;;
        "RAM Clean")       run_action 3  "RAM Clean" ;;
        "Swap Reset")      run_action 4  "Swap Reset" ;;
        "Apt Cache Clean") run_action 5  "APT Cache Clean" ;;
        "Journal Clean")   run_action 6  "Journal Vacuum" ;;
        "Rotated Logs")    run_action 7  "Rotated Logs" ;;
        "DNS Flush")       run_action 8  "DNS Flush" ;;
        "Temp Clean")      run_action 9  "Temp Files" ;;
        "User Cache")      run_action 10 "User Cache" ;;
        "Crash Reports")   run_action 11 "Crash Reports" ;;
        "Pip Cache")       run_action 12 "Pip Cache" ;;
        "NPM Cache")       run_action 13 "NPM Cache" ;;
        "Flatpak Cache")   run_action 14 "Flatpak Cache" ;;
        "Snap Cache")      run_action 15 "Snap Cache" ;;
        "Check /boot")     run_action 16 "Check /boot" ;;
        "Run ALL")         run_action 17 "Run ALL Cleaners" ;;
        "View Log")        run_action 18 "Activity Log" ;;
        "Quit")            exit 0 ;;
    esac
done
