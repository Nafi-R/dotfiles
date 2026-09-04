#!/usr/bin/env bash
#
# Nafi's dotfiles installer
# -------------------------
# A modular, per-app dotfiles installer.
#
# Layout (one app = one line in the registry below):
#   config/           -> ~/.config     (hypr, waybar, ghostty, nvim, ...)
#   home/             -> ~             (git/.gitconfig, tmux/.tmux.conf, zsh/.zshrc)
#   local/            -> ~/.local     (local/share/nafi -> ~/.local/share/nafi)
#   system/           -> /            (sddm theme, needs sudo)
#
# Every file lives under a VISIBLE folder (config/, home/, local/, system/),
# so the repo is no longer a sea of hidden ".config"/".local" dirs. Each app
# is still symbolically linked into place, and you choose per machine which
# apps get linked (interactive checklist, CLI args, or a saved profile).
#
# Usage:
#   ./install.sh                  interactive checklist + link + setup
#   ./install.sh --all            link/setup every app
#   ./install.sh hypr waybar      link just those apps (non-interactive)
#   ./install.sh --deps hypr      also install distro packages for hypr
#   ./install.sh --list           list available apps and exit
#   ./install.sh --edit           force the interactive editor
#   ./install.sh --no-deps        never install packages
#
# Interactive checklist: when `gum` is installed (it's already a dependency of
# the `hypr` app) you get a real checkbox menu -- arrow keys to move, SPACE to
# tick/untick apps, type to filter, ENTER to continue. A plain numbered toggle
# menu is used automatically as a fallback when gum isn't available.
set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "$0")" && pwd)"

# ---------------------------------------------------------------------------
# Output helpers
# ---------------------------------------------------------------------------
info()    { echo -e "\033[1;34m[INFO]\033[0m  $*"; }
warning() { echo -e "\033[1;33m[WARN]\033[0m  $*"; }
error()   { echo -e "\033[1;31m[ERROR]\033[0m $*" >&2; exit 1; }

# ---------------------------------------------------------------------------
# Registry: every app this repo knows about
# ---------------------------------------------------------------------------
# APP_LINKS format: "<repo-src>|<target-path>" (repeat, space-separated).
#   * repo-src   -> path relative to $DOTFILES_DIR
#   * target-path-> path relative to $HOME, or absolute (e.g. /usr/...)
# The installer symlinks  <repo>/<src>  ->  <target>  with ln -sfn.

declare -A APP_DESC
declare -A APP_LINKS
declare -A APP_DEPS   # logical package names, resolved via PKG_MAP

register_app() {
  local name="$1" desc="$2" links="$3" deps="$4"
  APP_DESC[$name]="$desc"
  APP_LINKS[$name]="$links"
  APP_DEPS[$name]="$deps"
}

register_app git      "Git configuration"                  "home/git/.gitconfig|.gitconfig"                       "git"
register_app tmux     "Tmux configuration"                 "home/tmux/.tmux.conf|.tmux.conf"                      "tmux"
register_app zsh      "Zsh shell + nafi helpers"           "home/zsh/.zshrc|.zshrc config/nafi|.config/nafi"     "zsh"
register_app nvim     "Neovim config (submodule)"          "config/nvim|.config/nvim"                            "curl git make gcc neovim ripgrep fzf unzip jq"
register_app hypr     "Hyprland window manager ecosystem"  "config/hypr|.config/hypr"                            "hyprland hyprlock hypridle hyprpicker xdg-desktop-portal-hyprland hyprsunset swww swayosd uwsm polkit-gnome fcitx5 grim slurp wl-clipboard satty brightnessctl upower playerctl pamixer libnotify libxkbcommon gum"
register_app waybar   "Waybar bar"                         "config/waybar|.config/waybar"                        "waybar"
register_app ghostty  "Ghostty terminal"                   "config/ghostty|.config/ghostty"                      "ghostty"
register_app rofi     "Rofi launcher"                      "config/rofi|.config/rofi"                            "rofi"
register_app swaync   "Sway notification center"           "config/swaync|.config/swaync"                        "swaync"
register_app discord  "Discord settings"                   "config/discord|.config/discord"                      "discord"
register_app noctalia "Noctalia shell/desktop config"      "config/noctalia|.config/noctalia"                  ""
register_app nafi     "Nafi CLI helper scripts"            "local/share/nafi|.local/share/nafi"                  "playerctl pamixer brightnessctl upower libnotify grim slurp wl-clipboard"
register_app sddm     "SDDM login theme (system-wide)"     "system/sddm/usr/share/sddm/themes/nafi|/usr/share/sddm/themes/nafi" "sddm"

