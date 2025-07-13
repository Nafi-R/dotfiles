#!/bin/bash

set -e  # Exit on any error

# Function to print messages
info() {
  echo -e "\033[1;34m[INFO]\033[0m $1"
}

error() {
  echo -e "\033[1;31m[ERROR]\033[0m $1" >&2
  exit 1
}

# Detect OS and install zsh
install_zsh() {
  if command -v zsh >/dev/null 2>&1; then
    info "Zsh is already installed."
    return
  fi

  info "Installing zsh..."

  if command -v apt >/dev/null 2>&1; then
    sudo apt update && sudo apt install -y zsh
  elif command -v dnf >/dev/null 2>&1; then
    sudo dnf install -y zsh
  elif command -v yum >/dev/null 2>&1; then
    sudo yum install -y zsh
  elif command -v pacman >/dev/null 2>&1; then
    sudo pacman -Sy --noconfirm zsh
  elif command -v brew >/dev/null 2>&1; then
    brew install zsh
  else
    error "Unsupported package manager. Please install zsh manually."
  fi
}

# Install oh-my-zsh
install_oh_my_zsh() {
  if [ -d "$HOME/.oh-my-zsh" ]; then
    info "Oh My Zsh is already installed."
  else
    info "Installing Oh My Zsh..."
    export RUNZSH=no  # prevent auto-switch
    export CHSH=no    # we'll set shell ourselves
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
  fi
}

# Change default shell to zsh
set_zsh_default() {
  ZSH_PATH="$(command -v zsh)"
  if [ "$SHELL" != "$ZSH_PATH" ]; then
    info "Setting Zsh as your default shell..."
    chsh -s "$ZSH_PATH"
    info "Default shell set to: $ZSH_PATH"
  else
    info "Zsh is already your default shell."
  fi
}

# Run everything
install_zsh
install_oh_my_zsh
set_zsh_default

CONFIG_FILES=(
    ".zshrc"
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

info "All done! Restart your terminal to use Zsh."
