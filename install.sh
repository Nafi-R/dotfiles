#!/bin/bash

# Define dotfiles path
dotfiles_path="$PWD"

# Update and upgrade the system
info() {
    echo -e "\033[1;34m$1\033[0m"
}

error() {
    echo -e "\033[1;31m$1\033[0m" >&2
    exit 1
}

warning() {
    echo -e "\033[1;33m$1\033[0m"
}

info "Installing Nafi's dotfiles..."
info "Updating and upgrading the system..."
sudo apt update && sudo apt upgrade -y

dependencies=(
    "software-properties-common"
    "curl"
    "git"
    "gcc"
    "tmux"
    "ripgrep"
    "fzf"
    "vim"
    "make"
)

for dep in "${dependencies[@]}"; do
    info "Installing $dep..."
    (sudo apt install -y "$dep" 2>/dev/null) 
done

# Install Python using pyenv if python3.10 is not available
if ! command -v python3.10 &> /dev/null; then
    echo "Python 3.10 is not available. Installing pyenv..."
    curl https://pyenv.run | bash
    eval "$(pyenv init --path)"
    pyenv install 3.10.7
    pyenv global 3.10.7
    echo "Python 3.10 installed successfully!"
else
    echo "Python 3.10 is already installed."
fi

# Install tmux plugin manager (TPM)
if [ ! -d "$HOME/.tmux/plugins/tpm" ]; then
    git clone https://github.com/tmux-plugins/tpm "$HOME/.tmux/plugins/tpm"
fi

# Backup existing files before creating symbolic links
CONFIG_FILES=(
    ".tmux.conf"
    ".gitconfig"
)

for file in "${CONFIG_FILES[@]}"; do
    if [ -f "$HOME/$file" ]; then
        mv "$HOME/$file" "$HOME/$file.bak"
        info "Backed up $file to $file.bak"
    fi  
    if [ ! -L "$HOME/$file" ]; then
        ln -s "$dotfiles_path/$file" "$HOME/$file"
        info "Created symbolic link for $file"
    else
        info "Symbolic link for $file already exists, skipping..."
    fi
done

# Install Neovim
if ! command -v nvim &> /dev/null; then
    echo "Neovim is not installed. Installing Neovim..."
    curl -LO https://github.com/neovim/neovim/releases/download/v0.11.2/nvim-linux-x86_64.tar.gz
    sudo rm -rf /opt/nvim
    sudo tar -C /opt -xzf nvim-linux-x86_64.tar.gz
    /opt/nvim-linux-x86_64/bin/nvim --version
else
    warning "Neovim is already installed."
fi

# Create configuration directory if it doesn't exist
if [ ! -d "$HOME/.config" ]; then
    info "Creating configuration directory..."
    mkdir -p "$HOME/.config"
fi

# Create symbolic link for Neovim configuration
if [ ! -L "$HOME/.config/nvim" ]; then
    git clone https://github.com/Nafi-R/nafi.nvim.git "$HOME/.config/nvim"
    info "Neovim configuration added to $HOME/.config/nvim"
else
    warning "Neovim configuration already exists, skipping..."
fi