# Stable, human-friendly ordering for prompts
ALL_APPS=(git tmux zsh nvim hypr waybar ghostty rofi swaync discord noctalia nafi sddm)

# ---------------------------------------------------------------------------
# Distro detection + package resolution
# ---------------------------------------------------------------------------
DISTRO=""

ask_distro() {
  local detected="$1"
  warning "Could not automatically determine distro family for '$detected'."
  echo "Which distro family is this system based on?"
  echo "  1) Arch   (pacman)  — Arch, Manjaro, EndeavourOS, CachyOS, etc."
  echo "  2) Debian (apt)     — Debian, Ubuntu, Mint, Pop!_OS, etc."
  echo "  3) Fedora (dnf)     — Fedora, Nobara, etc."
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

detect_distro() {
  [ -f /etc/os-release ] || { ask_distro "unknown"; return; }
  . /etc/os-release
  case "$ID" in
    ubuntu|debian|linuxmint|pop) DISTRO="debian" ;;
    arch|manjaro|endeavouros)     DISTRO="arch" ;;
    fedora)                       DISTRO="fedora" ;;
    *)
      case "$ID_LIKE" in
        *debian*|*ubuntu*) DISTRO="debian" ;;
        *arch*)            DISTRO="arch" ;;
        *fedora*|*rhel*)   DISTRO="fedora" ;;
        *)                 ask_distro "$ID" ;;
      esac
      ;;
  esac
  info "Detected distro family: $DISTRO"
}

# Package name mapping: logical name -> debian|arch|fedora ("__skip__" = n/a)
declare -A PKG_MAP=(
    [curl]="curl|curl|curl"        [git]="git|git|git"
    [gcc]="gcc|gcc|gcc"            [make]="make|make|make"
    [vim]="vim|vim|vim"            [tmux]="tmux|tmux|tmux"
    [stow]="stow|stow|stow"        [ripgrep]="ripgrep|ripgrep|ripgrep"
    [fzf]="fzf|fzf|fzf"            [neovim]="neovim|neovim|neovim"
    [unzip]="unzip|unzip|unzip"    [jq]="jq|jq|jq"
    [zsh]="zsh|zsh|zsh"            [rofi]="rofi|rofi|rofi"

    [hyprland]="hyprland|hyprland|hyprland"
    [hyprlock]="hyprlock|hyprlock|hyprlock"
    [hypridle]="hypridle|hypridle|hypridle"
    [hyprpicker]="hyprpicker|hyprpicker|hyprpicker"
    [xdg-desktop-portal-hyprland]="xdg-desktop-portal-hyprland|xdg-desktop-portal-hyprland|xdg-desktop-portal-hyprland"
    [hyprsunset]="__skip__|hyprsunset|__skip__"

    [waybar]="waybar|waybar|waybar"
    [swww]="__skip__|swww|__skip__"
    [mako]="mako-notifier|mako|mako"
    [swaync]="__skip__|swaync|SwayNotificationCenter"
    [swayosd]="swayosd|swayosd|__skip__"
    [uwsm]="uwsm|uwsm|__skip__"
    [polkit-gnome]="policykit-1-gnome|polkit-gnome|polkit-gnome"
    [fcitx5]="fcitx5|fcitx5|fcitx5"

    [grim]="grim|grim|grim"        [slurp]="slurp|slurp|slurp"
    [wl-clipboard]="wl-clipboard|wl-clipboard|wl-clipboard"
    [satty]="__skip__|satty|__skip__"

    [brightnessctl]="brightnessctl|brightnessctl|brightnessctl"
    [upower]="upower|upower|upower"  [playerctl]="playerctl|playerctl|playerctl"
    [pamixer]="pamixer|pamixer|pamixer"
    [libnotify]="libnotify-bin|libnotify|libnotify"
    [libxkbcommon]="libxkbcommon-dev|libxkbcommon|libxkbcommon"
    [gum]="__skip__|gum|gum"
    [ffmpeg]="ffmpeg|ffmpeg|ffmpeg" [btop]="btop|btop|btop"

    [nautilus]="nautilus|nautilus|nautilus"
    [gnome-calculator]="gnome-calculator|gnome-calculator|gnome-calculator"
    [ghostty]="__skip__|ghostty|__skip__"
    [gpu-screen-recorder]="__skip__|gpu-screen-recorder|__skip__"
    [discord]="discord|discord|discord"
    [sddm]="sddm|sddm|sddm"

    [lazydocker]="__skip__|lazydocker|__skip__"
    [impala]="__skip__|impala|__skip__"
    [bluetui]="__skip__|bluetui|__skip__"
    [wiremix]="__skip__|wiremix|__skip__"
)

