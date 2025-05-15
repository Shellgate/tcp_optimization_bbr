#!/bin/bash

# Colors
GREEN="\e[32m"
RED="\e[31m"
YELLOW="\e[33m"
BLUE="\e[34m"
RESET="\e[0m"

# Paths
SYSCTL_FILE="/etc/sysctl.conf"
BACKUP_FILE="/etc/sysctl.conf.bak"

# Show basic system info
function show_system_info() {
    echo -e "${BLUE}System Info${RESET}"
    echo -e "${YELLOW}CPU:${RESET} $(lscpu | grep 'Model name' | sed 's/Model name:\s*//')"
    echo -e "${YELLOW}Cores:${RESET} $(nproc)"
    echo -e "${YELLOW}RAM:${RESET} $(free -h | awk '/^Mem:/ {print $2}')"
    echo -e "${YELLOW}Used:${RESET} $(free -h | awk '/^Mem:/ {print $3}')"
    echo -e "${YELLOW}Disk:${RESET}"
    df -h / | awk 'NR==1 || NR==2' | sed 's/^/  /'
    echo
}

# Intro text
function show_intro() {
    echo -e "${GREEN}BBR Optimization Script${RESET}"
    echo -e "Backup, apply or restore sysctl network tuning configs."
    echo
}

# Option 1: Update sysctl.conf
function update_and_install() {
    echo -e "${BLUE}Creating backup...${RESET}"
    [ -f "$BACKUP_FILE" ] && rm -f "$BACKUP_FILE"
    cp "$SYSCTL_FILE" "$BACKUP_FILE"

    echo -e "${BLUE}Fetching new config...${RESET}"
    curl -fsSL https://raw.githubusercontent.com/Shellgate/tcp_optimization_bbr/main/sysctl.conf -o "$SYSCTL_FILE"

    echo -e "${BLUE}Applying settings...${RESET}"
    sysctl -p

    echo -e "${BLUE}Changes:${RESET}"
    diff --color=always "$BACKUP_FILE" "$SYSCTL_FILE" || echo -e "${YELLOW}(No differences found)${RESET}"
    echo

    read -rp "Reboot now? (y/n): " reboot_choice
    [[ "$reboot_choice" =~ ^[Yy]$ ]] && reboot
}

# Option 2: Restore backup
function restore_backup() {
    if [ ! -f "$BACKUP_FILE" ]; then
        echo -e "${RED}No backup found.${RESET}"
        return
    fi

    echo -e "${BLUE}Restoring backup...${RESET}"
    cp "$BACKUP_FILE" "$SYSCTL_FILE"
    sysctl -p

    read -rp "Reboot now? (y/n): " reboot_choice
    [[ "$reboot_choice" =~ ^[Yy]$ ]] && reboot
}

# Menu
function show_menu() {
    echo -e "${BLUE}Menu:${RESET}"
    echo "1) Apply optimized config"
    echo "2) Restore previous config"
    echo "3) Exit"
    read -rp "Select: " choice
    case $choice in
        1) update_and_install ;;
        2) restore_backup ;;
        3) echo -e "${YELLOW}Exiting...${RESET}" ;;
        *) echo -e "${RED}Invalid option.${RESET}" ;;
    esac
}

# Main
clear
show_system_info
show_intro
show_menu
