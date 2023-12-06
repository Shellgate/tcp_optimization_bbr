#!/bin/bash

# Project variables
project_name="TCP Optimization PCC"
backup_and_destination_path="/etc/sysctl.conf"
new_file_url="https://raw.githubusercontent.com/Shellgate/pcc-tcp-optimizer/main/sysctl.conf"

# Display system information
display_system_info() {
    echo -e "=== $project_name ==="
    echo -e "System Information:"
    echo -e "  OS: $(lsb_release -d | cut -f2)"
    echo -e "  CPU: $(grep 'model name' /proc/cpuinfo | head -n1 | cut -d' ' -f3-)"
    echo -e "  RAM: $(free -m | awk '/Mem/ {print $2 " MB"}')"
    echo -e "====================="
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
options=("Install Script" "Restore Initial Backup" "Exit")
PS3="Select an option: "

select option in "${options[@]}"; do
    case $REPLY in
        1)
            # Option 1: Install Script
            cp "$backup_and_destination_path" "$backup_and_destination_path.bak"
            echo "Downloading the new file..."
            curl -sSfL "$new_file_url" -o "$backup_and_destination_path" --progress-bar
            echo "File replaced, backup created."
            prompt_restart
            break
            ;;
        2)
            # Option 2: Restore Initial Backup
            cp "$backup_and_destination_path.bak" "$backup_and_destination_path"
            echo "File restored from initial backup."
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
