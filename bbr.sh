#!/bin/bash

# ================= Colors =================
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

# ================= Paths =================
SYSCTL_PATH="/etc/sysctl.conf"
SYSCTL_BACKUP="/etc/sysctl.conf.bbr.bak"
SYSCTL_TMP="/tmp/sysctl.new"
SYSCTL_URL="https://raw.githubusercontent.com/Shellgate/tcp_optimization_bbr/main/sysctl.conf"

SEC_LIMITS_PATH="/etc/security/limits.conf"
SEC_LIMITS_BACKUP="/etc/security/limits.conf.bbr.bak"
SEC_LIMITS_TMP="/tmp/limits.new"
SEC_LIMITS_URL="https://raw.githubusercontent.com/Shellgate/tcp_optimization_bbr/main/etc/security/limits.conf"

SYSTEMD_SYSTEM_CONF="/etc/systemd/system.conf"
SYSTEMD_USER_CONF="/etc/systemd/user.conf"
SYSTEMD_SYSTEM_BACKUP="/etc/systemd/system.conf.bbr.bak"
SYSTEMD_USER_BACKUP="/etc/systemd/user.conf.bbr.bak"

GAI_CONF="/etc/gai.conf"

# ================= Safe Detect Functions =================

detect_active_interface() {
    iface=$(ip route show default 2>/dev/null | awk '{print $5; exit}')
    if [[ -n "$iface" ]]; then
        echo "$iface"
        return
    fi

    iface=$(ip -o link show up | awk -F': ' '{print $2}' | grep -v lo | head -n1)
    if [[ -n "$iface" ]]; then
        echo "$iface"
        return
    fi

    echo "Unknown"
}

detect_internet_status() {
    ip route show default &>/dev/null || {
        echo "Offline"
        return
    }

    if command -v timeout &>/dev/null; then
        timeout 1 bash -c '</dev/tcp/1.1.1.1/53' &>/dev/null \
            && echo "Online" || echo "No Internet"
    else
        echo "Unknown"
    fi
}

# ================= System Info =================
show_system_info() {
    CPU_MODEL=$(lscpu | awk -F: '/Model name/ {print $2}' | xargs)
    CORES=$(nproc)
    RAM_TOTAL=$(free -h | awk '/^Mem:/ {print $2}')
    RAM_USED=$(free -h | awk '/^Mem:/ {print $3}')
    DISK_TOTAL=$(df -h / | awk 'NR==2 {print $2}')
    DISK_USED=$(df -h / | awk 'NR==2 {print $3}')
    KERNEL=$(uname -r)

    INTERFACE=$(detect_active_interface)
    INTERNET_STATUS=$(detect_internet_status)

    echo -e "${AQUA}${BOLD}╔════════════ SYSTEM SUMMARY ════════════╗${RESET}"
    echo -e "${CYAN}CPU:${WHITE} $CPU_MODEL"
    echo -e "${CYAN}Cores:${WHITE} $CORES"
    echo -e "${CYAN}RAM:${WHITE} $RAM_USED / $RAM_TOTAL"
    echo -e "${CYAN}Disk:${WHITE} $DISK_USED / $DISK_TOTAL"
    echo -e "${CYAN}Kernel:${WHITE} $KERNEL"
    echo -e "${CYAN}Interface:${WHITE} $INTERFACE"
    echo -e "${CYAN}Internet:${WHITE} $INTERNET_STATUS"
    echo -e "${AQUA}${BOLD}╚═══════════════════════════════════════╝${RESET}"
    echo
}

# ================= sysctl =================
install_sysctl() {
    cp "$SYSCTL_PATH" "$SYSCTL_BACKUP" 2>/dev/null
    curl -fsSL --connect-timeout 5 "$SYSCTL_URL" -o "$SYSCTL_TMP" || {
        echo -e "${YELLOW}⚠ Internet not available, skipping sysctl download${RESET}"
        return
    }
    cp "$SYSCTL_TMP" "$SYSCTL_PATH"
    sysctl -p >/dev/null
    echo -e "${GREEN}✓ sysctl optimization applied${RESET}"
}

restore_sysctl() {
    [[ -f "$SYSCTL_BACKUP" ]] && cp "$SYSCTL_BACKUP" "$SYSCTL_PATH" && sysctl -p >/dev/null
    echo -e "${GREEN}✓ sysctl restored${RESET}"
}

