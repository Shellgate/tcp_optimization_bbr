#!/bin/bash

# Define project variables
project_name="Advanced TCP Optimization PCC"
backup_and_destination_path="/etc/sysctl.conf"
new_file_url="https://raw.githubusercontent.com/Shellgate/pcc-tcp-optimizer/main/sysctl.conf"

# Display header and subheader
echo -e "=== $project_name ==="
echo -e ":: System Report ::\n"

# Set formatting colors
bold=$(tput bold)
underline=$(tput sgr 0 1)
reset=$(tput sgr0)
green=$(tput setaf 2)
blue=$(tput setaf 4)

# Flags for replacement and checking
replace_flag=false
check_replace_flag=false

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
            
            # Download new file
            echo "Downloading the new file..."
            wget "$new_file_url" -O "$backup_and_destination_path"
            
            # Display success message
            echo "File successfully replaced, and a backup has been created."
            replace_flag=true
            break
            ;;
        2)
            # Option 2: Restore Initial Backup
            cp "$backup_and_destination_path.bak" "$backup_and_destination_path"
            echo "File successfully restored from the initial backup."
            replace_flag=true
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
    echo -e "\nReplacement Status:"
    if $replace_flag; then
        echo "  The file has been replaced."
    else
        echo "  The file has not been replaced."
    fi
fi