resolve_pkg() {
  local key="$1" entry="${PKG_MAP[$key]:-}"
  if [ -n "$entry" ]; then
    case "$DISTRO" in
      debian) echo "$entry" | cut -d'|' -f1 ;;
      arch)   echo "$entry" | cut -d'|' -f2 ;;
      fedora) echo "$entry" | cut -d'|' -f3 ;;
    esac
    return
  fi
  echo "$key"
}

install_pkg() {
  local pkg="$1"
  case "$DISTRO" in
    debian) sudo apt install -y "$pkg" ;;
    arch)   sudo pacman -S --noconfirm --needed "$pkg" ;;
    fedora) sudo dnf install -y "$pkg" ;;
  esac
}

# ---------------------------------------------------------------------------
# Per-machine selection
# ---------------------------------------------------------------------------
PROFILE_DIR="$DOTFILES_DIR/profiles"
PROFILE_FILE="$PROFILE_DIR/$(hostname)"
SELECTED_APPS=()

usage() { sed -n '4,18p' "$0"; exit "${1:-0}"; }

list_apps() {
  echo "Available apps:"
  for a in "${ALL_APPS[@]}"; do
    printf '  %-10s %s\n' "$a" "${APP_DESC[$a]}"
  done
}

load_profile() {
  [ -f "$PROFILE_FILE" ] || return 1
  local line
  while IFS= read -r line; do
    [ -n "$line" ] && SELECTED_APPS+=("$line")
  done < "$PROFILE_FILE"
  return 0
}

save_profile() {
  mkdir -p "$PROFILE_DIR"
  : > "$PROFILE_FILE"
  local a
  for a in "${SELECTED_APPS[@]}"; do echo "$a"; done > "$PROFILE_FILE"
  info "Saved machine profile for '$(hostname)' -> profiles/$(hostname)"
}

normalize_apps() {
  local app out=()
  for app in "$@"; do
    case " ${ALL_APPS[*]} " in
      *" $app "*) out+=("$app") ;;
      *) warning "Unknown app '$app' — ignoring (see --list)." ;;
    esac
  done
  SELECTED_APPS=("${out[@]}")
}

toggle() {
  local -n _arr="$1"; local val="$2" i
  for i in "${!_arr[@]}"; do
    [ "${_arr[$i]}" = "$val" ] && { unset "_arr[$i]"; local -a tmp=("${_arr[@]}"); _arr=("${tmp[@]}"); return; }
  done
  _arr+=("$val")
}

