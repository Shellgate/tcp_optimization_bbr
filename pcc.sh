#!/bin/bash

# Project variables
project_name="Advanced TCP Optimization PCC"
backup_and_destination_path="/etc/sysctl.conf"
new_file_url="https://raw.githubusercontent.com/Shellgate/pcc-tcp-optimizer/main/sysctl.conf"

# Color codes
bold="\e[1m"
underline="\e[4m"
reset="\e[0m"
green="\e[32m"
blue="\e[34m"

# Display system information
display_system_info() {
    echo -e "$bold$underline:: System Information ::$reset"
    echo -e "  $bold$blue- OS:$reset $(lsb_release -d | cut -f2)"
    echo -e "  $bold$blue- CPU:$reset $(grep 'model name' /proc/cpuinfo | head -n1 | cut -d' ' -f3-)"
    echo -e "  $bold$blue- RAM:$reset $(free -m | awk '/Mem/ {print $2 " MB"}')"
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

# Display header
echo -e "$bold$blue=== $project_name ===$reset"
echo -e "$bold$green:: System Report ::$reset\n"

# Display system info before any action
display_system_info

# Display menu
options=("Install Script" "Restore Initial Backup" "Exit")
echo -e "$bold$green"
PS3="Select an option: "

select option in "${options[@]}"; do
    case $REPLY in
        1)
            # Option 1: Install Script
            cp "$backup_and_destination_path" "$backup_and_destination_path.bak"
            echo "Downloading the new file..."
            curl -sSfL "$new_file_url" -o "$backup_and_destination_path" --progress-bar
            echo "File replaced, backup created."
            display_system_info
            prompt_restart
            break
            ;;
        2)
            # Option 2: Restore Initial Backup
            cp "$backup_and_destination_path.bak" "$backup_and_destination_path"
            echo "File restored from initial backup."
            display_system_info
            prompt_restart
            break
            ;;
        3)
            # Option 3: Exit
            echo "Exiting."
            break
            ;;
        *) echo "Invalid choice. Please select again." ;;
    esac
done
