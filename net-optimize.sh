#!/bin/bash

# Ultra Accurate MTU+MSS Analyzer with Fragmentation & Loss Testing

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

HOSTS=("1.1.1.1" "8.8.8.8" "9.9.9.9")
MIN_MTU=576
MAX_MTU=9000

detect_iface() {
  ip route get 8.8.8.8 2>/dev/null | awk '/dev/ {for(i=1;i<=NF;i++){if($i=="dev"){print $(i+1); exit}}}'
}

test_mtu() {
  local mtu=$1
  local host=$2
  ping -M do -s $((mtu - 28)) -c 1 -W 1 "$host" &>/dev/null
  return $?
}

fine_tune_mtu() {
  local lower=$1
  local upper=$2
  local best=0
  for ((mtu=lower; mtu<=upper; mtu++)); do
    test_mtu "$mtu" "$HOST" && best=$mtu || break
  done
  echo "$best"
}

test_loss() {
  ping -c 10 "$1" | grep -oP '\d+(?=% packet loss)' || echo "100"
}

echo -e "${BOLD}📡 Ultra MTU + MSS Analyzer${NORMAL}"
IFACE=$(detect_iface)
info "Detected Interface: $IFACE"

read -rp "Use this interface? [Y/n]: " C
[[ "$C" =~ ^[Nn]$ ]] && read -rp "Enter interface: " IFACE

read -rp "Enter MTU Range (default: $MIN_MTU-$MAX_MTU): " RANGE
[[ "$RANGE" =~ ^[0-9]+-[0-9]+$ ]] && MIN_MTU=${RANGE%-*} && MAX_MTU=${RANGE#*-}

info "Testing packet loss across multiple hosts..."
declare -A LOSSES
for host in "${HOSTS[@]}"; do
  loss=$(test_loss "$host")
  LOSSES["$host"]="$loss"
done

HOST=$(printf "%s\n" "${!LOSSES[@]}" | sort -nk2 | head -n1)

echo -e "\n${BOLD}🌐 Best host for MTU test (lowest loss): $HOST (${LOSSES[$HOST]}%)${NORMAL}"

info "Performing binary MTU test ($MIN_MTU to $MAX_MTU)..."
LOW=$MIN_MTU
HIGH=$MAX_MTU
BEST=0

while (( LOW <= HIGH )); do
  MID=$(( (LOW + HIGH) / 2 ))
  if test_mtu "$MID" "$HOST"; then
    BEST=$MID
    LOW=$((MID + 1))
  else
    HIGH=$((MID - 1))
  fi
done

info "Fine-tuning MTU around $BEST..."
BEST_MTU=$(fine_tune_mtu $((BEST - 10)) $BEST)
BEST_MSS=$((BEST_MTU - 40))

# 📊 Display Results
echo -e "\n${BOLD}📊 Final Results:${NORMAL}"
printf "${BOLD}%-25s %-20s${NORMAL}\n" "Parameter" "Value"
printf "%-25s %-20s\n" "Selected Host" "$HOST"
printf "%-25s %-20s\n" "Selected Interface" "$IFACE"
printf "%-25s %-20s\n" "Packet Loss" "${LOSSES[$HOST]}%"
printf "%-25s %-20s\n" "Optimal MTU" "${GREEN}${BEST_MTU}${RESET}"
printf "%-25s %-20s\n" "Recommended MSS" "${YELLOW}${BEST_MSS}${RESET}"

# Optional apply
read -rp "Apply MTU=$BEST_MTU to $IFACE now? [y/N]: " APPLY
if [[ "$APPLY" =~ ^[Yy]$ ]]; then
  sudo ip link set dev "$IFACE" mtu "$BEST_MTU"
  success "MTU $BEST_MTU applied to $IFACE."
fi

read -rp "Add MSS clamp via iptables? [y/N]: " CLAMP
if [[ "$CLAMP" =~ ^[Yy]$ ]]; then
  sudo iptables -t mangle -A FORWARD -p tcp --tcp-flags SYN,RST SYN -j TCPMSS --set-mss "$BEST_MSS"
  success "MSS rule added."
fi

# Optional save
read -rp "Save results to log file? [y/N]: " SAVE
if [[ "$SAVE" =~ ^[Yy]$ ]]; then
  TIMESTAMP=$(date +"%Y%m%d-%H%M%S")
  FILE="mtu-mss-results-$TIMESTAMP.log"
  {
    echo "Interface: $IFACE"
    echo "Host: $HOST"
    echo "Packet Loss: ${LOSSES[$HOST]}%"
    echo "Optimal MTU: $BEST_MTU"
    echo "Recommended MSS: $BEST_MSS"
  } > "$FILE"
  success "Results saved to $FILE"
fi

success "✨ Optimization complete."
