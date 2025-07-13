#!/bin/bash

# Define dotfiles path
dotfiles_path="$PWD"

# Update and upgrade the system
sudo apt update && sudo apt upgrade -y

# Install necessary dependencies
sudo apt install -y software-properties-common curl git gcc zsh tmux ripgrep fzf vim

# Install Python using pyenv if python3.10 is not available
if ! command -v python3.10 &> /dev/null; then
    echo "Python 3.10 is not available. Installing pyenv..."
    curl https://pyenv.run | bash
    export PATH="$HOME/.pyenv/bin:$PATH"
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
    ".zshrc"
    ".tmux.conf"
    ".gitconfig"
)

for file in "${CONFIG_FILES[@]}"; do
    if [ -f "$HOME/$file" ]; then
        mv "$HOME/$file" "$HOME/$file.bak"
        echo "Backed up $file to $file.bak"
    fi  
    if [ ! -L "$HOME/$file" ]; then
        ln -s "$dotfiles_path/$file" "$HOME/$file"
        echo "Created symbolic link for $file"
    else
        echo "Symbolic link for $file already exists, skipping..."
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
    echo "Neovim is already installed."
fi

git submodule update --init --recursive
# Create configuration directory if it doesn't exist
if [ ! -d "$HOME/.config" ]; then
    echo "Creating configuration directory..."
    mkdir -p "$HOME/.config"
fi

# Create symbolic link for Neovim configuration
if [ ! -L "$HOME/.config/nvim" ]; then
    ln -s "$dotfiles_path/.config/nvim" "$HOME/.config/nvim"
    echo "Neovim configuration linked successfully!"
else
    echo "Neovim configuration already exists, skipping..."
fi

# chmod +x for all scripts in .local/bin
if [ -d "$dotfiles_path/.local/bin" ]; then
    echo "Making scripts in .local/bin executable..."
    find "$dotfiles_path/.local/bin" -type f -name "*.sh" -exec chmod +x {} \;
    echo "Scripts in .local/bin are now executable."
else
    echo ".local/bin directory does not exist, skipping chmod."
fi

# Source Zsh configuration
if [ "$SHELL" == "$(which zsh)" ]; then
    source "$HOME/.zshrc"
else
    echo "Please switch to Zsh and run 'source ~/.zshrc' manually."
fi