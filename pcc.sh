#!/bin/bash

project="TCP Optimization PCC"
backup_path="/etc/sysctl.conf"
new_file_url="https://raw.githubusercontent.com/Shellgate/pcc-tcp-optimizer/main/sysctl.conf"
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

display_info() {
    echo -e "\n=== ${GREEN}$project${NC} ==="
    echo -e "${RED}System Information:${NC}"
    echo -e "+------------------------+"
    echo -e "|  OS: $(lsb_release -d | cut -f2)  |"
    echo -e "|  CPU: $(grep 'model name' /proc/cpuinfo | head -n1 | cut -d' ' -f3-)  |"
    echo -e "|  RAM: $(free -m | awk '/Mem/ {print $2 " MB"}')  |"
    echo -e "+------------------------+"
}

prompt_restart() {
    read -p "Restart the system? (y/n): " restart_choice
    case $restart_choice in
        [Yy]) reboot ;;
        [Nn]) echo "No restart. Exiting." ;;
        *) echo "Invalid choice. No restart. Exiting." ;;
    esac
}

display_info

options=("Install Script" "Restore Initial Backup" "Exit")
PS3="Select an option: "

select option in "${options[@]}"; do
    case $REPLY in
        1)
            cp "$backup_path" "$backup_path.bak"
            echo "Downloading the new file..."
            curl -sSfL "$new_file_url" -o "$backup_path" --progress-bar
            echo -e "${GREEN}File replaced, backup created.${NC}"
            prompt_restart
            break
            ;;
        2)
            cp "$backup_path.bak" "$backup_path"
            echo -e "${GREEN}File restored from initial backup.${NC}"
            prompt_restart
            break
            ;;
        3)
            echo -e "${RED}Exiting.${NC}"
            break
            ;;
        *) echo "Invalid choice. Please select again." ;;
    esac
done
