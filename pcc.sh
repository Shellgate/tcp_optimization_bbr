#!/bin/bash

# Define project variables
project_name="Advanced TCP Optimization PCC"
backup_and_destination_path="/etc/sysctl.conf"
new_file_url="https://raw.githubusercontent.com/Shellgate/pcc-tcp-optimizer/main/sysctl.conf"

# Set ANSI color codes
bold="\e[1m"
underline="\e[4m"
reset="\e[0m"
green="\e[32m"
blue="\e[34m"

# Function to display system information
display_system_info() {
    echo -e "$bold$underline:: System Information ::$reset"
    # Display OS information
    echo -e "  $bold$blue- Operating System:$reset $(lsb_release -d | cut -f2)"
    # Display CPU information
    echo -e "  $bold$blue- CPU:$reset $(grep 'model name' /proc/cpuinfo | head -n1 | cut -d' ' -f3-)"
    # Display RAM information
    echo -e "  $bold$blue- RAM:$reset $(free -m | awk '/Mem/ {print $2 " MB"}')"
}

# Function to prompt user for restart
prompt_restart() {
    read -p "Do you want to restart the system? (y/n): " restart_choice
    case $restart_choice in
        [Yy])
            reboot
            ;;
        [Nn])
            echo "No restart is performed. Exiting the script."
            ;;
        *)
            echo "Invalid choice. No restart is performed. Exiting the script."
            ;;
    esac
}

# Display header and subheader
echo -e "$bold$blue=== $project_name ===$reset"
echo -e "$bold$green:: System Report ::$reset\n"

# Display system information before any action
display_system_info

# Display menu
options=("Install Script" "Restore Initial Backup" "Exit")
echo -e "$bold$green"
PS3="Please select an option: "

select option in "${options[@]}"; do
    case $REPLY in
        1)
            # Option 1: Install Script
            cp "$backup_and_destination_path" "$backup_and_destination_path.bak"
            
            # Download new file with progress bar
            echo "Downloading the new file..."
            curl -sSfL "$new_file_url" -o "$backup_and_destination_path" --progress-bar
            
            # Display success message
            echo "File successfully replaced, and a backup has been created."
            display_system_info
            prompt_restart
            break
            ;;
        2)
            # Option 2: Restore Initial Backup
            cp "$backup_and_destination_path.bak" "$backup_and_destination_path"
            echo "File successfully restored from the initial backup."
            display_system_info
            prompt_restart
            break
            ;;
        3)
            # Option 3: Exit
            echo "Exiting the script."
            break
            ;;
        *)
            echo "Please select a valid number."
            ;;
    esac
done
