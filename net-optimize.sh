#!/bin/bash

# Advanced Network MTU + MSS Analyzer with Local and Instagram Testing

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

# Function to detect the active network interface
detect_iface() {
  ip route get 8.8.8.8 2>/dev/null | awk '/dev/ {for(i=1;i<=NF;i++){if($i=="dev"){print $(i+1); exit}}}'
}

# Function to test MTU with no fragmentation
test_mtu() {
  local mtu=$1
  local host=$2
  ping -M do -s $((mtu - 28)) -c 1 -W 1 "$host" &>/dev/null
  return $?
}

# Function to test packet loss
test_loss() {
  ping -c 10 "$1" | grep -oP '\d+(?=% packet loss)' || echo "100"
}

# Function to resolve DNS and get the IP of Instagram
get_instagram_ip() {
  dig +short instagram.com | head -n 1
}

# Function to find the best MTU from a range using binary search
find_best_mtu() {
  local min_mtu=$1
  local max_mtu=$2
  local host=$3
  local best=0
  while (( min_mtu <= max_mtu )); do
    local mid=$(( (min_mtu + max_mtu) / 2 ))
    if test_mtu "$mid" "$host"; then
      best=$mid
      min_mtu=$((mid + 1))
    else
      max_mtu=$((mid - 1))
    fi
  done
  echo "$best"
}

# Function to perform fine-tuning for MTU
fine_tune_mtu() {
  local lower=$1
  local upper=$2
  local best=0
  for ((mtu=lower; mtu<=upper; mtu++)); do
    test_mtu "$mtu" "$HOST" && best=$mtu || break
  done
  echo "$best"
}

# Detect the active network interface
IFACE=$(detect_iface)
info "Detected Interface: $IFACE"

# Test packet loss for multiple hosts (internal and external)
HOSTS=("1.1.1.1" "8.8.8.8" "9.9.9.9")
info "Testing packet loss across multiple hosts..."
declare -A LOSSES
for host in "${HOSTS[@]}"; do
  loss=$(test_loss "$host")
  LOSSES["$host"]="$loss"
done

# Get the best external host (lowest packet loss)
BEST_HOST=$(printf "%s\n" "${!LOSSES[@]}" | sort -nk2 | head -n1)
info "Best external host for MTU test (lowest loss): $BEST_HOST (${LOSSES[$BEST_HOST]}%)"

# Get the IP of Instagram
INSTAGRAM_IP=$(get_instagram_ip)
info "Instagram IP: $INSTAGRAM_IP"

# Test MTU for Local Network, External, and Instagram
info "Finding best MTU for local network (internal)..."
LOCAL_MTU=$(find_best_mtu 576 16114 "$IFACE")
info "Best MTU for local network: $LOCAL_MTU"

info "Finding best MTU for $BEST_HOST..."
EXTERNAL_MTU=$(find_best_mtu 576 1492 "$BEST_HOST")
info "Best MTU for $BEST_HOST: $EXTERNAL_MTU"

info "Finding best MTU for Instagram..."
INSTAGRAM_MTU=$(find_best_mtu 576 1492 "$INSTAGRAM_IP")
info "Best MTU for Instagram: $INSTAGRAM_MTU"

# Fine-tune the MTU for local network
info "Fine-tuning MTU for local network..."
FINE_TUNED_LOCAL=$(fine_tune_mtu $((LOCAL_MTU - 10)) $LOCAL_MTU)

# Fine-tune the MTU for external host
info "Fine-tuning MTU for external host..."
FINE_TUNED_EXTERNAL=$(fine_tune_mtu $((EXTERNAL_MTU - 10)) $EXTERNAL_MTU)

# Fine-tune the MTU for Instagram
info "Fine-tuning MTU for Instagram..."
FINE_TUNED_INSTAGRAM=$(fine_tune_mtu $((INSTAGRAM_MTU - 10)) $INSTAGRAM_MTU)

# Compute MSS for each MTU
MSS_LOCAL=$((FINE_TUNED_LOCAL - 40))
MSS_EXTERNAL=$((FINE_TUNED_EXTERNAL - 40))
MSS_INSTAGRAM=$((FINE_TUNED_INSTAGRAM - 40))

# Display results in a formatted table
echo -e "\n${BOLD}📊 Final Results:${NORMAL}"
printf "${BOLD}%-25s %-20s %-20s %-20s %-20s${NORMAL}\n" "Target" "Max MTU" "Best MTU" "Recommended MSS" "Packet Loss"
printf "%-25s %-20s %-20s %-20s %-20s\n" "Local Network" "16114" "$FINE_TUNED_LOCAL" "$MSS_LOCAL" "N/A"
printf "%-25s %-20s %-20s %-20s %-20s\n" "External Host ($BEST_HOST)" "1492" "$FINE_TUNED_EXTERNAL" "$MSS_EXTERNAL" "${LOSSES[$BEST_HOST]}%"
printf "%-25s %-20s %-20s %-20s %-20s\n" "Instagram ($INSTAGRAM_IP)" "1492" "$FINE_TUNED_INSTAGRAM" "$MSS_INSTAGRAM" "N/A"

# Optional: Save results to log file
read -rp "Save results to log file? [y/N]: " SAVE
if [[ "$SAVE" =~ ^[Yy]$ ]]; then
  TIMESTAMP=$(date +"%Y%m%d-%H%M%S")
  FILE="mtu-mss-results-$TIMESTAMP.log"
  {
    echo "Local Network MTU: $FINE_TUNED_LOCAL"
    echo "External Host ($BEST_HOST) MTU: $FINE_TUNED_EXTERNAL"
    echo "Instagram MTU: $FINE_TUNED_INSTAGRAM"
    echo "Recommended MSS Local: $MSS_LOCAL"
    echo "Recommended MSS External: $MSS_EXTERNAL"
    echo "Recommended MSS Instagram: $MSS_INSTAGRAM"
  } > "$FILE"
  success "Results saved to $FILE"
fi

success "✨ Network optimization complete."
