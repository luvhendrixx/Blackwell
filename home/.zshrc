# Use the slim prompt inside Zed or VS Code terminals
if [[ -n $ZED_TERM || $TERM_PROGRAM == zed || $TERM_PROGRAM == vscode ]]; then
  export STARSHIP_CONFIG="$HOME/.config/starship-ide.toml"
fi

# Starship prompt
eval "$(starship init zsh)"

# ---------- Blackwell update manager ----------
blackwell() {
  bash "$HOME/dotfiles/update.sh" "$@"
}
bw() { blackwell "$@"; }

# ---------- Quality of life ----------
autoload -U compinit
compinit -D -d ~/.zcompdump
setopt autocd

HISTFILE=~/.zsh_history
HISTSIZE=10000
SAVEHIST=10000
setopt hist_ignore_dups hist_ignore_space share_history

# Instantly append commands to history file as soon as you hit Enter (instead of waiting for terminal exit)
setopt INC_APPEND_HISTORY

# Skip saving a command to history if it perfectly matches the previous one you just ran
setopt HIST_IGNORE_DUPS

# ---------- Lazy-load zoxide (only init on first use) ----------
_ZOXIDE_LOADED=0
_zoxide_lazy_setup() {
  [[ $_ZOXIDE_LOADED -eq 1 ]] && return
  _ZOXIDE_LOADED=1
  eval "$(zoxide init zsh)"
}
z() {
  _zoxide_lazy_setup
  __zoxide_z "$@"
}
zi() {
  _zoxide_lazy_setup
  __zoxide_zi "$@"
}
# ---------- Aliases ----------
alias ls="eza --icons=always --color=auto"
alias ll="eza -la --icons=always --git"
alias lt="eza --tree --level=2 --icons=always"
alias chat="irssi"
alias fm="spf"
alias zed="zeditor"
alias ff="fastfetch"
# alias code="codium"
alias cv="heif-convert" # a terminal util for easy conversion of files to diff fmts

# ---------- Git metrics (on-demand, replaces starship git_metrics) ----------
gitstats() {
  local added deleted
  added=$(git diff --shortstat 2>/dev/null | awk '{print $4}')
  deleted=$(git diff --shortstat 2>/dev/null | awk '{print $6}')
  if [[ -n "$added" || -n "$deleted" ]]; then
    print -P "%F{green}+$added%f %F{red}-$deleted%f"
  else
    print -P "%F{yellow}no changes%f"
  fi
}

# ---------- SSH agent (only start if not already running) ----------
#if [ -z "$SSH_AUTH_SOCK" ]; then
#  eval "$(ssh-agent -s)" > /dev/null
#fi
# eval $(keychain -q --eval ~/.ssh/myssh_key)


# ---------- Plugins (deferred until after first prompt) ----------
_defer_plugins() {
  source /usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh
  source /usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
  source /usr/share/zsh/plugins/zsh-history-substring-search/zsh-history-substring-search.zsh
  bindkey '^[[A' history-substring-search-up
  bindkey '^[[B' history-substring-search-down
  zle -D zle-line-init
}
zle-line-init() {
  _defer_plugins
}
zle -N zle-line-init

# ---------- Lazy-load fzf (only init on first use) ----------
fzf() {
  unfunction fzf
  source <(fzf --zsh)
  fzf "$@"
}

export EDITOR="nvim"
export VISUAL="nvim"
export LIBVA_DRIVER_NAME=iHD


# ---------- Languages ----------
export GOPATH=$HOME/go
export PATH=$PATH:$GOPATH/bin
[ -f "$HOME/.ghcup/env" ] && . "$HOME/.ghcup/env" # ghcup-env
