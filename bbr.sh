#!/bin/bash

# Colors
RED="\e[38;5;131m"
GREEN="\e[38;5;108m"
BLUE="\e[38;5;75m"
CYAN="\e[38;5;51m"
AQUA="\e[38;5;45m"
LIME="\e[38;5;154m"
GRAY="\e[38;5;250m"
WHITE="\e[97m"
MAGENTA="\e[38;5;213m"
YELLOW="\e[38;5;228m"
BOLD="\e[1m"
RESET="\e[0m"

# Paths - sysctl
BACKUP_PATH="/etc/sysctl.conf.bbr.bak"
SYSCTL_PATH="/etc/sysctl.conf"
TMP_FILE="/tmp/sysctl.new"
SYSCTL_URL="https://raw.githubusercontent.com/Shellgate/tcp_optimization_bbr/main/sysctl.conf"

# Paths - limits
LIMITS_PATH="/etc/security/limits.conf"
LIMITS_BACKUP="/etc/security/limits.conf.bbr.bak"
LIMITS_TMP="/tmp/limits.new"
LIMITS_URL="https://raw.githubusercontent.com/Shellgate/tcp_optimization_bbr/main/etc/security/limits.conf"

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

    echo -e "${AQUA}${BOLD}╔═══════════════ SYSTEM SUMMARY ═══════════════╗${RESET}"
    printf "${CYAN}%-15s${WHITE}%s\n" "CPU:" "$CPU_MODEL"
    printf "${CYAN}%-15s${LIME}%s${WHITE} cores\n" "Cores:" "$CORES"
    printf "${CYAN}%-15s${LIME}%s${WHITE} / ${LIME}%s${WHITE} used\n" "RAM:" "$RAM_USED" "$RAM_TOTAL"
    printf "${CYAN}%-15s${LIME}%s${WHITE} / ${LIME}%s${WHITE} used\n" "Disk:" "$DISK_USED" "$DISK_TOTAL"
    printf "${CYAN}%-15s${GRAY}%s available\n" "" "$DISK_AVAIL"
    printf "${MAGENTA}%-15s${WHITE}%s\n" "Kernel:" "$KERNEL"
    printf "${MAGENTA}%-15s${WHITE}%s\n" "Uptime:" "$UPTIME"
    echo -e "${GRAY}──────────────────── NETWORK ───────────────────${RESET}"
    printf "${CYAN}%-15s${WHITE}%s\n" "Interface:" "$INTERFACE"
    printf "${CYAN}%-15s${WHITE}%s\n" "Speed:" "${SPEED:-Unknown}"
    printf "${CYAN}%-15s${WHITE}%s\n" "Local IP:" "$LOCAL_IP"
    printf "${CYAN}%-15s${WHITE}%s\n" "Public IP:" "$PUBLIC_IP"
    printf "${CYAN}%-15s${WHITE}%s\n" "Internet:" "$PING_TEST"
    echo -e "${GRAY}───────────────────── BBR ─────────────────────${RESET}"
    printf "${CYAN}%-15s${WHITE}%s\n" "Congestion:" "$BBR_STATUS"
    if [[ "$BBR_ACTIVE" == *bbr* ]]; then
        printf "${CYAN}%-15s${LIME}Active${RESET}\n" "BBR Module:"
    else
        printf "${CYAN}%-15s${MAGENTA}Inactive${RESET}\n" "BBR Module:"
    fi
    echo -e "${AQUA}${BOLD}╚══════════════════════════════════════════════╝${RESET}"
    echo
}

# Function: Download and Apply sysctl.conf
function install_bbr() {
    echo -e "${BLUE}→ Preparing to install system optimization...${RESET}"
    [[ -f "$BACKUP_PATH" ]] && rm -f "$BACKUP_PATH"
    cp "$SYSCTL_PATH" "$BACKUP_PATH"
    echo -e "${GREEN}✓ Backup saved to $BACKUP_PATH${RESET}"

    curl -s -o "$TMP_FILE" "$SYSCTL_URL"
    if [[ $? -ne 0 ]]; then
        echo -e "${RED}✗ Failed to download configuration file.${RESET}"
        exit 1
    fi
    cp "$TMP_FILE" "$SYSCTL_PATH"
    echo -e "${GREEN}✓ Configuration applied.${RESET}"

    echo -e "${BLUE}→ Applied Changes:${RESET}"
    DIFF_OUTPUT=$(diff -u "$BACKUP_PATH" "$SYSCTL_PATH")
    if [[ -z "$DIFF_OUTPUT" ]]; then
        echo -e "${GRAY}(No differences shown)${RESET}"
    else
        while IFS= read -r line; do
            if [[ "$line" =~ ^\+ && ! "$line" =~ ^\+\+ ]]; then
                echo -e "${GREEN}$line${RESET}"
            elif [[ "$line" =~ ^\- && ! "$line" =~ ^\-\- ]]; then
                echo -e "${RED}$line${RESET}"
            else
                echo -e "${WHITE:-\e[97m}$line${RESET}"
            fi
        done <<< "$DIFF_OUTPUT"
    fi
    sysctl -p > /dev/null 2>&1
    echo
    read -p "→ Reboot system now? [y/N]: " confirm
    [[ "$confirm" =~ ^[Yy]$ ]] && reboot
}

