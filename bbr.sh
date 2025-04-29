#!/bin/bash
set -euo pipefail

project="TCP Optimization BBR"
config_file="/etc/sysctl.conf"
backup_dir="/etc/sysctl_backups"
backup_file="$backup_dir/sysctl.conf.$(date +%Y%m%d_%H%M%S)"
latest_backup="$backup_dir/sysctl.conf.latest"
new_file_url="https://raw.githubusercontent.com/Shellgate/tcp_optimization_bbr/main/sysctl.conf"
temp_download="$(mktemp /tmp/sysctl_new.XXXXXX)"
lock_file="/tmp/.bbr_update.lock"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[1;34m'
NC='\033[0m'

cleanup() {
    rm -f "$temp_download" "$lock_file"
}
trap cleanup EXIT

# Check root
require_root() {
    if [[ $EUID -ne 0 ]]; then
        echo -e "${RED}This script must be run as root. Exiting.${NC}" >&2
        exit 1
    fi
}

# Make backup dir if not exists
ensure_backup_dir() {
    [[ -d "$backup_dir" ]] || mkdir -p "$backup_dir"
}

# Prevent concurrent runs
lock_script() {
    if [[ -f "$lock_file" ]]; then
        echo -e "${YELLOW}Another update is in progress. Try again later.${NC}"
        exit 1
    fi
    touch "$lock_file"
}

# Show system info (robust & compatible)
display_info() {
    echo -e "\n${BLUE}=== $project ===${NC}"
    echo -e "${YELLOW}System Information:${NC}"
    echo -e "+------------------------+"
    # OS
    if command -v lsb_release >/dev/null 2>&1; then
        os_name=$(lsb_release -d 2>/dev/null | cut -f2)
    elif [[ -f /etc/os-release ]]; then
        os_name=$(awk -F= '/^PRETTY_NAME/{print $2}' /etc/os-release | tr -d '"')
    else
        os_name="N/A"
    fi
    echo -e "|  OS: ${os_name:-N/A}  |"
    # CPU
    if grep -q 'model name' /proc/cpuinfo 2>/dev/null; then
        cpu_name=$(grep 'model name' /proc/cpuinfo | head -n1 | cut -d' ' -f3-)
    else
        cpu_name="N/A"
    fi
    echo -e "|  CPU: ${cpu_name:-N/A}  |"
    # RAM
    if command -v free >/dev/null 2>&1; then
        ram_mb=$(free -m | awk '/^Mem:/ {print $2 " MB"}')
    else
        ram_mb="N/A"
    fi
    echo -e "|  RAM: ${ram_mb:-N/A}  |"
    echo -e "+------------------------+"
}

# Check internet
check_internet() {
    if ! curl -s --head https://raw.githubusercontent.com/ >/dev/null; then
        echo -e "${RED}Error: No internet connection!${NC}"
        exit 1
    fi
}

# Download latest config (no cache)
download_file() {
    if ! curl -sfL "$new_file_url" -o "$temp_download" -H "Cache-Control: no-cache"; then
        echo -e "${RED}Error: Failed to download the new file!${NC}"
        exit 1
    fi
    if ! grep -q . "$temp_download"; then
        echo -e "${RED}Error: Downloaded file is empty!${NC}"
        exit 1
    fi
}

# Backup current config with timestamp and update 'latest'
backup_current() {
    cp "$config_file" "$backup_file"
    cp "$config_file" "$latest_backup"
    echo -e "${GREEN}Backup created: $backup_file${NC}"
}

# List available backups
list_backups() {
    echo -e "${YELLOW}Available backups:${NC}"
    ls -1 "$backup_dir"/sysctl.conf.* 2>/dev/null | xargs -n 1 basename || echo "No backups found."
}

# Show diff (with fallback)
show_diff() {
    if command -v diff &>/dev/null; then
        echo -e "${YELLOW}Diff between current and new version:${NC}"
        diff -u "$config_file" "$temp_download" || echo -e "${BLUE}No changes found.${NC}"
    else
        echo -e "${YELLOW}diff command not found, can't show difference.${NC}"
    fi
}

# Apply the new config file
apply_update() {
    cp "$temp_download" "$config_file"
    echo -e "${GREEN}File replaced successfully.${NC}"
    if sysctl -p; then
        echo -e "${GREEN}New settings applied.${NC}"
    else
        echo -e "${RED}Warning: sysctl -p failed! Please check your config.${NC}"
    fi
}

# Restore from a selected backup
restore_backup() {
    list_backups
    read -p "Enter the backup filename to restore: " restore_file
    if [[ -f "$backup_dir/$restore_file" ]]; then
        cp "$backup_dir/$restore_file" "$config_file"
        sysctl -p && echo -e "${GREEN}Restored successfully from $restore_file.${NC}"
    else
        echo -e "${RED}Backup file not found!${NC}"
    fi
}

# Ask for system restart
prompt_restart() {
    read -p "Restart the system? (y/n): " restart_choice
    case $restart_choice in
        [Yy]*) reboot ;;
        *) echo "No restart." ;;
    esac
}

# -- MAIN --
require_root
lock_script
ensure_backup_dir
display_info

options=("Update & Optimize" "Show Config Diff" "Restore Backup" "List Backups" "Exit")
PS3="Select an option: "

select opt in "${options[@]}"; do
    case $REPLY in
        1)
            check_internet
            download_file
            backup_current
            show_diff
            read -p "Apply changes? (y/n): " apply_choice
            if [[ "$apply_choice" =~ ^[Yy]$ ]]; then
                apply_update
                prompt_restart
            else
                echo -e "${YELLOW}No changes applied.${NC}"
            fi
            exit 0
            ;;
        2)
            check_internet
            download_file
            show_diff
            exit 0
            ;;
        3)
            restore_backup
            prompt_restart
            exit 0
            ;;
        4)
            list_backups
            ;;
        5)
            echo -e "${RED}Exited.${NC}"
            exit 0
            ;;
        *)
            echo -e "${RED}Invalid option!${NC}" ;;
    esac
done
