export ZSH="$HOME/.oh-my-zsh"
ZSH_THEME="robbyrussell"

plugins=(git)

source $ZSH/oh-my-zsh.sh
dotfiles_path="$HOME/dotfiles"

parent_dirs=(
    "${HOME}/Repos"
)

child_dirs=(
    "${HOME}/.config/tmux"
    "${HOME}/.config/nvim"
)

export PARENT_WORKSPACES=$(find "${parent_dirs[@]}" -mindepth 1 -maxdepth 1 -type d 2>/dev/null)
export CHILD_WORKSPACES=$(find "${child_dirs[@]}" -mindepth 0 -maxdepth 0 -type d 2>/dev/null)

export PATH="$HOME/.local/bin:$PATH"
export PATH="/opt/nvim-linux-x86_64/bin:$PATH"
export PATH="$HOME/.pyenv/bin:$PATH"

# Python stuff
export PYENV_ROOT="$HOME/.pyenv"
[[ -d $PYENV_ROOT/bin ]] && export PATH="$PYENV_ROOT/bin:$PATH"
eval "$(pyenv init - zsh)"