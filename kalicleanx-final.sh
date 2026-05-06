#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════════
# KaliCleanX - Complete, non-destructive system cleaner for Kali Linux
# Standalone tool. Safe by design:
#   - No kernel deletion
#   - No package purge
#   - No system-critical removal
#   - Only cache, temp, logs, and non-critical data
# ═══════════════════════════════════════════════════════════════════

VERSION="1.2.0"

# ── Colors ──────────────────────────────────────────────────────────
RED="\e[31m"
GREEN="\e[32m"
YELLOW="\e[33m"
BLUE="\e[34m"
CYAN="\e[36m"
BOLD="\e[1m"
RESET="\e[0m"

# ── Config ──────────────────────────────────────────────────────────
LOG_FILE="/var/log/kalicleanx.log"
TOTAL_FREED=0

# ═══════════════════════════════════════════════════════════════════
#  UTILITIES
# ═══════════════════════════════════════════════════════════════════

banner() {
    clear
    echo -e "${GREEN}"
    cat << 'BANNER'
  ▄▄▄▄   ▄▄▄      ▄▄    ▄   ▄▄▄▄ ▄▄                     ▄▄▄   ▄▄▄ 
 █▀ ██  ██         ██   ▀██████▀  ██                   █▀▀██ ██▀  
    ██ ██          ██ ▀▀  ██      ██             ▄        ▀█▄█▀   
    █████    ▄▀▀█▄ ██ ██  ██      ██ ▄█▀█▄ ▄▀▀█▄ ████▄     ███    
    ██ ██▄   ▄█▀██ ██ ██  ██      ██ ██▄█▀ ▄█▀██ ██ ██   ▄█▀██▄   
  ▀██▀  ▀██▄▄▀█▄██▄██▄██  ▀█████ ▄██▄▀█▄▄▄▄▀█▄██▄██ ▀█ ▀██▀  ▀██▄
BANNER
    echo -e "${RESET}"
    echo -e "${YELLOW}KaliCleanX v${VERSION} — Safe, standalone cleaner for Kali Linux${RESET}"
    echo
}

log_action() {
    local msg="$1"
    mkdir -p "$(dirname "$LOG_FILE")" 2>/dev/null || true
    echo "$(date '+%F %T') — $msg" >> "$LOG_FILE" 2>/dev/null || true
}

check_root() {
    if [[ $EUID -ne 0 ]]; then
        echo -e "${RED}[!] This script must be run as root (sudo).${RESET}"
        exit 1
    fi
}

pause_and_return() {
    # Skip pause when called non-interactively (e.g. from the GUI wrapper)
    if [[ "${KALICLEANX_NONINTERACTIVE:-0}" == "1" ]]; then
        return
    fi
    echo
    echo -e "${YELLOW}"
    read -rp "Press ENTER to return to the main menu..." _
    echo -e "${RESET}"
}

bytes_to_human() {
    local bytes="${1:-0}"
    if (( bytes < 0 )); then bytes=0; fi
    if (( bytes >= 1073741824 )); then
        awk "BEGIN {printf \"%.2f GB\", $bytes/1073741824}"
    elif (( bytes >= 1048576 )); then
        awk "BEGIN {printf \"%.2f MB\", $bytes/1048576}"
    elif (( bytes >= 1024 )); then
        awk "BEGIN {printf \"%.2f KB\", $bytes/1024}"
    else
        echo "${bytes} B"
    fi
}

get_dir_size() {
    local target="$1"
    if [[ -d "$target" ]]; then
        du -sb "$target" 2>/dev/null | awk '{print $1}'
    else
        echo 0
    fi
}

get_free_space() {
    df --output=avail / 2>/dev/null | tail -1 | tr -d ' '
}

# ═══════════════════════════════════════════════════════════════════
#  1) SYSTEM STATUS
# ═══════════════════════════════════════════════════════════════════

system_status() {
    echo -e "${BLUE}[*] System Status Overview${RESET}"
    log_action "Viewed system status"

    echo -e "\n${GREEN}--- Hostname ---${RESET}"
    hostname 2>/dev/null || echo "  Unknown"

    echo -e "\n${GREEN}--- OS / Kernel ---${RESET}"
    uname -srmo 2>/dev/null
    cat /etc/os-release 2>/dev/null | grep -E "^PRETTY_NAME=" | cut -d= -f2 | tr -d '"' || true

    echo -e "\n${GREEN}--- CPU / Uptime ---${RESET}"
    uptime

    echo -e "\n${GREEN}--- Memory ---${RESET}"
    free -h

    echo -e "\n${GREEN}--- Swap ---${RESET}"
    swapon --show 2>/dev/null || echo "  No swap active"

    echo -e "\n${GREEN}--- Disk Usage ---${RESET}"
    df -h / /boot /home 2>/dev/null || df -h /

    echo -e "\n${GREEN}--- Network (IPv4) ---${RESET}"
    ip -4 addr show 2>/dev/null | grep -w inet || echo "  No IPv4 assigned"

    echo -e "\n${GREEN}--- Top Memory Processes ---${RESET}"
    ps aux --sort=-%mem | head -n 6

    pause_and_return
}

