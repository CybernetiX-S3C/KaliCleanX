#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════════
# KaliCleanX Uninstaller
# Removes installed scripts, symlinks, desktop launcher, and
# optionally the activity log.
# ═══════════════════════════════════════════════════════════════════

set -e

GREEN="\e[32m"; YELLOW="\e[33m"; RED="\e[31m"; BLUE="\e[34m"; BOLD="\e[1m"; RESET="\e[0m"
INSTALL_DIR="/opt/kalicleanx"
BIN_DIR="/usr/local/bin"
DESKTOP_FILE="/usr/share/applications/kalicleanx.desktop"
LOG_FILE="/var/log/kalicleanx.log"

echo -e "${BOLD}${RED}KaliCleanX Uninstaller${RESET}"
echo

# ── Root check ──────────────────────────────────────────
if [[ $EUID -ne 0 ]]; then
    echo -e "${RED}[!] Please run the uninstaller as root: sudo ./uninstall.sh${RESET}"
    exit 1
fi

# ── Confirm ─────────────────────────────────────────────
echo -e "${YELLOW}This will remove KaliCleanX from your system:${RESET}"
echo "  • Scripts in ${INSTALL_DIR}"
echo "  • Symlinks in ${BIN_DIR}"
echo "  • Desktop launcher"
echo
read -rp "Continue? [y/N]: " confirm
if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
    echo -e "${YELLOW}[~] Uninstall cancelled.${RESET}"
    exit 0
fi

echo

# ── Remove symlinks ─────────────────────────────────────
echo -e "${BLUE}[1/3] Removing symlinks...${RESET}"

SYMLINKS=(
    "${BIN_DIR}/kalicleanx"
    "${BIN_DIR}/kalicleanx-gui"
    "${BIN_DIR}/kalicleanx-log"
    "${BIN_DIR}/kalicleanx-tray"
)

for link in "${SYMLINKS[@]}"; do
    if [[ -L "$link" || -f "$link" ]]; then
        rm -f "$link"
        echo "  ✓ Removed $link"
    fi
done

# ── Remove desktop launcher ────────────────────────────
echo -e "${BLUE}[2/3] Removing desktop launcher...${RESET}"
if [[ -f "$DESKTOP_FILE" ]]; then
    rm -f "$DESKTOP_FILE"
    echo "  ✓ Removed $DESKTOP_FILE"
    # Refresh desktop database if available
    update-desktop-database "$( dirname "$DESKTOP_FILE" )" 2>/dev/null || true
else
    echo "  ~ Not found (skipped)"
fi

# ── Remove install directory ───────────────────────────
echo -e "${BLUE}[3/3] Removing install directory...${RESET}"
if [[ -d "$INSTALL_DIR" ]]; then
    rm -rf "$INSTALL_DIR"
    echo "  ✓ Removed $INSTALL_DIR"
else
    echo "  ~ Not found (skipped)"
fi

# ── Optionally remove log ──────────────────────────────
echo
if [[ -f "$LOG_FILE" ]]; then
    read -rp "Also remove the activity log (${LOG_FILE})? [y/N]: " rm_log
    if [[ "$rm_log" =~ ^[Yy]$ ]]; then
        rm -f "$LOG_FILE"
        echo -e "  ${GREEN}✓ Log file removed${RESET}"
    else
        echo -e "  ${YELLOW}~ Log file kept${RESET}"
    fi
fi

echo
echo -e "${GREEN}${BOLD}╔══════════════════════════════════════════════════╗${RESET}"
echo -e "${GREEN}${BOLD}║   ✓  KaliCleanX uninstalled successfully.       ║${RESET}"
echo -e "${GREEN}${BOLD}╚══════════════════════════════════════════════════╝${RESET}"
