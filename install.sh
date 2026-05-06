#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════════
# KaliCleanX Installer
# Copies scripts to /opt/kalicleanx, symlinks to /usr/local/bin,
# and optionally creates a .desktop launcher for the GUI.
# ═══════════════════════════════════════════════════════════════════

set -e

GREEN="\e[32m"; YELLOW="\e[33m"; RED="\e[31m"; BLUE="\e[34m"; BOLD="\e[1m"; RESET="\e[0m"
INSTALL_DIR="/opt/kalicleanx"
BIN_DIR="/usr/local/bin"
DESKTOP_DIR="/usr/share/applications"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo -e "${BOLD}${GREEN}KaliCleanX Installer${RESET}"
echo

# ── Root check ──────────────────────────────────────────
if [[ $EUID -ne 0 ]]; then
    echo -e "${RED}[!] Please run the installer as root: sudo ./install.sh${RESET}"
    exit 1
fi

# ── Check source files ──────────────────────────────────
REQUIRED_FILES=(
    "kalicleanx-final.sh"
    "kalicleanx-gui.sh"
    "kalicleanx-logviewer.sh"
    "kalicleanx-tray.sh"
    "uninstall.sh"
)

for f in "${REQUIRED_FILES[@]}"; do
    if [[ ! -f "${SCRIPT_DIR}/${f}" ]]; then
        echo -e "${RED}[!] Missing file: ${f}${RESET}"
        echo "    Make sure all KaliCleanX files are in the same directory as install.sh"
        exit 1
    fi
done

echo -e "${BLUE}[1/4] Creating install directory: ${INSTALL_DIR}${RESET}"
mkdir -p "$INSTALL_DIR"

echo -e "${BLUE}[2/4] Copying scripts...${RESET}"
for f in "${REQUIRED_FILES[@]}"; do
    cp "${SCRIPT_DIR}/${f}" "${INSTALL_DIR}/${f}"
    chmod +x "${INSTALL_DIR}/${f}"
    echo "  → ${INSTALL_DIR}/${f}"
done

# Copy supporting files if present
[[ -f "${SCRIPT_DIR}/README.md" ]]          && cp "${SCRIPT_DIR}/README.md"          "${INSTALL_DIR}/"
[[ -f "${SCRIPT_DIR}/kalicleanx.desktop" ]] && cp "${SCRIPT_DIR}/kalicleanx.desktop" "${INSTALL_DIR}/"

echo -e "${BLUE}[3/4] Creating symlinks in ${BIN_DIR}...${RESET}"

# Main CLI tool
ln -sf "${INSTALL_DIR}/kalicleanx-final.sh" "${BIN_DIR}/kalicleanx"
echo "  → kalicleanx  (main cleaner)"

# GUI
ln -sf "${INSTALL_DIR}/kalicleanx-gui.sh" "${BIN_DIR}/kalicleanx-gui"
echo "  → kalicleanx-gui"

# Log viewer
ln -sf "${INSTALL_DIR}/kalicleanx-logviewer.sh" "${BIN_DIR}/kalicleanx-log"
echo "  → kalicleanx-log"

# Tray
ln -sf "${INSTALL_DIR}/kalicleanx-tray.sh" "${BIN_DIR}/kalicleanx-tray"
echo "  → kalicleanx-tray"

echo -e "${BLUE}[4/4] Creating desktop launcher...${RESET}"
mkdir -p "$DESKTOP_DIR"
cat > "${DESKTOP_DIR}/kalicleanx.desktop" << 'DESKTOP'
[Desktop Entry]
Name=KaliCleanX
Comment=Safe system cleaner for Kali Linux
Exec=pkexec /opt/kalicleanx/kalicleanx-gui.sh
Icon=utilities-system-monitor
Terminal=false
Type=Application
Categories=System;Utility;
Keywords=clean;cache;temp;system;
DESKTOP

echo "  → ${DESKTOP_DIR}/kalicleanx.desktop"

echo
echo -e "${GREEN}${BOLD}╔══════════════════════════════════════════════════╗${RESET}"
echo -e "${GREEN}${BOLD}║   ✓  KaliCleanX installed successfully!         ║${RESET}"
echo -e "${GREEN}${BOLD}╠══════════════════════════════════════════════════╣${RESET}"
echo -e "${GREEN}${BOLD}║                                                 ║${RESET}"
echo -e "${GREEN}${BOLD}║   CLI:   sudo kalicleanx                       ║${RESET}"
echo -e "${GREEN}${BOLD}║   GUI:   sudo kalicleanx-gui                   ║${RESET}"
echo -e "${GREEN}${BOLD}║   Tray:  sudo kalicleanx-tray                  ║${RESET}"
echo -e "${GREEN}${BOLD}║   Log:   kalicleanx-log                        ║${RESET}"
echo -e "${GREEN}${BOLD}║   All:   sudo kalicleanx --all                 ║${RESET}"
echo -e "${GREEN}${BOLD}║   Help:  kalicleanx --help                     ║${RESET}"
echo -e "${GREEN}${BOLD}║                                                 ║${RESET}"
echo -e "${GREEN}${BOLD}╚══════════════════════════════════════════════════╝${RESET}"