# True if the interactive gum UI is usable (installed + running on a TTY).
use_gum() {
  command -v gum >/dev/null 2>&1 && [ -t 0 ] && [ -t 1 ]
}

# gum is *never* required: the installer has a dependency-free numbered fallback
# (pure bash + coreutils). On a brand-new machine where gum hasn't been installed
# yet, optionally offer to install the single `gum` binary via the detected
# package manager -- declining or a failed install just falls back to the plain
# menu, so the script always works with nothing extra preinstalled.
bootstrap_gum() {
  use_gum && return 0
  # Only offer interactively and when we can map to a package manager.
  { [ -t 0 ] && [ -t 1 ]; } || return 0
  case "$DISTRO" in arch|debian|fedora) ;; *) return 0 ;; esac
  local ans
  echo
  read -rp "gum is not installed (it gives a nicer arrow-key/SPACE checkbox menu, but is optional). Install it now? [y/N] " ans
  case "$ans" in
    y|Y|yes)
      warning "Installing gum via $DISTRO packages (may need sudo)..."
      case "$DISTRO" in
        debian) sudo apt-get install -y gum 2>/dev/null || sudo apt install -y gum ;;
        arch)   sudo pacman -S --noconfirm --needed gum ;;
        fedora) sudo dnf install -y gum ;;
      esac || { warning "Couldn't install gum. Continuing with the plain menu (no dependencies)."; return 0; }
      use_gum && info "gum installed. Enjoy the checkbox menu."
      ;;
  esac
  return 0
}

