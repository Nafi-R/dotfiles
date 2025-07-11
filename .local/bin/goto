#!/usr/bin/env bash

# This script is used to navigate to a directory using fzf but not with tmux unlike sessionizer.

parent_dirs=(
    "${HOME}/Nafi/Work"
)

child_dirs=(
    "${HOME}/.config/tmux"
    "${HOME}/.config/nvim"
)

if [[ $# -eq 1 ]]; then
    selected=$1
else
    parent_dir_results=$(find $parent_dirs -mindepth 1 -maxdepth 1 -type d 2>/dev/null)
    child_dir_results=$(find $child_dirs -mindepth 0 -maxdepth 0 -type d 2>/dev/null)
    selected=$(printf "%s\n%s" "$parent_dir_results" "$child_dir_results" | fzf)
fi

if [[ -z $selected ]]; then
    exit 0
fi

selected_name=$(basename "$selected" | tr . _)
if [[ -d $selected ]]; then
    cd "$selected" || exit
else
    echo "Selected path is not a directory."
    exit 1
fi