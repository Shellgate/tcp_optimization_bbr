#!/bin/bash

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

BACKUP_PATH="/etc/sysctl.conf.bbr.bak"
SYSCTL_PATH="/etc/sysctl.conf"
TMP_FILE="/tmp/sysctl.new"
SYSCTL_URL="https://raw.githubusercontent.com/Shellgate/tcp_optimization_bbr/main/sysctl.conf"

LIMITS_PATH="/etc/security/limits.conf"
LIMITS_BACKUP="/etc/security/limits.conf.bbr.bak"
LIMITS_TMP="/tmp/limits.new"
LIMITS_URL="https://raw.githubusercontent.com/Shellgate/tcp_optimization_bbr/main/etc/security/limits.conf"

SYSTEMD_SYSTEM_CONF="/etc/systemd/system.conf"
SYSTEMD_USER_CONF="/etc/systemd/user.conf"
SYSTEMD_SYSTEM_BACKUP="/etc/systemd/system.conf.bbr.bak"
SYSTEMD_USER_BACKUP="/etc/systemd/user.conf.bbr.bak"

GAI_CONF="/etc/gai.conf"

# ---------------- Safe helpers ----------------
function detect_active_interface() {
    local iface
    iface=$(ip route show default 2>/dev/null | awk '{print $5; exit}')
    if [[ -n "$iface" ]]; then
        echo "$iface"
        return
    fi
    iface=$(ip -o link show up 2>/dev/null | awk -F': ' '{print $2}' | grep -v lo | head -n1)
    if [[ -n "$iface" ]]; then
        echo "$iface"
        return
    fi
    echo "Unknown"
}

function internet_status() {
    # No default route => offline
    ip route show default &>/dev/null || { echo "Offline"; return; }

    # Non-blocking check if timeout exists
    if command -v timeout &>/dev/null; then
        timeout 1 bash -c '</dev/tcp/1.1.1.1/53' &>/dev/null && echo "Online" || echo "Offline"
    else
        echo "Unknown"
    fi
}

