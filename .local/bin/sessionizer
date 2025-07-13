#!/usr/bin/env bash

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
tmux_running=$(pgrep tmux)

if [[ -z $TMUX ]] && [[ -z $tmux_running ]]; then
    tmux new-session -s $selected_name -c $selected
    exit 0
fi

if ! tmux has-session -t=$selected_name 2> /dev/null; then
    tmux new-session -ds $selected_name -c $selected
fi

if [[ -z $TMUX ]]; then
    tmux attach -t $selected_name
else
    tmux switch-client -t $selected_name
fi