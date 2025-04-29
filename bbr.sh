#!/bin/bash
set -euo pipefail

# ==========================================
#         TCP Optimization Manager
# ==========================================
# 1) Update & Optimize: Download & apply the latest optimized sysctl.conf
#    - Shows server info and config differences before applying.
#    - Always fetches the latest version directly from GitHub.
#    - Creates a backup before any change.
# 2) Restore Backup: Restore previous sysctl.conf from backup.
# 3) Exit
# - After update or restore, you can choose to reboot for full effect.
# ==========================================

# --------- CONFIGURATION ---------
CONFIG_FILE="/etc/sysctl.conf"
BACKUP_DIR="/etc/sysctl_backups"
BACKUP_FILE="${BACKUP_DIR}/sysctl.conf.latest"
NEW_FILE_URL="https://raw.githubusercontent.com/Shellgate/tcp_optimization_bbr/main/sysctl.conf"
TEMP_DOWNLOAD="$(mktemp /tmp/sysctl_new.XXXXXX)"

# --------- MODERN COLORS ---------
RESET='\033[0m'
BOLD='\033[1m'
DIM='\033[2m'
RED='\033[1;31m'
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
BLUE='\033[1;34m'
CYAN='\033[1;36m'
MAGENTA='\033[1;35m'
WHITE='\033[1;37m'
BG="\033[48;5;238m"

# --------- CLEANUP ---------
cleanup() {
    rm -f "$TEMP_DOWNLOAD"
}
trap cleanup EXIT

# --------- FUNCTIONS ---------

require_root() {
    [[ $EUID -eq 0 ]] || { echo -e "${RED}${BOLD}✖ This script must be run as root.${RESET}"; exit 1; }
}

ensure_backup_dir() {
    [[ -d "$BACKUP_DIR" ]] || mkdir -p "$BACKUP_DIR"
}

show_system_info() {
    # OS
    if command -v lsb_release >/dev/null 2>&1; then
        os_name=$(lsb_release -d 2>/dev/null | cut -f2)
    elif [[ -f /etc/os-release ]]; then
        os_name=$(awk -F= '/^PRETTY_NAME/{print $2}' /etc/os-release | tr -d '"')
    else
        os_name="N/A"
    fi
    # CPU
    if grep -q 'model name' /proc/cpuinfo 2>/dev/null; then
        cpu_name=$(grep 'model name' /proc/cpuinfo | head -n1 | cut -d' ' -f3-)
    else
        cpu_name="N/A"
    fi
    # RAM
    if command -v free >/dev/null 2>&1; then
        ram_mb=$(free -m | awk '/^Mem:/ {printf "%.0f GB", $2/1024}')
    else
        ram_mb="N/A"
    fi
    # Disk Size (Total GB)
    if command -v lsblk >/dev/null 2>&1; then
        disk_gb=$(lsblk -bdo SIZE,TYPE | awk '$2=="disk"{sum+=$1} END{printf "%.0f GB", sum/1024/1024/1024}')
    else
        disk_gb="N/A"
    fi

    echo -e "${BLUE}${BOLD}-------------------------------------------${RESET}"
    printf "${CYAN}%-12s${RESET}: %s\n"  "OS"    "$os_name"
    printf "${CYAN}%-12s${RESET}: %s\n"  "CPU"   "$cpu_name"
    printf "${CYAN}%-12s${RESET}: %s\n"  "RAM"   "$ram_mb"
    printf "${CYAN}%-12s${RESET}: %s\n"  "Disk"  "$disk_gb"
    echo -e "${BLUE}${BOLD}-------------------------------------------${RESET}\n"
}

check_internet() {
    curl -s --head https://raw.githubusercontent.com/ >/dev/null || {
        echo -e "${RED}✖ No internet connection!${RESET}"
        exit 1
    }
}