# ---------------- Original panel (improved safety) ----------------
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

    INTERFACE=$(detect_active_interface)
    SPEED=$(ethtool "$INTERFACE" 2>/dev/null | grep -i speed | awk '{print $2}')
    LOCAL_IP=$(hostname -I 2>/dev/null | awk '{print $1}')

    # Public IP with short timeout to avoid hang when no internet
    if command -v timeout &>/dev/null; then
        PUBLIC_IP=$(timeout 2 curl -s https://api.ipify.org 2>/dev/null)
    else
        PUBLIC_IP=$(curl -s https://api.ipify.org 2>/dev/null)
    fi
    [[ -z "$PUBLIC_IP" ]] && PUBLIC_IP="Unknown"

    BBR_STATUS=$(sysctl net.ipv4.tcp_congestion_control 2>/dev/null | awk '{print $3}')
    BBR_ACTIVE=$(lsmod 2>/dev/null | grep bbr)
    PING_TEST=$(internet_status)

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
    printf "${CYAN}%-15s${WHITE}%s\n" "Local IP:" "${LOCAL_IP:-Unknown}"
    printf "${CYAN}%-15s${WHITE}%s\n" "Public IP:" "$PUBLIC_IP"
    printf "${CYAN}%-15s${WHITE}%s\n" "Internet:" "$PING_TEST"
    echo -e "${GRAY}───────────────────── BBR ─────────────────────${RESET}"
    printf "${CYAN}%-15s${WHITE}%s\n" "Congestion:" "${BBR_STATUS:-Unknown}"
    if [[ "$BBR_ACTIVE" == *bbr* ]]; then
        printf "${CYAN}%-15s${LIME}Active${RESET}\n" "BBR Module:"
    else
        printf "${CYAN}%-15s${MAGENTA}Inactive${RESET}\n" "BBR Module:"
    fi
    echo -e "${AQUA}${BOLD}╚══════════════════════════════════════════════╝${RESET}"
    echo
}

# ---------------- Sysctl (original style + safe curl) ----------------
function install_bbr() {
    echo -e "${BLUE}→ Preparing to install system optimization...${RESET}"
    [[ -f "$BACKUP_PATH" ]] && rm -f "$BACKUP_PATH"
    cp "$SYSCTL_PATH" "$BACKUP_PATH" 2>/dev/null
    echo -e "${GREEN}✓ Backup saved to $BACKUP_PATH${RESET}"

    if command -v timeout &>/dev/null; then
        timeout 5 curl -fsSL -o "$TMP_FILE" "$SYSCTL_URL" || {
            echo -e "${YELLOW}⚠ Download failed or no internet. Skipping.${RESET}"
            return
        }
    else
        curl -fsSL -o "$TMP_FILE" "$SYSCTL_URL" || {
            echo -e "${YELLOW}⚠ Download failed or no internet. Skipping.${RESET}"
            return
        }
    fi

    cp "$TMP_FILE" "$SYSCTL_PATH"
    echo -e "${GREEN}✓ Configuration applied.${RESET}"

    echo -e "${BLUE}→ Applied Changes:${RESET}"
    DIFF_OUTPUT=$(diff -u "$BACKUP_PATH" "$SYSCTL_PATH" 2>/dev/null)
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

    ip tcp_metrics flush all > /dev/null 2>&1
    sysctl -p > /dev/null 2>&1
    echo
    read -p "→ Reboot system now? [y/N]: " confirm
    [[ "$confirm" =~ ^[Yy]$ ]] && reboot
}

# ---------------- Security Limits (same original behavior + safe curl) ----------------
function install_limits() {
    echo -e "${BLUE}→ Preparing to install security limits optimization...${RESET}"
    [[ -f "$LIMITS_BACKUP" ]] && rm -f "$LIMITS_BACKUP"
    cp "$LIMITS_PATH" "$LIMITS_BACKUP" 2>/dev/null
    echo -e "${GREEN}✓ Backup saved to $LIMITS_BACKUP${RESET}"

    if command -v timeout &>/dev/null; then
        timeout 5 curl -fsSL -o "$LIMITS_TMP" "$LIMITS_URL" || {
            echo -e "${YELLOW}⚠ Download failed or no internet. Skipping.${RESET}"
            return
        }
    else
        curl -fsSL -o "$LIMITS_TMP" "$LIMITS_URL" || {
            echo -e "${YELLOW}⚠ Download failed or no internet. Skipping.${RESET}"
            return
        }
    fi

    cp "$LIMITS_TMP" "$LIMITS_PATH"
    echo -e "${GREEN}✓ limits.conf configuration applied.${RESET}"

    echo -e "${BLUE}→ Applied Changes:${RESET}"
    DIFF_OUTPUT=$(diff -u "$LIMITS_BACKUP" "$LIMITS_PATH" 2>/dev/null)
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

# ---------------- Restore sysctl (original) ----------------
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

# ---------------- Restore limits (original) ----------------
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

# ---------------- DNS Priority (original dynamic status + fixed resolved reload) ----------------
function get_dns_priority_status() {
    if [[ ! -f "$GAI_CONF" ]]; then
        echo -e "${BLUE}IPv6${RESET}"
        return
    fi
    if grep -q '^precedence ::ffff:0:0/96  \+100$' "$GAI_CONF"; then
        echo -e "${GREEN}IPv4${RESET}"
    else
        echo -e "${BLUE}IPv6${RESET}"
    fi
}

function set_dns_priority() {
    if [[ ! -f "$GAI_CONF" ]]; then
        touch "$GAI_CONF"
    fi

    if grep -q '^precedence ::ffff:0:0/96  \+100$' "$GAI_CONF"; then
        sudo sed -i 's/^precedence ::ffff:0:0\/96  \+100$/#precedence ::ffff:0:0\/96  100/' "$GAI_CONF"
        echo -e "DNS Priority changed to: ${BLUE}IPv6${RESET}"
    else
        sudo sed -i 's/^#precedence ::ffff:0:0\/96  \+100$/precedence ::ffff:0:0\/96  100/' "$GAI_CONF"
        if ! grep -q '^precedence ::ffff:0:0/96  \+100$' "$GAI_CONF"; then
            echo 'precedence ::ffff:0:0/96  100' | sudo tee -a "$GAI_CONF" >/dev/null
        fi
        echo -e "DNS Priority changed to: ${GREEN}IPv4${RESET}"
    fi

    # FIX: reload systemd-resolved when active (no hang)
    if systemctl list-unit-files 2>/dev/null | grep -q systemd-resolved; then
        if systemctl is-active --quiet systemd-resolved; then
            sudo systemctl reload systemd-resolved 2>/dev/null || sudo systemctl restart systemd-resolved
            echo -e "${AQUA}✓ systemd-resolved reloaded.${RESET}"
        else
            echo -e "${YELLOW}systemd-resolved is installed but not active.${RESET}"
        fi
    else
        echo -e "${GRAY}systemd-resolved not found. No reload needed.${RESET}"
    fi

    echo -e "Current DNS Priority: [$(get_dns_priority_status)]"
    echo
}

# ---------------- NEW: systemd Security Limits (apply/restore) ----------------
function install_systemd_security_limits() {
    echo -e "${BLUE}→ Preparing to install systemd security limits...${RESET}"
    [[ -f "$SYSTEMD_SYSTEM_BACKUP" ]] && rm -f "$SYSTEMD_SYSTEM_BACKUP"
    [[ -f "$SYSTEMD_USER_BACKUP" ]] && rm -f "$SYSTEMD_USER_BACKUP"

    cp "$SYSTEMD_SYSTEM_CONF" "$SYSTEMD_SYSTEM_BACKUP" 2>/dev/null
    cp "$SYSTEMD_USER_CONF" "$SYSTEMD_USER_BACKUP" 2>/dev/null

    for FILE in "$SYSTEMD_SYSTEM_CONF" "$SYSTEMD_USER_CONF"; do
        [[ ! -f "$FILE" ]] && touch "$FILE"
        sed -i '/^DefaultLimitNOFILE=/d' "$FILE"
        sed -i '/^DefaultLimitNPROC=/d' "$FILE"
        sed -i '/^DefaultTasksMax=/d' "$FILE"
        cat <<EOF >> "$FILE"

# systemd Security Limits
DefaultLimitNOFILE=1048576
DefaultLimitNPROC=1048576
DefaultTasksMax=1048576
EOF
    done

    sudo systemctl daemon-reexec
    echo -e "${GREEN}✓ systemd security limits applied.${RESET}"
    echo
}

function restore_systemd_security_limits() {
    echo -e "${BLUE}→ Restoring systemd security limits backups...${RESET}"
    if [[ -f "$SYSTEMD_SYSTEM_BACKUP" ]]; then
        cp "$SYSTEMD_SYSTEM_BACKUP" "$SYSTEMD_SYSTEM_CONF"
    fi
    if [[ -f "$SYSTEMD_USER_BACKUP" ]]; then
        cp "$SYSTEMD_USER_BACKUP" "$SYSTEMD_USER_CONF"
    fi
    sudo systemctl daemon-reexec
    echo -e "${GREEN}✓ systemd security limits restored.${RESET}"
    echo
}

# ---------------- NEW: Apply/Restore ALL ----------------
function apply_all() {
    install_bbr
    install_limits
    install_systemd_security_limits
}

function restore_all() {
    restore_backup
    restore_limits_backup
    restore_systemd_security_limits
}

# ================= Main =================
clear
show_system_info

while true; do
    echo -e "${BOLD}Choose an option:${RESET}"
    echo -e "${YELLOW}1)${RESET} Install / Update Sysctl Optimization (sysctl.conf)"
    echo -e "${YELLOW}2)${RESET} Install / Update Security Limits (limits.conf)"
    echo -e "${YELLOW}3)${RESET} Restore Previous sysctl.conf Configuration"
    echo -e "${YELLOW}4)${RESET} Restore Previous limits.conf Configuration"
    echo -e "${YELLOW}5)${RESET} DNS Priority [$(get_dns_priority_status)]"
    echo -e "${YELLOW}6)${RESET} Install / Update systemd Security Limits (system.conf + user.conf)"
    echo -e "${YELLOW}7)${RESET} Restore Previous systemd Security Limits"
    echo -e "${GREEN}8)${RESET} Apply ALL (sysctl + limits + systemd)"
    echo -e "${RED}9)${RESET} Restore ALL (sysctl + limits + systemd)"
    echo -e "${GRAY}10)${RESET} Exit"
    echo
    read -p "Enter choice [1-10]: " option

    case "$option" in
        1) install_bbr ;;
        2) install_limits ;;
        3) restore_backup ;;
        4) restore_limits_backup ;;
        5) set_dns_priority ;;
        6) install_systemd_security_limits ;;
        7) restore_systemd_security_limits ;;
        8) apply_all ;;
        9) restore_all ;;
        10) echo -e "${GRAY}Exiting...${RESET}"; exit 0 ;;
        *) echo -e "${RED}Invalid option.${RESET}" ;;
    esac
    echo
done
