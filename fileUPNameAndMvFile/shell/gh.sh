#!/bin/bash

# Function to check if number of arguments is correct
check_arguments() {
    if [ $# -lt 2 ]; then
    echo "Usage: $0 <folder> <password1> [password2] [password3] ..."
    exit 1
    fi
}

# Main function
main() {
# Check number of arguments
    check_arguments "$@"
    
# Extract folder path and passwords
    local folder="$1"
    shift
    local passwords=("$@")
    
# Enter the folder and verify the path
    cd "$folder" || exit 1
    echo "Entered folder: $PWD"
    
# Iterate through each password and encrypt files using the corresponding password
    for password in "${passwords[@]}"; do
        echo "Encrypting files with password: $password"
        for name in `ls`; do
            zip -1 -P "$password" "$name.d" "$name" && rm "$name"
            done
            done
            
            echo "Encryption completed."
}

# Call the main function with arguments passed to the script
main "$@"

