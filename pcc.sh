#!/bin/bash

# Project variables
project_name="TCP Optimization PCC"
backup_and_destination_path="/etc/sysctl.conf"
new_file_url="https://raw.githubusercontent.com/Shellgate/pcc-tcp-optimizer/main/sysctl.conf"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

# Display system information
display_system_info() {
    echo -e "\n=== ${GREEN}$project_name${NC} ==="
    echo -e "${RED}System Information:${NC}"
    echo -e "+------------------------+"
    echo -e "|  OS: $(lsb_release -d | cut -f2)  |"
    echo -e "|  CPU: $(grep 'model name' /proc/cpuinfo | head -n1 | cut -d' ' -f3-)  |"
    echo -e "|  RAM: $(free -m | awk '/Mem/ {print $2 " MB"}')  |"
    echo -e "+------------------------+"
}

# Prompt user for restart
prompt_restart() {
    read -p "Restart the system? (y/n): " restart_choice
    case $restart_choice in
        [Yy]) reboot ;;
        [Nn]) echo "No restart. Exiting." ;;
        *) echo "Invalid choice. No restart. Exiting." ;;
    esac
}

# Display system info before any action
display_system_info

# Display menu
options=("1. Install Script" "2. Restore Initial Backup" "3. Exit")

printf "Select an option:\n"
for i in "${!options[@]}"; do
    printf "%d) %s\n" "$((i+1))" "${options[$i]}"
done

read -p "#? " choice
case $choice in
    1)
        # Option 1: Install Script
        cp "$backup_and_destination_path" "$backup_and_destination_path.bak"
        echo "Downloading the new file..."
        curl -sSfL "$new_file_url" -o "$backup_and_destination_path" --progress-bar
        echo -e "${GREEN}File replaced, backup created.${NC}"
        prompt_restart
        ;;
    2)
        # Option 2: Restore Initial Backup
        cp "$backup_and_destination_path.bak" "$backup_and_destination_path"
        echo -e "${GREEN}File restored from initial backup.${NC}"
        prompt_restart
        ;;
    3)
        # Option 3: Exit
        echo -e "${RED}Exiting.${NC}"
        ;;
    *)
        echo "Invalid choice. Please select again."
        ;;
esac