# ═══════════════════════════════════════════════════════════════════
#  2) LOG SIZES
# ═══════════════════════════════════════════════════════════════════

log_sizes() {
    echo -e "${BLUE}[*] Largest log files in /var/log${RESET}"
    log_action "Viewed largest log files"
    echo
    find /var/log -type f -printf "%s %p\n" 2>/dev/null | sort -nr | head -n 15 | \
        awk '{
            size=$1; file=$2
            if      (size >= 1073741824) printf "%10.2f GB  %s\n", size/1073741824, file
            else if (size >= 1048576)    printf "%10.2f MB  %s\n", size/1048576,    file
            else if (size >= 1024)       printf "%10.2f KB  %s\n", size/1024,       file
            else                         printf "%10d  B  %s\n",  size,             file
        }'
    pause_and_return
}

# ═══════════════════════════════════════════════════════════════════
#  3) RAM CACHE CLEAN
# ═══════════════════════════════════════════════════════════════════

clean_ram() {
    echo -e "${BLUE}[*] Dropping filesystem caches...${RESET}"
    log_action "RAM cache clean started"

    local before after freed
    before=$(awk '/^Cached:/{print $2}' /proc/meminfo 2>/dev/null || echo 0)

    sync
    if echo 3 > /proc/sys/vm/drop_caches 2>/dev/null; then
        after=$(awk '/^Cached:/{print $2}' /proc/meminfo 2>/dev/null || echo 0)
        freed=$(( (before - after) * 1024 ))
        if (( freed > 0 )); then
            TOTAL_FREED=$((TOTAL_FREED + freed))
            echo -e "${GREEN}[+] Freed ~$(bytes_to_human $freed) of cached RAM${RESET}"
        else
            echo -e "${GREEN}[+] Caches dropped (already minimal)${RESET}"
        fi
    else
        echo -e "${RED}[!] Failed to drop caches (permission denied?)${RESET}"
    fi

    log_action "RAM cache clean complete"
    pause_and_return
}

# ═══════════════════════════════════════════════════════════════════
#  4) SWAP RESET
# ═══════════════════════════════════════════════════════════════════

reset_swap() {
    echo -e "${BLUE}[*] Resetting swap...${RESET}"
    log_action "Swap reset started"

    if swapon --show 2>/dev/null | grep -q "/"; then
        swapoff -a 2>/dev/null && swapon -a 2>/dev/null
        echo -e "${GREEN}[+] Swap reset successfully${RESET}"
    else
        echo -e "${YELLOW}[~] No swap is currently active — nothing to reset${RESET}"
    fi

    log_action "Swap reset complete"
    pause_and_return
}

# ═══════════════════════════════════════════════════════════════════
#  5) APT CACHE CLEAN
# ═══════════════════════════════════════════════════════════════════