# Function: Download and Apply limits.conf
function install_limits() {
    echo -e "${BLUE}→ Preparing to install limits.conf optimization...${RESET}"
    [[ -f "$LIMITS_BACKUP" ]] && rm -f "$LIMITS_BACKUP"
    cp "$LIMITS_PATH" "$LIMITS_BACKUP"
    echo -e "${GREEN}✓ Backup saved to $LIMITS_BACKUP${RESET}"

    curl -s -o "$LIMITS_TMP" "$LIMITS_URL"
    if [[ $? -ne 0 ]]; then
        echo -e "${RED}✗ Failed to download limits.conf file.${RESET}"
        exit 1
    fi
    cp "$LIMITS_TMP" "$LIMITS_PATH"
    echo -e "${GREEN}✓ limits.conf configuration applied.${RESET}"

    echo -e "${BLUE}→ Applied Changes:${RESET}"
    DIFF_OUTPUT=$(diff -u "$LIMITS_BACKUP" "$LIMITS_PATH")
    if [[ -z "$DIFF_OUTPUT" ]]; then
        echo -e "${GRAY}(No differences shown)${RESET}"
    else
        while IFS= read -r line; do
            if [[ "$line" =~ ^\+ && ! "$line" =~ ^\+\+ ]]; then
                echo -e "${GREEN}$line${RESET}"
            elif [[ "$line" =~ ^\- && ! "$line" =~ ^\-\- ]]; then
                echo -e "${RED}$line${RESET}"
            else
                echo -e "${WHITE:-\e[97m}$line${RESET}"
            fi
        done <<< "$DIFF_OUTPUT"
    fi
    echo
    read -p "→ Reboot system now? [y/N]: " confirm
    [[ "$confirm" =~ ^[Yy]$ ]] && reboot
}

# Function: Restore backup sysctl.conf
function restore_backup() {
    if [[ -f "$BACKUP_PATH" ]]; then
        cp "$BACKUP_PATH" "$SYSCTL_PATH"
        echo -e "${GREEN}✓ Backup restored.${RESET}"
        sysctl -p > /dev/null 2>&1
        echo
        read -p "→ Reboot system now? [y/N]: " confirm
        [[ "$confirm" =~ ^[Yy]$ ]] && reboot
    else
        echo -e "${RED}✗ No backup file found.${RESET}"
    fi
}

# Function: Restore backup limits.conf
function restore_limits_backup() {
    if [[ -f "$LIMITS_BACKUP" ]]; then
        cp "$LIMITS_BACKUP" "$LIMITS_PATH"
        echo -e "${GREEN}✓ limits.conf backup restored.${RESET}"
        echo
        read -p "→ Reboot system now? [y/N]: " confirm
        [[ "$confirm" =~ ^[Yy]$ ]] && reboot
    else
        echo -e "${RED}✗ No limits.conf backup file found.${RESET}"
    fi
}

# Show system info
clear
show_system_info

# Menu
echo -e "${BOLD}Choose an option:${RESET}"
echo -e "${YELLOW}1)${RESET} Install / Update Sysctl Optimization (sysctl.conf)"
echo -e "${YELLOW}2)${RESET} Install / Update Security Limits (limits.conf)"
echo -e "${YELLOW}3)${RESET} Restore Previous sysctl.conf Configuration"
echo -e "${YELLOW}4)${RESET} Restore Previous limits.conf Configuration"
echo -e "${YELLOW}5)${RESET} Exit"
echo
read -p "Enter choice [1-5]: " option

case "$option" in
    1) install_bbr ;;
    2) install_limits ;;
    3) restore_backup ;;
    4) restore_limits_backup ;;
    5) echo -e "${GRAY}Exiting...${RESET}" ;;
    *) echo -e "${RED}Invalid option.${RESET}" ;;
esac
