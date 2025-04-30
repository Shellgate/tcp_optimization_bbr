#!/bin/bash
set -euo pipefail

# ----------- CONFIGURATION -----------
CONFIG_FILE="/etc/sysctl.conf"
BACKUP_DIR="/etc/sysctl_backups"
BACKUP_FILE="${BACKUP_DIR}/sysctl.conf.latest"
REMOTE_CONFIG_URL="https://raw.githubusercontent.com/Shellgate/tcp_optimization_bbr/main/sysctl.conf"

# ----------- COLORS -----------
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

# ----------- BBRManager CLASS -----------
class_BBRManager() {
    local self="$1"
    eval "${self}_require_root() {
        if [[ \$EUID -ne 0 ]]; then
            echo -e \"${RED}${BOLD}✖ This script must be run as root.${RESET}\"
            exit 1
        fi
    }"

    eval "${self}_ensure_backup_dir() {
        [[ -d \"\$BACKUP_DIR\" ]] || mkdir -p \"\$BACKUP_DIR\"
    }"

    eval "${self}_print_system_info() {
        echo -e \"${BLUE}${BOLD}-------- System Information --------${RESET}\"
        local os=\"N/A\" cpu=\"N/A\" ram=\"N/A\" disk=\"N/A\"
        [[ -f /etc/os-release ]] && os=\$(awk -F'\"' '/^PRETTY_NAME/{print \$2}' /etc/os-release)
        [[ -r /proc/cpuinfo ]] && cpu=\$(grep -m1 'model name' /proc/cpuinfo | cut -d: -f2- | xargs)
        command -v free >/dev/null && ram=\$(free -h | awk '/^Mem:/ {print \$2}')
        command -v lsblk >/dev/null && disk=\$(lsblk -bndo SIZE,TYPE | awk '\$2==\"disk\"{sum+=\$1} END{printf \"%.0fGB\",sum/1024/1024/1024}')
        printf \"${CYAN}%-15s${RESET}: %s\\n\" \"OS\" \"\$os\"
        printf \"${CYAN}%-15s${RESET}: %s\\n\" \"CPU\" \"\$cpu\"
        printf \"${CYAN}%-15s${RESET}: %s\\n\" \"RAM\" \"\$ram\"
        printf \"${CYAN}%-15s${RESET}: %s\\n\" \"Disk\" \"\$disk\"
        echo -e \"${BLUE}${BOLD}------------------------------------${RESET}\"
    }"

    eval "${self}_check_internet() {
        curl -s --head https://raw.githubusercontent.com/ >/dev/null || {
            echo -e \"${RED}✖ No internet connection!${RESET}\"
            exit 1
        }
    }"

    eval "${self}_download_config() {
        local tmpfile
        tmpfile=\$(mktemp /tmp/sysctl_new.XXXXXX)
        if ! curl -sfL \"${REMOTE_CONFIG_URL}?\$(date +%s)\" -o \"\$tmpfile\"; then
            echo -e \"${RED}✖ Downloading the new config failed!${RESET}\"
            exit 1
        fi
        if ! grep -q . \"\$tmpfile\"; then
            echo -e \"${RED}✖ Downloaded file is empty!${RESET}\"
            exit 1
        fi
        echo \"\$tmpfile\"
    }"

    eval "${self}_show_diff() {
        local newfile=\"\$1\"
        if command -v diff >/dev/null 2>&1; then
            local diffout
            diffout=\$(diff -u \"\$CONFIG_FILE\" \"\$newfile\" || true)
            if [[ -n \"\$diffout\" ]]; then
                echo -e \"${YELLOW}${BOLD}Configuration Changes:${RESET}\"
                while IFS= read -r line; do
                    case \"\$line\" in
                        ---*|+++*|@@*) echo -e \"${BLUE}\$line${RESET}\" ;;
                        -*) echo -e \"${RED}\$line${RESET}\" ;;
                        +*) echo -e \"${GREEN}\$line${RESET}\" ;;
                        *) echo \"\$line\" ;;
                    esac
                done <<< \"\$diffout\"
                return 0
            else
                echo -e \"${GREEN}✔ You already have the latest optimized configuration.${RESET}\"
                return 1
            fi
        else
            echo -e \"${YELLOW}⚠ diff is not installed. Can't show changes.${RESET}\"
            return 2
        fi
    }"

    eval "${self}_backup_config() {
        cp \"\$CONFIG_FILE\" \"\$BACKUP_FILE\"
        echo -e \"${DIM}Backup saved: \$BACKUP_FILE${RESET}\"
    }"

    eval "${self}_apply_config() {
        local newfile=\"\$1\"
        ${self}_backup_config
        cp \"\$newfile\" \"\$CONFIG_FILE\"
        if sysctl -p &>/dev/null; then
            echo -e \"${GREEN}✔ New settings applied and sysctl loaded without error.${RESET}\"
        else
            echo -e \"${RED}✖ Warning: sysctl -p encountered errors!${RESET}\"
            sysctl -p
        fi
    }"

    eval "${self}_restore_backup() {
        if [[ -f \"\$BACKUP_FILE\" ]]; then
            cp \"\$BACKUP_FILE\" \"\$CONFIG_FILE\"
            if sysctl -p &>/dev/null; then
                echo -e \"${GREEN}✔ Backup restored and settings applied.${RESET}\"
            else
                echo -e \"${RED}✖ Warning: sysctl -p encountered errors after restore!${RESET}\"
                sysctl -p
            fi
        else
            echo -e \"${RED}✖ No backup found to restore!${RESET}\"
        fi
    }"

    eval "${self}_ask_reboot() {
        echo
        echo -ne \"${MAGENTA}${BOLD}↻ Do you want to reboot now? (y/n): ${RESET}\"
        read -r answer
        if [[ \"\$answer\" =~ ^[Yy]$ ]]; then
            reboot
        fi
    }"

    eval "${self}_pause() {
        echo -e \"${DIM}Press ENTER to continue...${RESET}\"
        read -r
    }"

    eval "${self}_show_menu() {
        clear
        echo -e \"${BG}${WHITE}${BOLD}        TCP/BBR Optimization Manager        ${RESET}\\n\"
        ${self}_print_system_info
        echo -e \"${CYAN}1) ${WHITE}Update & Optimize (Recommended)\"
        echo -e \"${CYAN}2) ${WHITE}Restore Previous Backup\"
        echo -e \"${CYAN}3) ${WHITE}Exit${RESET}\"
    }"
}

# ----------- MAIN APP -----------

BBR="BBRManager"
class_BBRManager "$BBR"

${BBR}_require_root
${BBR}_ensure_backup_dir

while true; do
    ${BBR}_show_menu
    echo
    echo -ne "${BOLD}Select an option [1-3]: ${RESET}"
    read -r opt
    case "$opt" in
        1)
            ${BBR}_check_internet
            newfile=$(${BBR}_download_config)
            if ${BBR}_show_diff "$newfile"; then
                echo -ne "${BOLD}Apply these changes? (y/n): ${RESET}"
                read -r ans
                if [[ "$ans" =~ ^[Yy]$ ]]; then
                    ${BBR}_apply_config "$newfile"
                    ${BBR}_ask_reboot
                else
                    echo -e "${YELLOW}✱ Update cancelled.${RESET}"
                fi
            fi
            ${BBR}_pause
            ;;
        2)
            ${BBR}_restore_backup
            ${BBR}_ask_reboot
            ${BBR}_pause
            ;;
        3)
            echo -e "${BLUE}${BOLD}Goodbye!${RESET}"
            exit 0
            ;;
        *)
            echo -e "${RED}✖ Invalid option!${RESET}"
            ${BBR}_pause
            ;;
    esac
done
