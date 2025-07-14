export ZSH="$HOME/.oh-my-zsh"
ZSH_THEME="robbyrussell"

plugins=(git)

source $ZSH/oh-my-zsh.sh
dotfiles_path="$HOME/dotfiles"

source "${HOME}/.config/nafi/utils"
export PATH="/opt/nvim-linux-x86_64/bin:$PATH"
export PATH="$HOME/.pyenv/bin:$PATH"
