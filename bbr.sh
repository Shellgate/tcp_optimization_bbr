#!/bin/bash

# Colors
BLUE="\e[38;5;75m"
GREEN="\e[38;5;82m"
YELLOW="\e[38;5;228m"
RED="\e[38;5;196m"
GRAY="\e[38;5;245m"
RESET="\e[0m"
BOLD="\e[1m"

# Paths
BACKUP_PATH="/etc/sysctl.conf.bbr.bak"
SYSCTL_PATH="/etc/sysctl.conf"
TMP_FILE="/tmp/sysctl.new"

# Function: System Info
function show_system_info() {
    CPU_MODEL=$(lscpu | grep "Model name" | sed 's/Model name:\s*//')
    CORES=$(nproc)
    RAM_TOTAL=$(free -h | awk '/^Mem:/ {print $2}')
    RAM_USED=$(free -h | awk '/^Mem:/ {print $3}')
    DISK_TOTAL=$(df -h / | awk 'NR==2 {print $2}')
    DISK_USED=$(df -h / | awk 'NR==2 {print $3}')
    DISK_AVAIL=$(df -h / | awk 'NR==2 {print $4}')
    KERNEL=$(uname -r)
    UPTIME=$(uptime -p)
    INTERFACE=$(ip route get 1.1.1.1 | awk '{print $5; exit}')
    SPEED=$(ethtool "$INTERFACE" 2>/dev/null | grep -i speed | awk '{print $2}')
    LOCAL_IP=$(hostname -I | awk '{print $1}')
    PUBLIC_IP=$(curl -s https://api.ipify.org)
    BBR_STATUS=$(sysctl net.ipv4.tcp_congestion_control | awk '{print $3}')
    BBR_ACTIVE=$(lsmod | grep bbr)
    PING_TEST=$(ping -c 1 -W 1 8.8.8.8 >/dev/null 2>&1 && echo "Online" || echo "Offline")

    echo -e "${BLUE}${BOLD}╔═══════════════ System Summary ═══════════════╗${RESET}"
    printf "${YELLOW}%-15s${RESET} %s\n" "CPU:" "$CPU_MODEL"
    printf "${YELLOW}%-15s${RESET} %s cores\n" "Cores:" "$CORES"
    printf "${YELLOW}%-15s${RESET} %s / %s used\n" "RAM:" "$RAM_USED" "$RAM_TOTAL"
    printf "${YELLOW}%-15s${RESET} %s / %s used\n" "Disk:" "$DISK_USED" "$DISK_TOTAL"
    printf "${YELLOW}%-15s${RESET} %s available\n" "" "$DISK_AVAIL"
    printf "${YELLOW}%-15s${RESET} %s\n" "Kernel:" "$KERNEL"
    printf "${YELLOW}%-15s${RESET} %s\n" "Uptime:" "$UPTIME"
    echo -e "${GRAY}──────────────── Network ────────────────${RESET}"
    printf "${YELLOW}%-15s${RESET} %s\n" "Interface:" "$INTERFACE"
    printf "${YELLOW}%-15s${RESET} %s\n" "Speed:" "${SPEED:-Unknown}"
    printf "${YELLOW}%-15s${RESET} %s\n" "Local IP:" "$LOCAL_IP"
    printf "${YELLOW}%-15s${RESET} %s\n" "Public IP:" "$PUBLIC_IP"
    printf "${YELLOW}%-15s${RESET} %s\n" "Internet:" "$PING_TEST"
    echo -e "${GRAY}───────────────── BBR ───────────────────${RESET}"
    printf "${YELLOW}%-15s${RESET} %s\n" "Congestion:" "$BBR_STATUS"
    if [[ "$BBR_ACTIVE" == *bbr* ]]; then
        printf "${YELLOW}%-15s${GREEN}Active${RESET}\n" "BBR Module:"
    else
        printf "${YELLOW}%-15s${RED}Inactive${RESET}\n" "BBR Module:"
    fi
    echo -e "${BLUE}${BOLD}╚═════════════════════════════════════════╝${RESET}"
    echo
}

# Function: Download and Apply sysctl.conf
function install_bbr() {
    echo -e "${BLUE}→ Preparing to install System optimization...${RESET}"
    
    [[ -f "$BACKUP_PATH" ]] && rm -f "$BACKUP_PATH"
    cp "$SYSCTL_PATH" "$BACKUP_PATH"
    echo -e "${GREEN}✓ Backup saved to $BACKUP_PATH${RESET}"

    curl -s -o "$TMP_FILE" https://raw.githubusercontent.com/Shellgate/tcp_optimization_bbr/main/sysctl.conf
    if [[ $? -ne 0 ]]; then
        echo -e "${RED}✗ Failed to download configuration file.${RESET}"
        exit 1
    fi

    cp "$TMP_FILE" "$SYSCTL_PATH"
    echo -e "${GREEN}✓ Configuration applied.${RESET}"

    echo -e "${BLUE}→ Applied Changes:${RESET}"
    diff -u "$BACKUP_PATH" "$SYSCTL_PATH" || echo -e "${GRAY}(No differences shown)${RESET}"

    sysctl -p

    echo
    read -p "→ Reboot system now? [y/N]: " confirm
    [[ "$confirm" =~ ^[Yy]$ ]] && reboot
}

# Function: Restore backup
function restore_backup() {
    if [[ -f "$BACKUP_PATH" ]]; then
        cp "$BACKUP_PATH" "$SYSCTL_PATH"
        echo -e "${GREEN}✓ Backup restored.${RESET}"
        sysctl -p
        echo
        read -p "→ Reboot system now? [y/N]: " confirm
        [[ "$confirm" =~ ^[Yy]$ ]] && reboot
    else
        echo -e "${RED}✗ No backup file found.${RESET}"
    fi
}

# Show system info
clear
show_system_info

# Menu
echo -e "${BOLD}Choose an option:${RESET}"
echo -e "${YELLOW}1)${RESET} Install / Update System Optimization"
echo -e "${YELLOW}2)${RESET} Restore Previous Configuration"
echo -e "${YELLOW}3)${RESET} Exit"
echo
read -p "Enter choice [1-3]: " option

case "$option" in
    1) install_bbr ;;
    2) restore_backup ;;
    3) echo -e "${GRAY}Exiting...${RESET}" ;;
    *) echo -e "${RED}Invalid option.${RESET}" ;;
esac
