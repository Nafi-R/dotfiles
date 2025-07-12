export ZSH="$HOME/.oh-my-zsh"
ZSH_THEME="robbyrussell"

plugins=(git)

source $ZSH/oh-my-zsh.sh
dotfiles_path="$HOME/dotfiles"

export PATH=dotfiles_path/.local/bin:$PATH
export PATH=/opt/nvim-linux-x86_64/bin:$PATH