# ================= Security Limits (limits.conf) =================
install_security_limits() {
    cp "$SEC_LIMITS_PATH" "$SEC_LIMITS_BACKUP" 2>/dev/null
    curl -fsSL --connect-timeout 5 "$SEC_LIMITS_URL" -o "$SEC_LIMITS_TMP" || {
        echo -e "${YELLOW}⚠ Internet not available, skipping limits download${RESET}"
        return
    }
    cp "$SEC_LIMITS_TMP" "$SEC_LIMITS_PATH"
    echo -e "${GREEN}✓ Security Limits applied (limits.conf)${RESET}"
}

restore_security_limits() {
    [[ -f "$SEC_LIMITS_BACKUP" ]] && cp "$SEC_LIMITS_BACKUP" "$SEC_LIMITS_PATH"
    echo -e "${GREEN}✓ Security Limits restored (limits.conf)${RESET}"
}

# ================= systemd Security Limits =================
install_systemd_security_limits() {
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

    systemctl daemon-reexec
    echo -e "${GREEN}✓ systemd Security Limits applied${RESET}"
}

restore_systemd_security_limits() {
    [[ -f "$SYSTEMD_SYSTEM_BACKUP" ]] && cp "$SYSTEMD_SYSTEM_BACKUP" "$SYSTEMD_SYSTEM_CONF"
    [[ -f "$SYSTEMD_USER_BACKUP" ]] && cp "$SYSTEMD_USER_BACKUP" "$SYSTEMD_USER_CONF"
    systemctl daemon-reexec
    echo -e "${GREEN}✓ systemd Security Limits restored${RESET}"
}

# ================= DNS Priority =================
set_dns_priority() {
    [[ ! -f "$GAI_CONF" ]] && touch "$GAI_CONF"

    if grep -q '^precedence ::ffff:0:0/96  100$' "$GAI_CONF"; then
        sed -i 's/^precedence ::ffff:0:0\/96  100/#precedence ::ffff:0:0\/96  100/' "$GAI_CONF"
        MODE="IPv6"
    else
        sed -i 's/^#precedence ::ffff:0:0\/96  100/precedence ::ffff:0:0\/96  100/' "$GAI_CONF"
        grep -q '^precedence ::ffff:0:0/96' "$GAI_CONF" || \
            echo 'precedence ::ffff:0:0/96  100' >> "$GAI_CONF"
        MODE="IPv4"
    fi

    if systemctl is-active --quiet systemd-resolved; then
        systemctl reload systemd-resolved 2>/dev/null || systemctl restart systemd-resolved
        RES="reloaded"
    else
        RES="not active"
    fi

    echo -e "${GREEN}✓ DNS Priority set to ${MODE}${RESET}"
    echo -e "${GRAY}systemd-resolved: ${RES}${RESET}"
}

# ================= Combined =================
apply_all() {
    install_sysctl
    install_security_limits
    install_systemd_security_limits
}

restore_all() {
    restore_sysctl
    restore_security_limits
    restore_systemd_security_limits
}

# ================= Menu =================
clear
show_system_info

while true; do
    echo -e "${BOLD}Choose an option:${RESET}"
    echo -e "${YELLOW}1)${RESET} Apply sysctl optimization"
    echo -e "${YELLOW}2)${RESET} Apply Security Limits (limits.conf)"
    echo -e "${YELLOW}3)${RESET} Apply systemd Security Limits"
    echo -e "${GREEN}4)${RESET} Apply ALL"
    echo -e "${YELLOW}5)${RESET} Restore sysctl"
    echo -e "${YELLOW}6)${RESET} Restore Security Limits (limits.conf)"
    echo -e "${YELLOW}7)${RESET} Restore systemd Security Limits"
    echo -e "${RED}8)${RESET} Restore ALL"
    echo -e "${MAGENTA}9)${RESET} Toggle DNS Priority"
    echo -e "${GRAY}10)${RESET} Exit"
    echo
    read -p "Enter choice [1-10]: " opt

    case "$opt" in
        1) install_sysctl ;;
        2) install_security_limits ;;
        3) install_systemd_security_limits ;;
        4) apply_all ;;
        5) restore_sysctl ;;
        6) restore_security_limits ;;
        7) restore_systemd_security_limits ;;
        8) restore_all ;;
        9) set_dns_priority ;;
        10) exit 0 ;;
        *) echo -e "${RED}Invalid option${RESET}" ;;
    esac
    echo
done
