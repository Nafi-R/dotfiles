#!/bin/bash

# Update and upgrade the system
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
)

echo "Installing packages..."
for package in "${PACKAGES[@]}"; do
    sudo apt install -y "$package"
done

echo "Packages installed successfully!"

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
# Set Zsh as the default shell
if [ "$SHELL" != "$(which zsh)" ]; then
    echo "Changing default shell to Zsh..."
    chsh -s "$(which zsh)"
    echo "Default shell changed to Zsh. Please log out and log back in for changes
    to take effect."
else
    echo "Zsh is already the default shell."
fi

# Install neovim
if ! command -v nvim &> /dev/null; then
    echo "Installing Neovim..."
    sudo apt install -y neovim
    echo "Neovim installed successfully!"
else
    echo "Neovim is already installed."
fi

# Make symboilic links for configuration files
CONFIG_FILES=(
    ".zshrc"
    ".tmux.conf"
)

echo "Creating symbolic links for configuration files..."
for file in "${CONFIG_FILES[@]}"; do
    if [ -f "$HOME/$file" ]; then
        echo "File $file already exists, skipping..."
    else
        ln -s "$PWD/$file" "$HOME/$file"
        echo "Created symbolic link for $file"
    fi
done
echo "Symbolic links created successfully!"

# Create symbolic link for Neovim configuration
if [ ! -d "$HOME/.config/nvim" ]; then
    echo "Creating symbolic link for Neovim configuration..."
    mkdir -p "$HOME/.config"
    ln -s "$PWD/nvim" "$HOME/.config/nvim"
    echo "Neovim configuration linked successfully!"
else
    echo "Neovim configuration already exists, skipping..."
fi

# Create symbolic link for tmux configuration
if [ ! -d "$HOME/.config/tmux" ]; then
    echo "Creating symbolic link for tmux configuration..."
    mkdir -p "$HOME/.config"
    ln -s "$PWD/tmux" "$HOME/.config/tmux"
    echo "Tmux configuration linked successfully!"
else
    echo "Tmux configuration already exists, skipping..."
fi

# Add all my .local/bin/<scripts> to PATH
if ! grep -q ".local/bin" "$HOME/.zshrc"; then
    echo "Adding .local/bin to PATH in .zshrc..."
    echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$HOME/.zshrc"
    echo ".local/bin added to PATH in .zshrc."
else
    echo ".local/bin is already in PATH in .zshrc."
fi

# chmod +x for all scripts in .local/bin
if [ -d "$HOME/.local/bin" ]; then
    echo "Making scripts in .local/bin executable..."
    find "$HOME/.local/bin" -type f -name "*.sh" -exec chmod+x {} \;
    echo "Scripts in .local/bin are now executable."
else
    echo ".local/bin directory does not exist, skipping chmod."
fi
