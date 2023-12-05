#!/bin/bash

# Define project variables
project_name="Advanced TCP Optimization PCC"
backup_and_destination_path="/etc/sysctl.conf"
new_file_url="https://raw.githubusercontent.com/Shellgate/pcc-tcp-optimizer/main/sysctl.conf"

# Display header and subheader
echo -e "$bold$blue=== $project_name ===$reset"
echo -e "$bold$green:: System Report ::$reset\n"

# Set formatting colors
bold=$(tput bold)
underline=$(tput sgr 0 1)
reset=$(tput sgr0)
green=$(tput setaf 2)
yellow=$(tput setaf 3)
blue=$(tput setaf 4)

# Flags for replacement and checking
replace_flag=false
check_replace_flag=false

# Function to display system information
display_system_info() {
    echo -e "\n$bold$underline:: System Information ::$reset"
    # Add commands to display system information here
}

# Function to prompt for restart
prompt_restart() {
    read -p "Do you want to restart your system? (y/n): " restart_choice
    if [[ $restart_choice == "y" || $restart_choice == "Y" ]]; then
        echo "Restarting the system..."
        # Add command to restart the system here
    else
        echo "No restart requested."
    fi
}

# Menu options
options=("1. Install Script" "2. Restore Initial Backup" "3. Exit")

# Display menu
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
            replace_flag=true
            check_replace_flag=true
            display_system_info
            prompt_restart
            break
            ;;
        2)
            # Option 2: Restore Initial Backup
            cp "$backup_and_destination_path.bak" "$backup_and_destination_path"
            echo "File successfully restored from the initial backup."
            replace_flag=true
            check_replace_flag=true
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

# Display replacement status in normal execution
if $check_replace_flag; then
    echo -e "\n$bold$underline Replacement Status:$reset"
    if $replace_flag; then
        echo -e "  $green The file has been replaced.$reset"
    else
        echo -e "  $blue The file has not been replaced.$reset"
    fi
fi