# Plain numbered toggle menu (used when gum isn't available).
select_apps_legacy() {
  local -a chosen=("${SELECTED_APPS[@]}")
  local names=("${ALL_APPS[@]}")
  local choice tok idx i
  echo
  echo "Which apps should THIS machine get? (toggle by number, ranges like 1-3)"
  echo "  (plain menu -- works with NO extra installs; install gum for arrow-key checkboxes)"
  echo "  [a] all   [n] none     <enter> to finish"
  while true; do
    echo "----------------------------------------"
    for i in "${!names[@]}"; do
      printf '  [%2d] %-10s [%s]  %s\n' $((i+1)) "${names[$i]}" \
        "$([[ " ${chosen[*]} " == *" ${names[$i]} "* ]] && echo x || echo ' ')" \
        "${APP_DESC[${names[$i]}]}"
    done
    echo "----------------------------------------"
    read -rp "> " choice
    [ -z "$choice" ] && [ ${#chosen[@]} -gt 0 ] && break
    case "$choice" in
      a|A) chosen=("${names[@]}") ;;
      n|N) chosen=() ;;
      *)
        for tok in $(echo "$choice" | tr ',' ' '); do
          if [[ "$tok" =~ ^([0-9]+)-([0-9]+)$ ]]; then
            for ((i=BASH_REMATCH[1]; i<=BASH_REMATCH[2]; i++)); do
              idx=$((i-1)); [ "$idx" -ge 0 ] && [ "$idx" -lt ${#names[@]} ] && toggle chosen "${names[$idx]}"
            done
          elif [[ "$tok" =~ ^[0-9]+$ ]]; then
            idx=$((tok-1)); [ "$idx" -ge 0 ] && [ "$idx" -lt ${#names[@]} ] && toggle chosen "${names[$idx]}"
          fi
        done
        ;;
    esac
  done
  SELECTED_APPS=("${chosen[@]}")
}

# Interactive checkbox picker. Uses gum when available (arrow keys + SPACE to
# tick/untick, type to filter, ENTER to confirm); falls back to the numbered
# menu otherwise. Pre-selects the apps already in SELECTED_APPS (a saved profile).
# Returns 0 on a confirmed selection (possibly empty), 1 if the user cancels.
select_apps_interactive() {
  local a
  bootstrap_gum          # optional: install gum on a fresh box if user says yes
  if use_gum; then
    # Show a quick legend with descriptions, then gum over plain app names.
    echo
    info "Available apps:"
    for a in "${ALL_APPS[@]}"; do
      printf '  \033[2m%-10s\033[0m %s\n' "$a" "${APP_DESC[$a]}"
    done
    echo
    info "Name the apps for this machine with the checkbox menu."
    local sel=""
    local -a gum_args=(
      --no-limit --ordered
      --header "Which apps should $(hostname) get?  (space = tick/untick, / = filter)"
      --cursor "> " --cursor-prefix "  "
      --selected-prefix "✔ " --unselected-prefix "  "
      --height "${#ALL_APPS[@]}"
    )
    if [ ${#SELECTED_APPS[@]} -gt 0 ]; then
      gum_args+=(--selected "$(IFS=,; echo "${SELECTED_APPS[*]}")")
    fi
    if ! sel="$(printf '%s\n' "${ALL_APPS[@]}" | gum choose "${gum_args[@]}")"; then
      echo
      info "Selection cancelled."
      return 1
    fi
    local line
    SELECTED_APPS=()
    while IFS= read -r line; do
      [ -n "$line" ] && SELECTED_APPS+=("$line")
    done <<< "$sel"
    return 0
  fi
  select_apps_legacy
}

# Show the final ticked list and ask for confirmation before anything is linked.
# Returns 0 to proceed, 1 to re-open the menu.
confirm_selection() {
  local a
  if [ ${#SELECTED_APPS[@]} -eq 0 ]; then
    warning "No apps selected yet."
    return 1
  fi
  echo
  info "Apps that will be symlinked on $(hostname):"
  for a in "${ALL_APPS[@]}"; do
    if [[ " ${SELECTED_APPS[*]} " == *" $a "* ]]; then
      printf '  \033[1;32m✔\033[0m %-10s %s\n' "$a" "${APP_DESC[$a]}"
    fi
  done
  echo
  if use_gum; then
    gum confirm "Link these apps now?" \
      --affirmative "Yes, link them" --negative "No, edit selection" --default=true
    return $?
  fi
  local ans
  read -rp "Link these apps now? [Y/n] " ans
  case "$ans" in
    n|N|no) return 1 ;;
    *)       return 0 ;;
  esac
}

# ---------------------------------------------------------------------------
# Linking
# ---------------------------------------------------------------------------
# Symlink one repo path to a target (replacing stale links from older layouts).
link_one() {
  local src="$1" tgt="$2"
  local src_abs="$DOTFILES_DIR/$src" tgt_abs tgt_dir use_sudo=""
  if [[ "$tgt" == /* ]]; then tgt_abs="$tgt"; use_sudo="sudo"; else tgt_abs="$HOME/$tgt"; fi

  # Never clobber a real file/dir the user owns (only replace our own symlinks)
  if [ -e "$tgt_abs" ] && [ ! -L "$tgt_abs" ]; then
    warning "Skip $src -> $tgt_abs (a real file/dir exists). Remove it manually to adopt this app."
    return
  fi

  tgt_dir="$(dirname "$tgt_abs")"
  if [ -n "$use_sudo" ]; then
    sudo mkdir -p "$tgt_dir"
    sudo rm -f "$tgt_abs"
    sudo ln -sfn "$src_abs" "$tgt_abs"
  else
    mkdir -p "$tgt_dir"
    rm -f "$tgt_abs"
    ln -sfn "$src_abs" "$tgt_abs"
  fi
  info "Linked: ${tgt_abs#$HOME/} -> $src"
}

link_app() {
  local app="$1"
  local links="${APP_LINKS[$app]:-}"
  local spec src tgt
  [ -n "$links" ] || { warning "No link rules for '$app'."; return 1; }
  for spec in $links; do
    IFS='|' read -r src tgt <<<"$spec"
    link_one "$src" "$tgt"
  done
}

link_all() {
  local a
  for a in "${SELECTED_APPS[@]}"; do link_app "$a"; done
}

# ---------------------------------------------------------------------------
# Optional per-app distro package install
# ---------------------------------------------------------------------------
install_deps() {
  [ "$DO_DEPS" -eq 1 ] || return 0
  info "Installing distro packages for your selected apps..."
  local a dep pkg
  for a in "${SELECTED_APPS[@]}"; do
    for dep in ${APP_DEPS[$a]:-}; do
      pkg="$(resolve_pkg "$dep")"
      if [ "$pkg" = "__skip__" ]; then
        info "  $dep: not in $DISTRO official repos — skip/install manually."
        continue
      fi
      info "  installing $dep ($pkg)"
      install_pkg "$pkg" || warning "  failed to install $dep"
    done
  done
}

# ---------------------------------------------------------------------------
# Submodule + per-app setup hooks
# ---------------------------------------------------------------------------
init_submodules() {
  if [ -f "$DOTFILES_DIR/.gitmodules" ]; then
    info "Initializing git submodules (nvim config)..."
    git -C "$DOTFILES_DIR" submodule update --init --recursive || warning "submodule init failed"
  fi
}

setup_zsh() {
  if [ -x "$DOTFILES_DIR/scripts/zsh.sh" ]; then
    info "Running zsh setup (oh-my-zsh, plugins, default shell)..."
    bash "$DOTFILES_DIR/scripts/zsh.sh"
  fi
}

setup_tmux() {
  if [ ! -d "$HOME/.tmux/plugins/tpm" ]; then
    info "Installing tmux plugin manager (TPM)..."
    mkdir -p "$HOME/.tmux/plugins"
    git clone --depth 1 https://github.com/tmux-plugins/tpm "$HOME/.tmux/plugins/tpm" \
      || warning "Could not clone TPM — install manually."
  else
    info "TPM already installed."
  fi
}

setup_app() {
  case "$1" in
    zsh)  setup_zsh ;;
    tmux) setup_tmux ;;
  esac
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
main() {
  DO_DEPS=0
  local edit=0 all_mode=0 list_mode=0 positional=()
  for arg in "$@"; do
    case "$arg" in
      --all)      all_mode=1 ;;
      --list)     list_mode=1 ;;
      --deps)     DO_DEPS=1 ;;
      --no-deps)  DO_DEPS=0 ;;
      --edit)     edit=1 ;;
      -h|--help)  usage 0 ;;
      --*)        warning "Unknown option '$arg'"; usage 1 ;;
      *)          positional+=("$arg") ;;
    esac
  done

  [ "$list_mode" -eq 1 ] && { list_apps; exit 0; }

  detect_distro
  init_submodules   # needed before nvim is usable

  # 1) Determine the selection
  if [ ${#positional[@]} -gt 0 ]; then
    normalize_apps "${positional[@]}"
    [ ${#SELECTED_APPS[@]} -eq 0 ] && error "None of the provided apps are valid. See --list."
  elif [ "$all_mode" -eq 1 ]; then
    SELECTED_APPS=("${ALL_APPS[@]}")
  elif [ "$edit" -eq 0 ] && load_profile; then
    info "Using saved profile ($(hostname)): ${SELECTED_APPS[*]}"
    echo "Re-run with --edit to change, or `--all` for everything."
  else
    # Interactive path: keep re-opening the checklist until the selection is
    # confirmed (or the user cancels with Ctrl-C).
    while true; do
      select_apps_interactive || { echo; info "Aborted by user."; exit 1; }
      confirm_selection && break
    done
    save_profile
  fi

  [ ${#SELECTED_APPS[@]} -eq 0 ] && warning "No apps selected — nothing to do."
  echo
  echo "Selected apps: ${SELECTED_APPS[*]:-<none>}"

  # 2) Optional dependency install
  install_deps

  # 3) Symlink everything
  link_all

  # 4) Per-app setup hooks
  local a
  for a in "${SELECTED_APPS[@]}"; do setup_app "$a"; done

  echo
  info "Done! Symlinked: ${SELECTED_APPS[*]:-<none>}"
  info "Restart your shell (exec zsh) or log out/in to pick up changes."
}

main "$@"
