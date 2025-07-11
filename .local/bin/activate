#!/usr/bin/env bash

# Find all Python virtual environments in the current directory (recursively)
venvs=$(rg --files --glob '*/bin/activate' --no-messages)

if [[ -z "$venvs" ]]; then
    echo "No Python virtual environments found in the current directory."
    exit 1
fi

# Use fzf to select a virtual environment
selected=$(echo "$venvs" | fzf --prompt="Select a virtualenv to activate: ")

if [[ -z "$selected" ]]; then
    echo "No virtual environment selected."
    exit 1
fi

# Activate the selected virtual environment
# shellcheck source=/dev/null
source "$selected"