#!/bin/bash

# Terminal-friendly, visually enhanced MTU+MSS optimizer
# Requires: bash, iproute2, ping, awk

# Colors
BOLD=$(tput bold)
NORMAL=$(tput sgr0)
RED=$(tput setaf 1)
GREEN=$(tput setaf 2)
BLUE=$(tput setaf 4)
YELLOW=$(tput setaf 3)
RESET=$(tput sgr0)

info() { echo -e "${BLUE}[INFO]${RESET} $1"; }
success() { echo -e "${GREEN}[OK]${RESET} $1"; }
warn() { echo -e "${YELLOW}[WARN]${RESET} $1"; }
error() { echo -e "${RED}[ERROR]${RESET} $1"; }

# Detect default interface
detect_iface() {
  ip route get 8.8.8.8 2>/dev/null | awk '/dev/ {for(i=1;i<=NF;i++){if($i=="dev"){print $(i+1); exit}}}'
}

# Test MTU with ping
test_mtu() {
  local mtu=$1
  ping -M do -s $((mtu - 28)) -c 1 -W 1 "$HOST" &>/dev/null
  return $?
}

# Test packet loss
test_loss() {
  ping -c 10 "$HOST" | grep -oP '\d+(?=% packet loss)' || echo "100"
}

# --- MAIN ---
HOST="8.8.8.8"
IFACE=$(detect_iface)

echo -e "${BOLD}🔍 Network Optimizer (Terminal Enhanced)${NORMAL}"
info "Detected interface: ${IFACE}"

read -rp "Use detected interface? [Y/n]: " ANS
[[ "$ANS" =~ ^[Nn]$ ]] && read -rp "Enter interface name: " IFACE

read -rp "Enter test host (default: 8.8.8.8): " H
[[ -n "$H" ]] && HOST="$H"

info "Checking packet loss to $HOST..."
LOSS=$(test_loss)
if (( LOSS > 20 )); then
  warn "High packet loss detected: ${LOSS}%"
else
  success "Packet loss acceptable: ${LOSS}%"
fi

info "Starting MTU discovery (supporting Jumbo Frames)..."
MIN=1200
MAX=9000
BEST_MTU=0

while (( MIN <= MAX )); do
  MID=$(( (MIN + MAX) / 2 ))
  if test_mtu "$MID"; then
    BEST_MTU=$MID
    MIN=$((MID + 1))
  else
    MAX=$((MID - 1))
  fi
done

BEST_MSS=$((BEST_MTU - 40))

# Final Result Table
echo -e "\n${BOLD}📊 Optimization Result:${NORMAL}"
printf "${BOLD}%-20s %-20s\n${NORMAL}" "Parameter" "Value"
printf "%-20s %-20s\n" "Interface" "$IFACE"
printf "%-20s %-20s\n" "Test Host" "$HOST"
printf "%-20s %-20s\n" "Packet Loss" "${LOSS}%"
printf "%-20s %-20s\n" "Optimal MTU" "${GREEN}${BEST_MTU}${RESET}"
printf "%-20s %-20s\n" "Recommended MSS" "${YELLOW}${BEST_MSS}${RESET}"

# Apply?
echo
read -rp "Apply MTU=$BEST_MTU to $IFACE now? [y/N]: " APPLY
if [[ "$APPLY" =~ ^[Yy]$ ]]; then
  sudo ip link set dev "$IFACE" mtu "$BEST_MTU"
  success "MTU $BEST_MTU applied to $IFACE."
fi

read -rp "Add MSS clamp rule via iptables? [y/N]: " CLAMP
if [[ "$CLAMP" =~ ^[Yy]$ ]]; then
  sudo iptables -t mangle -C FORWARD -p tcp --tcp-flags SYN,RST SYN -j TCPMSS --set-mss "$BEST_MSS" 2>/dev/null || \
  sudo iptables -t mangle -A FORWARD -p tcp --tcp-flags SYN,RST SYN -j TCPMSS --set-mss "$BEST_MSS"
  success "iptables MSS clamp rule added (non-persistent)."
fi

echo
info "If you'd like to persist:"
echo "- Edit MTU in /etc/netplan/* or /etc/network/interfaces"
echo "- Save iptables: sudo iptables-save > /etc/iptables/rules.v4"

success "All done."