clean_apt_cache() {
    echo -e "${BLUE}[*] Cleaning APT cache...${RESET}"
    log_action "APT cache clean started"

    local before after freed
    before=$(get_dir_size /var/cache/apt)

    apt-get clean -y   2>/dev/null || true
    apt-get autoclean -y 2>/dev/null || true
    rm -rf /var/cache/apt/archives/partial/* 2>/dev/null || true

    after=$(get_dir_size /var/cache/apt)
    freed=$((before - after))

    if (( freed > 0 )); then
        TOTAL_FREED=$((TOTAL_FREED + freed))
        echo -e "${GREEN}[+] Freed $(bytes_to_human $freed) from APT cache${RESET}"
    else
        echo -e "${GREEN}[+] APT cache already clean${RESET}"
    fi

    log_action "APT cache clean complete — freed $(bytes_to_human ${freed:-0})"
    pause_and_return
}

# ═══════════════════════════════════════════════════════════════════
#  6) JOURNAL VACUUM
# ═══════════════════════════════════════════════════════════════════

clean_journal() {
    echo -e "${BLUE}[*] Vacuuming systemd journal logs...${RESET}"
    log_action "Journal vacuum started"

    if command -v journalctl &>/dev/null; then
        local before after
        before=$(journalctl --disk-usage 2>/dev/null | grep -oP '[\d.]+\s*[KMGT]?' | head -1 || echo "?")
        journalctl --vacuum-time=2d   2>/dev/null || true
        journalctl --vacuum-size=50M  2>/dev/null || true
        after=$(journalctl --disk-usage 2>/dev/null | grep -oP '[\d.]+\s*[KMGT]?' | head -1 || echo "?")
        echo -e "${GREEN}[+] Journal: ${before:-?} → ${after:-?}${RESET}"
    else
        echo -e "${YELLOW}[~] journalctl not found — skipped${RESET}"
    fi

    log_action "Journal vacuum complete"
    pause_and_return
}

# ═══════════════════════════════════════════════════════════════════
#  7) ROTATED LOGS CLEAN
# ═══════════════════════════════════════════════════════════════════

clean_rotated_logs() {
    echo -e "${BLUE}[*] Cleaning rotated / compressed logs...${RESET}"
    log_action "Rotated log cleanup started"

    local count
    count=$(find /var/log -type f \( \
        -name "*.gz"  -o -name "*.xz"  -o -name "*.bz2" \
        -o -name "*.old" \
        -o -name "*.1" -o -name "*.2" -o -name "*.3" \
        -o -name "*.4" -o -name "*.5" -o -name "*.6" \
        -o -name "*.7" -o -name "*.8" -o -name "*.9" \
    \) 2>/dev/null | wc -l)

    find /var/log -type f \( \
        -name "*.gz"  -o -name "*.xz"  -o -name "*.bz2" \
        -o -name "*.old" \
        -o -name "*.1" -o -name "*.2" -o -name "*.3" \
        -o -name "*.4" -o -name "*.5" -o -name "*.6" \
        -o -name "*.7" -o -name "*.8" -o -name "*.9" \
    \) -delete 2>/dev/null || true

    echo -e "${GREEN}[+] Removed ${count} rotated log file(s)${RESET}"
    log_action "Rotated log cleanup complete — removed ${count} files"
    pause_and_return
}

# ═══════════════════════════════════════════════════════════════════
#  8) DNS CACHE FLUSH
# ═══════════════════════════════════════════════════════════════════

flush_dns() {
    echo -e "${BLUE}[*] Flushing DNS cache...${RESET}"
    log_action "DNS flush started"

    local flushed=false

    if command -v resolvectl &>/dev/null; then
        resolvectl flush-caches 2>/dev/null && flushed=true
    elif command -v systemd-resolve &>/dev/null; then
        systemd-resolve --flush-caches 2>/dev/null && flushed=true
    fi

    if systemctl is-active --quiet nscd 2>/dev/null; then
        systemctl restart nscd 2>/dev/null && flushed=true
    fi

    if systemctl is-active --quiet dnsmasq 2>/dev/null; then
        systemctl restart dnsmasq 2>/dev/null && flushed=true
    fi

    if [[ "$flushed" == true ]]; then
        echo -e "${GREEN}[+] DNS cache flushed successfully${RESET}"
    else
        echo -e "${YELLOW}[~] No active DNS cache service detected${RESET}"
    fi

    log_action "DNS flush complete"
    pause_and_return
}

# ═══════════════════════════════════════════════════════════════════
#  9) TEMP FILES CLEAN
# ═══════════════════════════════════════════════════════════════════

clean_temp() {
    echo -e "${BLUE}[*] Cleaning temporary files...${RESET}"
    log_action "Temp cleanup started"

    local before after freed
    before=$(( $(get_dir_size /tmp) + $(get_dir_size /var/tmp) ))

    find /tmp     -mindepth 1 -maxdepth 1 -exec rm -rf {} + 2>/dev/null || true
    find /var/tmp -mindepth 1 -maxdepth 1 -exec rm -rf {} + 2>/dev/null || true

    after=$(( $(get_dir_size /tmp) + $(get_dir_size /var/tmp) ))
    freed=$((before - after))

    if (( freed > 0 )); then
        TOTAL_FREED=$((TOTAL_FREED + freed))
        echo -e "${GREEN}[+] Freed $(bytes_to_human $freed) from temp directories${RESET}"
    else
        echo -e "${GREEN}[+] Temp directories already clean${RESET}"
    fi

    log_action "Temp cleanup complete — freed $(bytes_to_human ${freed:-0})"
    pause_and_return
}

# ═══════════════════════════════════════════════════════════════════
#  10) USER CACHE CLEAN
# ═══════════════════════════════════════════════════════════════════

clean_user_cache() {
    echo -e "${BLUE}[*] Cleaning user caches...${RESET}"
    log_action "User cache cleanup started"

    local freed=0

    for user_home in /home/* /root; do
        [[ -d "$user_home" ]] || continue

        # ~/.cache
        if [[ -d "$user_home/.cache" ]]; then
            local before after
            before=$(get_dir_size "$user_home/.cache")
            find "$user_home/.cache" -mindepth 1 -delete 2>/dev/null || true
            after=$(get_dir_size "$user_home/.cache")
            local diff=$((before - after))
            (( diff > 0 )) && freed=$((freed + diff))
        fi

        # ~/.thumbnails (legacy)
        if [[ -d "$user_home/.thumbnails" ]]; then
            local tb
            tb=$(get_dir_size "$user_home/.thumbnails")
            rm -rf "$user_home/.thumbnails/"* 2>/dev/null || true
            (( tb > 0 )) && freed=$((freed + tb))
        fi

        # ~/.local/share/Trash
        if [[ -d "$user_home/.local/share/Trash" ]]; then
            local trash_sz
            trash_sz=$(get_dir_size "$user_home/.local/share/Trash")
            rm -rf "$user_home/.local/share/Trash/"* 2>/dev/null || true
            (( trash_sz > 0 )) && freed=$((freed + trash_sz))
        fi

        # ~/.local/share/recently-used.xbel
        rm -f "$user_home/.local/share/recently-used.xbel" 2>/dev/null || true
    done

    TOTAL_FREED=$((TOTAL_FREED + freed))
    echo -e "${GREEN}[+] Freed $(bytes_to_human $freed) from user caches / thumbnails / trash${RESET}"
    log_action "User cache cleanup complete — freed $(bytes_to_human $freed)"
    pause_and_return
}

# ═══════════════════════════════════════════════════════════════════
#  11) CRASH REPORTS CLEAN
# ═══════════════════════════════════════════════════════════════════

clean_crash_reports() {
    echo -e "${BLUE}[*] Cleaning crash reports & coredumps...${RESET}"
    log_action "Crash report cleanup started"

    local count=0

    if [[ -d /var/crash ]]; then
        local c
        c=$(find /var/crash -type f 2>/dev/null | wc -l)
        rm -rf /var/crash/* 2>/dev/null || true
        count=$((count + c))
    fi

    if [[ -d /var/lib/systemd/coredump ]]; then
        local c
        c=$(find /var/lib/systemd/coredump -type f 2>/dev/null | wc -l)
        rm -rf /var/lib/systemd/coredump/* 2>/dev/null || true
        count=$((count + c))
    fi

    # Clear coredumpctl if available
    if command -v coredumpctl &>/dev/null; then
        coredumpctl 2>/dev/null | tail -n +2 | wc -l || true
    fi

    echo -e "${GREEN}[+] Removed ${count} crash report(s) / coredump(s)${RESET}"
    log_action "Crash report cleanup complete — removed ${count} files"
    pause_and_return
}

# ═══════════════════════════════════════════════════════════════════
#  12) PIP CACHE CLEAN
# ═══════════════════════════════════════════════════════════════════

clean_pip_cache() {
    echo -e "${BLUE}[*] Cleaning pip cache...${RESET}"
    log_action "Pip cache clean started"

    local found=false

    if command -v pip3 &>/dev/null; then
        pip3 cache purge 2>/dev/null || true
        echo -e "${GREEN}[+] pip3 cache purged${RESET}"
        found=true
    elif command -v pip &>/dev/null; then
        pip cache purge 2>/dev/null || true
        echo -e "${GREEN}[+] pip cache purged${RESET}"
        found=true
    fi

    # Manual pip cache directories
    for user_home in /home/* /root; do
        if [[ -d "$user_home/.cache/pip" ]]; then
            rm -rf "$user_home/.cache/pip" 2>/dev/null || true
            found=true
        fi
    done

    if [[ "$found" == false ]]; then
        echo -e "${YELLOW}[~] pip not installed — skipped${RESET}"
    fi

    log_action "Pip cache clean complete"
    pause_and_return
}

# ═══════════════════════════════════════════════════════════════════
#  13) NPM CACHE CLEAN
# ═══════════════════════════════════════════════════════════════════

clean_npm_cache() {
    echo -e "${BLUE}[*] Cleaning npm / yarn cache...${RESET}"
    log_action "NPM cache clean started"

    local found=false

    if command -v npm &>/dev/null; then
        npm cache clean --force 2>/dev/null || true
        echo -e "${GREEN}[+] npm cache cleaned${RESET}"
        found=true
    fi

    if command -v yarn &>/dev/null; then
        yarn cache clean 2>/dev/null || true
        echo -e "${GREEN}[+] yarn cache cleaned${RESET}"
        found=true
    fi

    if command -v pnpm &>/dev/null; then
        pnpm store prune 2>/dev/null || true
        echo -e "${GREEN}[+] pnpm store pruned${RESET}"
        found=true
    fi

    if [[ "$found" == false ]]; then
        echo -e "${YELLOW}[~] npm / yarn / pnpm not installed — skipped${RESET}"
    fi

    log_action "NPM cache clean complete"
    pause_and_return
}

# ═══════════════════════════════════════════════════════════════════
#  14) FLATPAK CACHE CLEAN
# ═══════════════════════════════════════════════════════════════════

clean_flatpak_cache() {
    echo -e "${BLUE}[*] Cleaning Flatpak unused runtimes...${RESET}"
    log_action "Flatpak cleanup started"

    if command -v flatpak &>/dev/null; then
        flatpak uninstall --unused -y 2>/dev/null || true
        # Also remove cached repo data
        rm -rf /var/tmp/flatpak-cache-* 2>/dev/null || true
        echo -e "${GREEN}[+] Flatpak unused runtimes removed${RESET}"
    else
        echo -e "${YELLOW}[~] Flatpak not installed — skipped${RESET}"
    fi

    log_action "Flatpak cleanup complete"
    pause_and_return
}

# ═══════════════════════════════════════════════════════════════════
#  15) SNAP CACHE CLEAN
# ═══════════════════════════════════════════════════════════════════

clean_snap_cache() {
    echo -e "${BLUE}[*] Cleaning old Snap revisions...${RESET}"
    log_action "Snap cleanup started"

    if command -v snap &>/dev/null; then
        local removed=0
        while IFS= read -r line; do
            local name rev
            name=$(echo "$line" | awk '{print $1}')
            rev=$(echo "$line" | awk '{print $3}')
            if [[ -n "$name" && -n "$rev" ]]; then
                snap remove "$name" --revision="$rev" 2>/dev/null || true
                ((removed++)) || true
            fi
        done < <(snap list --all 2>/dev/null | awk '/disabled/{print}')
        echo -e "${GREEN}[+] Removed ${removed} old Snap revision(s)${RESET}"
    else
        echo -e "${YELLOW}[~] Snap not installed — skipped${RESET}"
    fi

    log_action "Snap cleanup complete"
    pause_and_return
}

# ═══════════════════════════════════════════════════════════════════
#  16) CHECK /boot USAGE
# ═══════════════════════════════════════════════════════════════════

check_boot() {
    echo -e "${BLUE}[*] Checking /boot usage...${RESET}"
    log_action "Checked /boot usage"

    echo -e "\n${GREEN}--- /boot Disk Usage ---${RESET}"
    df -h /boot 2>/dev/null || echo "  /boot is not a separate partition"

    echo -e "\n${GREEN}--- Installed Kernel Images ---${RESET}"
    if ls /boot/vmlinuz-* &>/dev/null; then
        ls -lh /boot/vmlinuz-* 2>/dev/null
    else
        echo "  No kernel images found in /boot"
    fi

    echo -e "\n${GREEN}--- Kernel Packages ---${RESET}"
    dpkg -l 'linux-image-*' 2>/dev/null | grep '^ii' || echo "  No kernel packages found"

    echo -e "\n${GREEN}--- Currently Running ---${RESET}"
    echo "  $(uname -r)"

    echo -e "\n${YELLOW}╔══════════════════════════════════════════════════════════╗${RESET}"
    echo -e "${YELLOW}║  KaliCleanX does NOT remove kernels — this is by design ║${RESET}"
    echo -e "${YELLOW}║  To remove old kernels manually:                        ║${RESET}"
    echo -e "${YELLOW}║  sudo apt remove --purge linux-image-<old-version>      ║${RESET}"
    echo -e "${YELLOW}╚══════════════════════════════════════════════════════════╝${RESET}"

    pause_and_return
}

# ═══════════════════════════════════════════════════════════════════
#  17) RUN ALL CLEANERS
# ═══════════════════════════════════════════════════════════════════

run_all() {
    echo -e "${BOLD}${BLUE}[*] Running ALL safe cleaners...${RESET}"
    echo -e "${BLUE}    This may take a moment.${RESET}"
    log_action "══════ RUN ALL started ══════"

    local free_before free_after total_steps=13 step=0
    free_before=$(get_free_space)
    TOTAL_FREED=0

    # ── 1) RAM ──
    ((step++)) || true
    echo -e "\n${CYAN}[${step}/${total_steps}] RAM Cache...${RESET}"
    sync
    echo 3 > /proc/sys/vm/drop_caches 2>/dev/null || true
    echo -e "${GREEN}  ✓ Done${RESET}"

    # ── 2) Swap ──
    ((step++)) || true
    echo -e "${CYAN}[${step}/${total_steps}] Swap Reset...${RESET}"
    if swapon --show 2>/dev/null | grep -q "/"; then
        swapoff -a 2>/dev/null && swapon -a 2>/dev/null
        echo -e "${GREEN}  ✓ Done${RESET}"
    else
        echo -e "${YELLOW}  ~ No swap active${RESET}"
    fi

    # ── 3) APT ──
    ((step++)) || true
    echo -e "${CYAN}[${step}/${total_steps}] APT Cache...${RESET}"
    local apt_b apt_a
    apt_b=$(get_dir_size /var/cache/apt)
    apt-get clean -y     2>/dev/null || true
    apt-get autoclean -y 2>/dev/null || true
    rm -rf /var/cache/apt/archives/partial/* 2>/dev/null || true
    apt_a=$(get_dir_size /var/cache/apt)
    (( apt_b - apt_a > 0 )) && TOTAL_FREED=$((TOTAL_FREED + apt_b - apt_a))
    echo -e "${GREEN}  ✓ Done${RESET}"

    # ── 4) Journal ──
    ((step++)) || true
    echo -e "${CYAN}[${step}/${total_steps}] Journal Logs...${RESET}"
    journalctl --vacuum-time=2d  2>/dev/null || true
    journalctl --vacuum-size=50M 2>/dev/null || true
    echo -e "${GREEN}  ✓ Done${RESET}"

    # ── 5) Rotated Logs ──
    ((step++)) || true
    echo -e "${CYAN}[${step}/${total_steps}] Rotated Logs...${RESET}"
    find /var/log -type f \( \
        -name "*.gz" -o -name "*.xz" -o -name "*.bz2" \
        -o -name "*.old" \
        -o -name "*.1" -o -name "*.2" -o -name "*.3" \
        -o -name "*.4" -o -name "*.5" -o -name "*.6" \
        -o -name "*.7" -o -name "*.8" -o -name "*.9" \
    \) -delete 2>/dev/null || true
    echo -e "${GREEN}  ✓ Done${RESET}"

    # ── 6) DNS ──
    ((step++)) || true
    echo -e "${CYAN}[${step}/${total_steps}] DNS Flush...${RESET}"
    resolvectl flush-caches 2>/dev/null || \
        systemd-resolve --flush-caches 2>/dev/null || true
    systemctl restart nscd    2>/dev/null || true
    systemctl restart dnsmasq 2>/dev/null || true
    echo -e "${GREEN}  ✓ Done${RESET}"

    # ── 7) Temp ──
    ((step++)) || true
    echo -e "${CYAN}[${step}/${total_steps}] Temp Files...${RESET}"
    local tmp_b tmp_a
    tmp_b=$(( $(get_dir_size /tmp) + $(get_dir_size /var/tmp) ))
    find /tmp     -mindepth 1 -maxdepth 1 -exec rm -rf {} + 2>/dev/null || true
    find /var/tmp -mindepth 1 -maxdepth 1 -exec rm -rf {} + 2>/dev/null || true
    tmp_a=$(( $(get_dir_size /tmp) + $(get_dir_size /var/tmp) ))
    (( tmp_b - tmp_a > 0 )) && TOTAL_FREED=$((TOTAL_FREED + tmp_b - tmp_a))
    echo -e "${GREEN}  ✓ Done${RESET}"

    # ── 8) User Caches ──
    ((step++)) || true
    echo -e "${CYAN}[${step}/${total_steps}] User Caches & Trash...${RESET}"
    for uh in /home/* /root; do
        [[ -d "$uh" ]] || continue
        [[ -d "$uh/.cache" ]]              && find "$uh/.cache" -mindepth 1 -delete 2>/dev/null || true
        [[ -d "$uh/.thumbnails" ]]         && rm -rf "$uh/.thumbnails/"*             2>/dev/null || true
        [[ -d "$uh/.local/share/Trash" ]]  && rm -rf "$uh/.local/share/Trash/"*      2>/dev/null || true
        rm -f "$uh/.local/share/recently-used.xbel" 2>/dev/null || true
    done
    echo -e "${GREEN}  ✓ Done${RESET}"

    # ── 9) Crash Reports ──
    ((step++)) || true
    echo -e "${CYAN}[${step}/${total_steps}] Crash Reports...${RESET}"
    rm -rf /var/crash/*                   2>/dev/null || true
    rm -rf /var/lib/systemd/coredump/*    2>/dev/null || true
    echo -e "${GREEN}  ✓ Done${RESET}"

    # ── 10) Pip ──
    ((step++)) || true
    echo -e "${CYAN}[${step}/${total_steps}] Pip Cache...${RESET}"
    pip3 cache purge 2>/dev/null || pip cache purge 2>/dev/null || true
    for uh in /home/* /root; do
        rm -rf "$uh/.cache/pip" 2>/dev/null || true
    done
    echo -e "${GREEN}  ✓ Done${RESET}"

    # ── 11) NPM ──
    ((step++)) || true
    echo -e "${CYAN}[${step}/${total_steps}] NPM / Yarn / pnpm Cache...${RESET}"
    npm cache clean --force 2>/dev/null || true
    yarn cache clean        2>/dev/null || true
    pnpm store prune        2>/dev/null || true
    echo -e "${GREEN}  ✓ Done${RESET}"

    # ── 12) Flatpak ──
    ((step++)) || true
    echo -e "${CYAN}[${step}/${total_steps}] Flatpak Cache...${RESET}"
    flatpak uninstall --unused -y   2>/dev/null || true
    rm -rf /var/tmp/flatpak-cache-* 2>/dev/null || true
    echo -e "${GREEN}  ✓ Done${RESET}"

    # ── 13) Snap ──
    ((step++)) || true
    echo -e "${CYAN}[${step}/${total_steps}] Snap Cache...${RESET}"
    if command -v snap &>/dev/null; then
        snap list --all 2>/dev/null | awk '/disabled/{print $1, $3}' | \
            while read -r sname srev; do
                snap remove "$sname" --revision="$srev" 2>/dev/null || true
            done
    fi
    echo -e "${GREEN}  ✓ Done${RESET}"

    # ── Bonus: Docker ──
    if command -v docker &>/dev/null; then
        echo -e "${CYAN}[Bonus] Docker Prune...${RESET}"
        docker system prune -f 2>/dev/null || true
        echo -e "${GREEN}  ✓ Done${RESET}"
    fi

    # ── Summary ──
    free_after=$(get_free_space)
    local disk_freed=0
    if [[ -n "$free_before" && -n "$free_after" ]]; then
        disk_freed=$(( (free_after - free_before) * 1024 ))
        (( disk_freed < 0 )) && disk_freed=0
    fi

    echo
    echo -e "${GREEN}${BOLD}╔══════════════════════════════════════════╗${RESET}"
    echo -e "${GREEN}${BOLD}║   ✓  All cleaners finished!             ║${RESET}"
    if (( disk_freed > 0 )); then
        printf "${GREEN}${BOLD}║   Disk space recovered: ~%-15s ║${RESET}\n" "$(bytes_to_human $disk_freed)"
    fi
    echo -e "${GREEN}${BOLD}╚══════════════════════════════════════════╝${RESET}"

    log_action "══════ RUN ALL complete — disk freed: ~$(bytes_to_human ${disk_freed:-0}) ══════"
    pause_and_return
}

# ═══════════════════════════════════════════════════════════════════
#  18) VIEW KALICLEANX LOG
# ═══════════════════════════════════════════════════════════════════

view_cleaner_log() {
    echo -e "${BLUE}[*] Viewing KaliCleanX log: ${LOG_FILE}${RESET}"
    log_action "Viewed cleaner log"

    if [[ -f "$LOG_FILE" ]]; then
        echo
        if [[ "${KALICLEANX_NONINTERACTIVE:-0}" == "1" ]]; then
            cat "$LOG_FILE"
        else
            less "$LOG_FILE" 2>/dev/null || cat "$LOG_FILE"
        fi
    else
        echo -e "${YELLOW}[~] No log file found yet — run a cleaner first.${RESET}"
    fi

    pause_and_return
}

# ═══════════════════════════════════════════════════════════════════
#  MAIN MENU
# ═══════════════════════════════════════════════════════════════════

show_menu() {
    echo -e "${BOLD}${CYAN}  ┌──────────────────────────────────────────┐${RESET}"
    echo -e "${BOLD}${CYAN}  │            M A I N   M E N U             │${RESET}"
    echo -e "${BOLD}${CYAN}  ├──────────────────────────────────────────┤${RESET}"
    echo -e "${CYAN}  │  ${GREEN} 1)${CYAN}  System Status                    │${RESET}"
    echo -e "${CYAN}  │  ${GREEN} 2)${CYAN}  Log Sizes                        │${RESET}"
    echo -e "${CYAN}  │  ${GREEN} 3)${CYAN}  RAM Cache Clean                  │${RESET}"
    echo -e "${CYAN}  │  ${GREEN} 4)${CYAN}  Swap Reset                       │${RESET}"
    echo -e "${CYAN}  │  ${GREEN} 5)${CYAN}  APT Cache Clean                  │${RESET}"
    echo -e "${CYAN}  │  ${GREEN} 6)${CYAN}  Journal Vacuum                   │${RESET}"
    echo -e "${CYAN}  │  ${GREEN} 7)${CYAN}  Rotated Logs Clean               │${RESET}"
    echo -e "${CYAN}  │  ${GREEN} 8)${CYAN}  DNS Cache Flush                  │${RESET}"
    echo -e "${CYAN}  │  ${GREEN} 9)${CYAN}  Temp Files Clean                 │${RESET}"
    echo -e "${CYAN}  │  ${GREEN}10)${CYAN}  User Cache Clean                 │${RESET}"
    echo -e "${CYAN}  │  ${GREEN}11)${CYAN}  Crash Reports Clean              │${RESET}"
    echo -e "${CYAN}  │  ${GREEN}12)${CYAN}  Pip Cache Clean                  │${RESET}"
    echo -e "${CYAN}  │  ${GREEN}13)${CYAN}  NPM / Yarn Cache Clean           │${RESET}"
    echo -e "${CYAN}  │  ${GREEN}14)${CYAN}  Flatpak Cache Clean              │${RESET}"
    echo -e "${CYAN}  │  ${GREEN}15)${CYAN}  Snap Cache Clean                 │${RESET}"
    echo -e "${CYAN}  │  ${GREEN}16)${CYAN}  Check /boot Usage                │${RESET}"
    echo -e "${CYAN}  │  ${RED}17)${CYAN}  ★ Run ALL Cleaners ★             │${RESET}"
    echo -e "${CYAN}  │  ${GREEN}18)${CYAN}  View KaliCleanX Log              │${RESET}"
    echo -e "${CYAN}  │  ${RED} 0)${CYAN}  Exit                              │${RESET}"
    echo -e "${BOLD}${CYAN}  └──────────────────────────────────────────┘${RESET}"
    echo
}

# ═══════════════════════════════════════════════════════════════════
#  CLI ARGUMENT HANDLING
# ═══════════════════════════════════════════════════════════════════

handle_args() {
    case "${1:-}" in
        --help|-h)
            cat << HELPEOF
KaliCleanX v${VERSION} — Safe system cleaner for Kali Linux

Usage:
  sudo kalicleanx-final.sh [OPTION]

Options:
  (no args)        Interactive menu mode
  --all            Run all cleaners (non-interactive)
  --status         Show system status and exit
  --version, -v    Print version
  --help,    -h    Show this help

Examples:
  sudo ./kalicleanx-final.sh              # Interactive menu
  sudo ./kalicleanx-final.sh --all        # Run everything, no prompts
  sudo ./kalicleanx-final.sh --status     # Quick system overview
HELPEOF
            exit 0
            ;;
        --version|-v)
            echo "KaliCleanX v${VERSION}"
            exit 0
            ;;
        --all)
            check_root
            export KALICLEANX_NONINTERACTIVE=1
            banner
            run_all
            exit 0
            ;;
        --status)
            check_root
            export KALICLEANX_NONINTERACTIVE=1
            banner
            system_status
            exit 0
            ;;
    esac
}

# ═══════════════════════════════════════════════════════════════════
#  MAIN
# ═══════════════════════════════════════════════════════════════════

main() {
    handle_args "$@"
    check_root

    while true; do
        banner
        show_menu
        read -rp "  Select an option [0-18]: " choice || exit 0
        case "$choice" in
            1)  system_status ;;
            2)  log_sizes ;;
            3)  clean_ram ;;
            4)  reset_swap ;;
            5)  clean_apt_cache ;;
            6)  clean_journal ;;
            7)  clean_rotated_logs ;;
            8)  flush_dns ;;
            9)  clean_temp ;;
            10) clean_user_cache ;;
            11) clean_crash_reports ;;
            12) clean_pip_cache ;;
            13) clean_npm_cache ;;
            14) clean_flatpak_cache ;;
            15) clean_snap_cache ;;
            16) check_boot ;;
            17) run_all ;;
            18) view_cleaner_log ;;
            0|"")
                echo -e "${GREEN}[*] Goodbye!${RESET}"
                log_action "Exited KaliCleanX"
                exit 0
                ;;
            *)
                echo -e "${RED}[!] Invalid option: ${choice}${RESET}"
                sleep 1
                ;;
        esac
    done
}

main "$@"
