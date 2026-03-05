#!/bin/bash

set -e

DOTFILES_DIR="$(cd "$(dirname "$0")" && pwd)"

# ---------- Output helpers ----------
info()    { echo -e "\033[1;34m[INFO]\033[0m $1"; }
warning() { echo -e "\033[1;33m[WARN]\033[0m $1"; }
error()   { echo -e "\033[1;31m[ERROR]\033[0m $1" >&2; exit 1; }

# ---------- Ask user for distro family ----------
ask_distro() {
    local detected="$1"
    warning "Could not automatically determine distro family for '$detected'."
    echo ""
    echo "Which distro family is this system based on?"
    echo "  1) Arch   (pacman)  — Arch, Manjaro, EndeavourOS, CachyOS, etc."
    echo "  2) Debian (apt)     — Debian, Ubuntu, Mint, Pop!_OS, etc."
    echo "  3) Fedora (dnf)     — Fedora, Nobara, etc."
    echo ""
    while true; do
        read -rp "Enter choice [1-3]: " choice
        case "$choice" in
            1) DISTRO="arch";   return ;;
            2) DISTRO="debian"; return ;;
            3) DISTRO="fedora"; return ;;
            *) echo "Invalid choice. Please enter 1, 2, or 3." ;;
        esac
    done
}

# ---------- Detect distro family ----------
detect_distro() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        case "$ID" in
            ubuntu|debian|linuxmint|pop) DISTRO="debian" ;;
            arch|manjaro|endeavouros)     DISTRO="arch" ;;
            fedora)                       DISTRO="fedora" ;;
            *)
                # Fallback: check ID_LIKE
                case "$ID_LIKE" in
                    *debian*|*ubuntu*) DISTRO="debian" ;;
                    *arch*)            DISTRO="arch" ;;
                    *fedora*|*rhel*)   DISTRO="fedora" ;;
                    *)                 ask_distro "$ID" ;;
                esac
                ;;
        esac
    else
        ask_distro "unknown"
    fi
    info "Detected distro family: $DISTRO"
}

# ---------- System update ----------
update_system() {
    info "Updating system packages..."
    case "$DISTRO" in
        debian) sudo apt update && sudo apt upgrade -y ;;
        arch)   sudo pacman -Syu --noconfirm ;;
        fedora) sudo dnf upgrade -y ;;
    esac
}

# ---------- Package installation ----------
install_pkg() {
    local pkg="$1"
    case "$DISTRO" in
        debian) sudo apt install -y "$pkg" ;;
        arch)   sudo pacman -S --noconfirm --needed "$pkg" ;;
        fedora) sudo dnf install -y "$pkg" ;;
    esac
}

# Some packages have different names across distros.
# Map: logical name -> debian|arch|fedora
# Use "__skip__" to handle a package separately.
declare -A PKG_MAP=(
    [curl]="curl|curl|curl"
    [git]="git|git|git"
    [gcc]="gcc|gcc|gcc"
    [make]="make|make|make"
    [vim]="vim|vim|vim"
    [tmux]="tmux|tmux|tmux"
    [stow]="stow|stow|stow"
    [ripgrep]="ripgrep|ripgrep|ripgrep"
    [fzf]="fzf|fzf|fzf"
    [neovim]="neovim|neovim|neovim"
    [unzip]="unzip|unzip|unzip"
)

resolve_pkg() {
    local key="$1"
    local entry="${PKG_MAP[$key]}"
    if [ -z "$entry" ]; then
        # No mapping; use the key as-is
        echo "$key"
        return
    fi
    case "$DISTRO" in
        debian) echo "$entry" | cut -d'|' -f1 ;;
        arch)   echo "$entry" | cut -d'|' -f2 ;;
        fedora) echo "$entry" | cut -d'|' -f3 ;;
    esac
}

install_dependencies() {
    local deps=(
        curl
        git
        gcc
        make
        vim
        tmux
        stow
        ripgrep
        fzf
        neovim
        unzip
    )

    for dep in "${deps[@]}"; do
        local pkg
        pkg="$(resolve_pkg "$dep")"
        if [ "$pkg" = "__skip__" ]; then
            continue
        fi
        info "Installing $dep ($pkg)..."
        if ! install_pkg "$pkg"; then
            warning "Failed to install $dep — you may need to install it manually."
        fi
    done
}

# ---------- Brave browser ----------
install_brave() {
    if command -v brave-browser >/dev/null 2>&1 || command -v brave >/dev/null 2>&1; then
        info "Brave browser is already installed."
        return
    fi

    info "Installing Brave browser..."
    case "$DISTRO" in
        debian)
            sudo apt install -y curl
            sudo curl -fsSLo /usr/share/keyrings/brave-browser-archive-keyring.gpg \
                https://brave-browser-apt-release.s3.brave.com/brave-browser-archive-keyring.gpg
            echo "deb [signed-by=/usr/share/keyrings/brave-browser-archive-keyring.gpg] \
https://brave-browser-apt-release.s3.brave.com/ stable main" \
                | sudo tee /etc/apt/sources.list.d/brave-browser-release.list >/dev/null
            sudo apt update
            sudo apt install -y brave-browser
            ;;
        arch)
            # brave-bin is in the AUR — needs an AUR helper
            if command -v yay >/dev/null 2>&1; then
                yay -S --noconfirm brave-bin
            elif command -v paru >/dev/null 2>&1; then
                paru -S --noconfirm brave-bin
            else
                warning "No AUR helper found (yay/paru). Install brave-bin manually from the AUR."
            fi
            ;;
        fedora)
            sudo dnf install -y dnf-plugins-core
            sudo dnf config-manager --add-repo \
                https://brave-browser-rpm-release.s3.brave.com/brave-browser.repo
            sudo rpm --import https://brave-browser-rpm-release.s3.brave.com/brave-core.asc
            sudo dnf install -y brave-browser
            ;;
    esac
}

# ---------- TPM (tmux plugin manager) ----------
install_tpm() {
    if [ -d "$HOME/.tmux/plugins/tpm" ]; then
        info "TPM is already installed."
    else
        info "Installing tmux plugin manager (TPM)..."
        git clone https://github.com/tmux-plugins/tpm "$HOME/.tmux/plugins/tpm"
    fi
}

# ---------- Stow dotfiles ----------
stow_packages() {
    info "Symlinking dotfiles with stow..."
    local packages=(git tmux nvim zsh hypr waybar discord)

    for pkg in "${packages[@]}"; do
        if [ -d "$DOTFILES_DIR/$pkg" ]; then
            info "Stowing $pkg..."
            stow -d "$DOTFILES_DIR" -t "$HOME" --restow "$pkg" || \
                warning "Failed to stow $pkg — resolve conflicts manually."
        fi
    done
}

# ---------- Git submodules (nvim config) ----------
init_submodules() {
    info "Initializing git submodules..."
    git -C "$DOTFILES_DIR" submodule update --init --recursive
}

# ---------- Zsh setup ----------
setup_zsh() {
    if [ -x "$DOTFILES_DIR/zsh/install.sh" ]; then
        info "Running zsh setup..."
        bash "$DOTFILES_DIR/zsh/install.sh"
    else
        warning "zsh/install.sh not found or not executable — skipping zsh setup."
    fi
}

# ========== Main ==========
main() {
    info "Installing Nafi's dotfiles..."
    detect_distro
    update_system
    install_dependencies
    install_brave
    install_tpm
    init_submodules
    stow_packages
    setup_zsh
    info "Done! Restart your terminal or run 'exec zsh' to get started."
}

main "$@"
