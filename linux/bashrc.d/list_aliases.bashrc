#!/bin/bash

# Function to list all custom aliases with descriptions
function list_aliases() {
    echo "Custom Aliases:"
    echo "-------------"
    
    # Use alias command and format the output
    alias | grep -v "^alias alias" | sed 's/alias\s//g' | sort | while read line; do
        # Extract alias name and command
        name=$(echo "$line" | cut -d'=' -f1)
        command=$(echo "$line" | cut -d'=' -f2- | sed "s/^'//;s/'$//")
        
        # Print formatted output
        printf "%-15s => %s\n" "$name" "$command"
    done
    
    echo -e "\nFor more details about specific alias, use: type alias_name"
}

# Create the alias
alias lsalias='list_aliases'
