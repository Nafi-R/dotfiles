export ZSH="$HOME/.oh-my-zsh"

plugins=(
    git
    zsh-syntax-highlighting
    zsh-autosuggestions
)

source $ZSH/oh-my-zsh.sh

PROMPT='%{$fg_bold[red]%}➜ %{$fg_bold[green]%}%p %{$fg[cyan]%}%2c %{$fg_bold[blue]%}$(git_prompt_info)%{$fg_bold[blue]%} % %{$reset_color%}'
ZSH_THEME_GIT_PROMPT_PREFIX="git:(%{$fg[red]%}"
ZSH_THEME_GIT_PROMPT_SUFFIX="%{$reset_color%}"
ZSH_THEME_GIT_PROMPT_DIRTY="%{$fg[blue]%}) %{$fg[yellow]%}✗%{$reset_color%}"
ZSH_THEME_GIT_PROMPT_CLEAN="%{$fg[blue]%})"

source "${HOME}/.config/nafi/utils"
# portable nvim (only if present)
[ -d /opt/nvim-linux-x86_64/bin ] && export PATH="/opt/nvim-linux-x86_64/bin:$PATH"
export PATH="${HOME}/.local/share/nafi/bin:$PATH"
# cargo: source the env file (it is a script, not a bin dir)
[ -f "$HOME/.cargo/env" ] && . "$HOME/.cargo/env"
# bun (default install location)
[ -d "$HOME/.bun/bin" ] && export PATH="$HOME/.bun/bin:$PATH"
export PATH="${HOME}/Applications/:$PATH"
export EDITOR="nvim"

bindkey -s '^g' 'goto\n'
bindkey -s '^s' 'sessionizer\n'


# opencode
export PATH="$HOME/.opencode/bin:$PATH"
[ -f "$HOME/.secrets" ] && source "$HOME/.secrets"

ollama() {
 docker exec -it ollama ollama $@
}

# Prime Agent (npm global binaries)
export PATH="$HOME/.npm-global/bin:$PATH"

# uv env (managed by `uv` in ~/.local/bin)
[ -f "$HOME/.local/bin/env" ] && . "$HOME/.local/bin/env"

# Pi
export PATH="$HOME/.pi/agent/bin:$PATH"

# Point pi-llama at local llama.cpp server (instead of default 9931)
export LLAMA_BASE_URL="http://localhost:8080/v1"