download_file() {
    # Always get the latest directly from GitHub
    if ! curl -sfL "$NEW_FILE_URL" -o "$TEMP_DOWNLOAD" -H "Cache-Control: no-cache"; then
        echo -e "${RED}✖ Failed to download the new config!${RESET}"
        exit 1
    fi
    if ! grep -q . "$TEMP_DOWNLOAD"; then
        echo -e "${RED}✖ Downloaded file is empty!${RESET}"
        exit 1
    fi
}

show_diff() {
    if command -v diff >/dev/null 2>&1; then
        diff_output=$(diff -u "$CONFIG_FILE" "$TEMP_DOWNLOAD" || true)
        if [[ -n "$diff_output" ]]; then
            echo -e "${YELLOW}${BOLD}Configuration Changes:${RESET}"
            echo -e "${CYAN}$diff_output${RESET}"
            return 0
        else
            echo -e "${GREEN}✔ You already have the latest optimized configuration.${RESET}"
            return 1
        fi
    else
        echo -e "${YELLOW}⚠ diff not found. Cannot show changes.${RESET}"
        return 2
    fi
}

apply_update() {
    cp "$CONFIG_FILE" "$BACKUP_FILE"
    cp "$TEMP_DOWNLOAD" "$CONFIG_FILE"
    echo -e "${GREEN}✔ Updated! Backup saved at: ${BOLD}$BACKUP_FILE${RESET}"
    if sysctl -p; then
        echo -e "${GREEN}✔ sysctl settings applied.${RESET}"
    else
        echo -e "${RED}✖ Warning: sysctl -p failed. Please check your config.${RESET}"
    fi
}

restore_backup() {
    if [[ -f "$BACKUP_FILE" ]]; then
        cp "$BACKUP_FILE" "$CONFIG_FILE"
        echo -e "${GREEN}✔ Restored from backup: ${BOLD}$BACKUP_FILE${RESET}"
        if sysctl -p; then
            echo -e "${GREEN}✔ sysctl settings applied after restore.${RESET}"
        else
            echo -e "${RED}✖ Warning: sysctl -p failed after restore!${RESET}"
        fi
    else
        echo -e "${RED}✖ No backup found to restore!${RESET}"
    fi
}

prompt_reboot() {
    echo -ne "${MAGENTA}${BOLD}↻ Reboot now for all changes to take effect? (y/n): ${RESET}"
    read -r reboot_choice
    [[ "$reboot_choice" =~ ^[Yy]$ ]] && reboot
}

show_menu() {
    clear
    echo -e "${BG}${WHITE}${BOLD}         TCP Optimization Manager         ${RESET}\n"
    show_system_info
    echo -e "${CYAN}1) ${WHITE}Update & Optimize (Recommended)"
    echo -e "${CYAN}2) ${WHITE}Restore Backup"
    echo -e "${CYAN}3) ${WHITE}Exit${RESET}"
}

# -------------- MAIN --------------
require_root
ensure_backup_dir

while true; do
    show_menu
    echo
    echo -ne "${BOLD}Select an option [1-3]: ${RESET}"
    read -r choice
    case "$choice" in
        1)
            check_internet
            download_file
            if show_diff; then
                echo -ne "${BOLD}Apply these changes? (y/n): ${RESET}"
                read -r apply_choice
                if [[ "$apply_choice" =~ ^[Yy]$ ]]; then
                    apply_update
                    prompt_reboot
                else
                    echo -e "${YELLOW}✱ Update cancelled.${RESET}"
                fi
            fi
            echo -e "${DIM}Press ENTER to return to the menu...${RESET}"; read -r
            ;;
        2)
            restore_backup
            prompt_reboot
            echo -e "${DIM}Press ENTER to return to the menu...${RESET}"; read -r
            ;;
        3)
            echo -e "${BLUE}${BOLD}Goodbye!${RESET}"
            break
            ;;
        *)
            echo -e "${RED}✖ Invalid option!${RESET}"
            ;;
    esac
done
