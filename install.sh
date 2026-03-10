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

install_aur_pkg() {
    local pkg="$1"
    if command -v yay >/dev/null 2>&1; then
        yay -S --noconfirm "$pkg"
    elif command -v paru >/dev/null 2>&1; then
        paru -S --noconfirm "$pkg"
    else
        warning "No AUR helper found (yay/paru). Install '$pkg' manually from the AUR."
        return 1
    fi
}

# ---------- Package name mapping ----------
# Map: logical name -> debian|arch|fedora
# Use "__skip__" when a package is not available for that distro.
declare -A PKG_MAP=(
    # Build essentials & CLI tools
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
    [jq]="jq|jq|jq"

    # Hyprland ecosystem
    [hyprland]="hyprland|hyprland|hyprland"
    [hyprlock]="hyprlock|hyprlock|hyprlock"
    [hypridle]="hypridle|hypridle|hypridle"
    [hyprpicker]="hyprpicker|hyprpicker|hyprpicker"
    [xdg-desktop-portal-hyprland]="xdg-desktop-portal-hyprland|xdg-desktop-portal-hyprland|xdg-desktop-portal-hyprland"
    [hyprsunset]="__skip__|hyprsunset|__skip__"

    # Desktop environment
    [waybar]="waybar|waybar|waybar"
    [swww]="__skip__|swww|__skip__"
    [mako]="mako-notifier|mako|mako"
    [swaync]="__skip__|swaync|SwayNotificationCenter"
    [swayosd]="swayosd|swayosd|__skip__"
    [uwsm]="uwsm|uwsm|__skip__"
    [polkit-gnome]="policykit-1-gnome|polkit-gnome|polkit-gnome"
    [fcitx5]="fcitx5|fcitx5|fcitx5"

    # Wayland utilities
    [grim]="grim|grim|grim"
    [slurp]="slurp|slurp|slurp"
    [wl-clipboard]="wl-clipboard|wl-clipboard|wl-clipboard"
    [satty]="__skip__|satty|__skip__"

    # System utilities
    [brightnessctl]="brightnessctl|brightnessctl|brightnessctl"
    [upower]="upower|upower|upower"
    [playerctl]="playerctl|playerctl|playerctl"
    [pamixer]="pamixer|pamixer|pamixer"
    [libnotify]="libnotify-bin|libnotify|libnotify"
    [v4l-utils]="v4l-utils|v4l-utils|v4l-utils"
    [ffmpeg]="ffmpeg|ffmpeg|ffmpeg"
    [btop]="btop|btop|btop"
    [gum]="__skip__|gum|gum"
    [libxkbcommon]="libxkbcommon-dev|libxkbcommon|libxkbcommon"

    # Desktop apps
    [nautilus]="nautilus|nautilus|nautilus"
    [gnome-calculator]="gnome-calculator|gnome-calculator|gnome-calculator"

    # Terminal emulator
    [ghostty]="__skip__|ghostty|__skip__"

    # Screen recording
    [gpu-screen-recorder]="__skip__|gpu-screen-recorder|__skip__"

    # TUI apps (Arch-only)
    [lazydocker]="__skip__|lazydocker|__skip__"
    [impala]="__skip__|impala|__skip__"
    [bluetui]="__skip__|bluetui|__skip__"
    [wiremix]="__skip__|wiremix|__skip__"
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

# ---------- Install standard packages ----------
install_dependencies() {
    info "Installing standard dependencies..."
    local deps=(
        # Build essentials & CLI tools
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
        jq

        # Hyprland ecosystem
        hyprland
        hyprlock
        hypridle
        hyprpicker
        xdg-desktop-portal-hyprland
        hyprsunset

        # Desktop environment
        waybar
        swww
        mako
        swaync
        swayosd
        uwsm
        polkit-gnome
        fcitx5

        # Wayland utilities
        grim
        slurp
        wl-clipboard
        satty

        # System utilities
        brightnessctl
        upower
        playerctl
        pamixer
        libnotify
        v4l-utils
        ffmpeg
        btop
        gum
        libxkbcommon

        # Desktop apps
        nautilus
        gnome-calculator

        # Terminal emulator
        ghostty

        # Screen recording
        gpu-screen-recorder

        # TUI apps
        lazydocker
        impala
        bluetui
        wiremix
    )

    local skipped=()

    for dep in "${deps[@]}"; do
        local pkg
        pkg="$(resolve_pkg "$dep")"
        if [ "$pkg" = "__skip__" ]; then
            skipped+=("$dep")
            continue
        fi
        info "Installing $dep ($pkg)..."
        if ! install_pkg "$pkg"; then
            warning "Failed to install $dep — you may need to install it manually."
        fi
    done

    if [ ${#skipped[@]} -gt 0 ]; then
        echo ""
        warning "The following packages are not available in official $DISTRO repos:"
        for s in "${skipped[@]}"; do
            echo "  - $s"
        done
        echo ""
        info "You may need to install them manually (e.g. from source, Flatpak, or a third-party repo)."
    fi
}

# ---------- AUR-only packages (Arch) ----------
install_aur_packages() {
    if [ "$DISTRO" != "arch" ]; then
        return
    fi

    info "Installing AUR packages..."
    local aur_deps=(
        walker
        elephant
        opencode
        voxtype
        xdg-terminal-exec
        hyprland-preview-share-picker-git
    )

    for dep in "${aur_deps[@]}"; do
        info "Installing $dep from AUR..."
        if ! install_aur_pkg "$dep"; then
            warning "Failed to install $dep from AUR."
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
            install_aur_pkg brave-bin
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
    local packages=(git tmux nvim zsh hypr waybar ghostty nafi discord)

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

# ---------- Summary of manual installs needed ----------
print_manual_install_summary() {
    if [ "$DISTRO" = "arch" ]; then
        return
    fi

    echo ""
    info "=== Manual installation needed ==="
    echo ""
    echo "The following tools are not in official $DISTRO repos and must be installed manually:"
    echo ""
    echo "  Required:"
    echo "    - walker           (app launcher)        https://github.com/abenz1267/walker"
    echo "    - elephant         (walker plugin)       https://github.com/abenz1267/elephant"
    echo "    - opencode         (AI coding tool)      https://opencode.ai"
    echo "    - xdg-terminal-exec                      https://github.com/Vladimir-csp/xdg-terminal-exec"
    echo ""
    echo "  Optional:"
    echo "    - voxtype          (dictation)           https://github.com/meli-iern/voxtype"
    echo "    - hyprland-preview-share-picker          https://github.com/mightymeld/hyprland-preview-share-picker"

    if [ "$DISTRO" = "debian" ]; then
        echo ""
        echo "  Debian-specific missing packages (may need backports, Flatpak, or build from source):"
        echo "    - swww             (wallpaper daemon)    https://github.com/LGFae/swww"
        echo "    - swaync           (notification center) https://github.com/ErikReider/SwayNotificationCenter"
        echo "    - hyprsunset       (color temperature)   https://github.com/hyprwm/hyprsunset"
        echo "    - satty            (screenshot editor)   https://github.com/gabm/Satty"
        echo "    - ghostty          (terminal emulator)   https://ghostty.org"
        echo "    - gpu-screen-recorder                    https://github.com/dec05eba/gpu-screen-recorder"
        echo "    - gum              (TUI tool)            https://github.com/charmbracelet/gum"
        echo "    - lazydocker       (Docker TUI)          https://github.com/jesseduffield/lazydocker"
        echo "    - impala           (WiFi TUI)            https://github.com/pythops/impala"
        echo "    - bluetui          (Bluetooth TUI)       https://github.com/pythops/bluetui"
        echo "    - wiremix          (audio mixer TUI)     https://github.com/mablin7/wiremix"
    fi

    if [ "$DISTRO" = "fedora" ]; then
        echo ""
        echo "  Fedora-specific missing packages (may need COPR or build from source):"
        echo "    - swww             (wallpaper daemon)    https://github.com/LGFae/swww"
        echo "    - swayosd          (on-screen display)   https://github.com/ErikReider/SwayOSD"
        echo "    - uwsm             (session manager)     https://github.com/Vladimir-csp/uwsm"
        echo "    - hyprsunset       (color temperature)   https://github.com/hyprwm/hyprsunset"
        echo "    - satty            (screenshot editor)   https://github.com/gabm/Satty"
        echo "    - ghostty          (terminal emulator)   https://ghostty.org"
        echo "    - gpu-screen-recorder                    https://github.com/dec05eba/gpu-screen-recorder"
        echo "    - lazydocker       (Docker TUI)          https://github.com/jesseduffield/lazydocker"
        echo "    - impala           (WiFi TUI)            https://github.com/pythops/impala"
        echo "    - bluetui          (Bluetooth TUI)       https://github.com/pythops/bluetui"
        echo "    - wiremix          (audio mixer TUI)     https://github.com/mablin7/wiremix"
    fi

    echo ""
}

# ========== Main ==========
main() {
    info "Installing Nafi's dotfiles..."
    detect_distro
    update_system
    install_dependencies
    install_aur_packages
    install_brave
    install_tpm
    init_submodules
    setup_zsh
    stow_packages
    print_manual_install_summary
    info "Done! Restart your terminal or run 'exec zsh' to get started."
}

main "$@"
