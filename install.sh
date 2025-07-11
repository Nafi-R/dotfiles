#!/bin/bash

# Update and upgrade the system
sudo apt install software-properties-common
sudo add-apt-repository ppa:deadsnakes/ppa -y
sudo apt update && sudo apt upgrade -y

# Install packages
PACKAGES=(
    gcc
    git
    curl
    zsh
    tmux
    ripgrep
    fzf
    vim
    python3.10
    python3.10-venv
    python3.10-dev
)

echo "Installing packages..."
for package in "${PACKAGES[@]}"; do
    sudo apt install -y "$package"
done

echo "Packages installed successfully!"

# Install tmux plugin manager (TPM)
if [ ! -d "$HOME/.tmux/plugins/tpm" ]; then
    git clone https://github.com/tmux-plugins/tpm "$HOME/.tmux/plugins/tpm"
fi

# Set Zsh as the default shell
if [ "$SHELL" != "$(which zsh)" ]; then
    echo "Changing default shell to Zsh..."
    chsh -s "$(which zsh)"
    echo "Default shell changed to Zsh. Please log out and log back in for changes to take effect."
else
    echo "Zsh is already the default shell."
fi

# Install Oh My Zsh
if [ ! -d "$HOME/.oh-my-zsh" ]; then
    echo "Installing Oh My Zsh..."
    # Install dependencies for Oh My Zsh
    sudo apt install -y zsh-syntax-highlighting zsh-autosuggestions
    # Install Oh My Zsh
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
    echo "Oh My Zsh installed successfully!"
else
    echo "Oh My Zsh is already installed."
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
        ln -s "$PWD/$file" "$HOME/$file"
        echo "Created symbolic link for $file"
    else
        echo "Symbolic link for $file already exists, skipping..."
    fi
done
# Install Neovim
if ! command -v nvim &> /dev/null; then
    curl -LO https://github.com/neovim/neovim/releases/download/v0.11.2/nvim-linux-x86_64.tar.gz
    sudo rm -rf /opt/nvim
    sudo tar -C /opt -xzf nvim-linux-x86_64.tar.gz
    /opt/nvim/bin/nvim --version
else
    echo "Neovim is already installed."
fi

if [ ! -d "$HOME/.config" ]; then
    echo "Creating configuration directory..."
    mkdir -p "$HOME/.config"
fi

# Create symbolic link for Neovim configuration
if [ ! -d "$HOME/.config/nvim" ]; then
    echo "Creating symbolic link for Neovim configuration..."
    mkdir -p "$HOME/.config"
    ln -s "$PWD/.config/nvim" "$HOME/.config/nvim"
    echo "Neovim configuration linked successfully!"
else
    echo "Neovim configuration already exists, skipping..."
fi

# chmod +x for all scripts in .local/bin
if [ -d "$PWD/.local/bin" ]; then
    echo "Making scripts in .local/bin executable..."
    find "$PWD/.local/bin" -type f -name "*.sh" -exec chmod +x {} \;
    echo "Scripts in .local/bin are now executable."
else
    echo ".local/bin directory does not exist, skipping chmod."
fi
