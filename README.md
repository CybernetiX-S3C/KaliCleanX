# KaliCleanX

**Safe, non-destructive system cleaner for Kali Linux**

KaliCleanX is a standalone cleaning utility designed specifically for Kali Linux. It removes caches, temp files, rotated logs, and other non-critical data — **without ever touching kernels, packages, or system-critical files**.

---

## Features

| # | Cleaner | What It Does |
|---|---------|-------------|
| 1 | System Status | CPU, RAM, swap, disk, network, top processes |
| 2 | Log Sizes | Lists the largest files in `/var/log` |
| 3 | RAM Cache Clean | Drops filesystem caches (`/proc/sys/vm/drop_caches`) |
| 4 | Swap Reset | Cycles swap off/on to release swap-cached memory |
| 5 | APT Cache Clean | `apt-get clean` + `autoclean` + partial archives |
| 6 | Journal Vacuum | Trims systemd journal to 2 days / 50 MB |
| 7 | Rotated Logs | Removes `*.gz`, `*.old`, `*.1`-`*.9` from `/var/log` |
| 8 | DNS Flush | Flushes `resolvectl`, `nscd`, and `dnsmasq` caches |
| 9 | Temp Files | Cleans `/tmp` and `/var/tmp` |
| 10 | User Cache | Clears `~/.cache`, `~/.thumbnails`, user trash, recent files |
| 11 | Crash Reports | Removes `/var/crash` contents and coredumps |
| 12 | Pip Cache | Purges pip / pip3 cache |
| 13 | NPM Cache | Cleans npm, yarn, and pnpm caches |
| 14 | Flatpak Cache | Removes unused Flatpak runtimes |
| 15 | Snap Cache | Removes disabled Snap revisions |
| 16 | Boot Check | Shows `/boot` usage and installed kernels (read-only) |
| 17 | **Run ALL** | Runs cleaners 3-15 sequentially with before/after disk report |
| 18 | View Log | Opens the KaliCleanX activity log |

**Bonus (automatic during Run ALL):**
- Docker system prune (if Docker is installed)
- Thumbnail cache cleanup

---

## Safety Guarantees

- No kernel deletion
- No package purging
- No system-critical file removal
- Every action is logged to `/var/log/kalicleanx.log`
- All operations are non-destructive and reversible (caches regenerate naturally)

---

## Requirements

| Requirement | Notes |
|------------|-------|
| **Kali Linux** | Designed for Kali; works on Debian/Ubuntu-based distros |
| **Bash 4+** | Pre-installed on all modern Linux |
| **Root access** | Required for system-level cleaning |
| **yad** *(optional)* | Required only for the GUI and tray icon |

---

## Installation

```bash
git clone https://github.com/CybernetiX-S3C/KaliCleanX.git
cd KaliCleanX
sudo ./install.sh
```

The installer will:
1. Copy all scripts to `/opt/kalicleanx/`
2. Create symlinks in `/usr/local/bin/`
3. Add a `.desktop` launcher to the application menu

### Manual Installation

```bash
chmod +x kalicleanx-final.sh kalicleanx-gui.sh kalicleanx-logviewer.sh kalicleanx-tray.sh
sudo cp *.sh /opt/kalicleanx/
sudo ln -sf /opt/kalicleanx/kalicleanx-final.sh /usr/local/bin/kalicleanx
```

---

## Usage

### CLI (Interactive Menu)

```bash
sudo kalicleanx
```

Launches the full interactive menu with all 18 options.

### CLI (Non-Interactive)

```bash
sudo kalicleanx --all       # Run all cleaners, no prompts
sudo kalicleanx --status    # Quick system overview
sudo kalicleanx --version   # Print version
sudo kalicleanx --help      # Show help
```

### Environment Variable

```bash
sudo KALICLEANX_NONINTERACTIVE=1 kalicleanx
```

Suppresses "press ENTER" pauses -- useful for scripting or piping.

### GUI

```bash
sudo kalicleanx-gui
```

Opens a `yad`-based graphical interface. Select any cleaner from the list; output is displayed in a scrollable dialog.

### System Tray

```bash
sudo kalicleanx-tray
```

Places a tray icon that provides quick access to the GUI, headless Run ALL, log viewer, and quit.

### Log Viewer

```bash
kalicleanx-log                    # Interactive pager
kalicleanx-log --tail 50          # Last 50 entries
kalicleanx-log --search "APT"     # Search the log
sudo kalicleanx-log --clear       # Truncate the log
```

---

## Uninstallation

```bash
sudo ./uninstall.sh
```

Removes all installed scripts, symlinks, and the desktop launcher. Optionally removes the activity log.

---

## Project Structure

```
kalicleanx/
|-- kalicleanx-final.sh      # Main CLI cleaner (18 menu options)
|-- kalicleanx-gui.sh         # yad-based GUI wrapper
|-- kalicleanx-logviewer.sh   # Log viewer with tail/search/clear
|-- kalicleanx-tray.sh        # System tray icon
|-- install.sh                 # Installer script
|-- uninstall.sh               # Uninstaller script
|-- kalicleanx.desktop         # Desktop menu entry
|-- README.md                  # This file
```

---

## License

This project is provided as-is for personal and educational use. Feel free to modify and distribute.

---

## Contributing

Contributions are welcome! Open an issue or submit a pull request.

---

**Built for Kali Linux. Clean smart. Stay safe.**
