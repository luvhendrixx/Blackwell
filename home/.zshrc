# Use the slim prompt inside Zed's terminal
if [[ -n $ZED_TERM || $TERM_PROGRAM == zed ]]; then
  export STARSHIP_CONFIG="$HOME/.config/starship-ide.toml"
fi


# Starship prompt
eval "$(starship init zsh)"


# ---------- Transient prompt ----------
TRANSIENT_PROMPT=$'\n%B%F{green}~ >%f%b '

zle-line-init() {
  emulate -L zsh
  [[ $CONTEXT == start ]] || return 0

  while true; do
    zle .recursive-edit
    local -i ret=$?
    [[ $ret == 0 && $KEYS == $'\4' ]] || break
    [[ -o ignore_eof ]] || exit 0
  done

  local saved_prompt=$PROMPT
  local saved_rprompt=$RPROMPT
  PROMPT=$TRANSIENT_PROMPT
  RPROMPT=''
  zle .reset-prompt
  PROMPT=$saved_prompt
  RPROMPT=$saved_rprompt

  if (( ret )); then
    zle .send-break
  else
    zle .accept-line
  fi
  return ret
}
zle -N zle-line-init

# ---------- Quality of life ----------
autoload -U compinit && compinit
setopt autocd

HISTFILE=~/.zsh_history
HISTSIZE=10000
SAVEHIST=10000
setopt hist_ignore_dups hist_ignore_space share_history

eval "$(zoxide init zsh)"

# ---------- Aliases ----------
alias ls="eza --icons=always --color=auto"
alias ll="eza -la --icons=always --git"
alias lt="eza --tree --level=2 --icons=always"
alias chat="irssi"
alias fm="spf"
alias zed="zeditor"
alias ff="fastfetch"

# ---------- SSH agent (only start if not already running) ----------
#if [ -z "$SSH_AUTH_SOCK" ]; then
#  eval "$(ssh-agent -s)" > /dev/null
#fi
# eval $(keychain -q --eval ~/.ssh/hetzner_key)

# ---------- Languages ----------
export GOPATH=$HOME/go
export PATH=$PATH:$GOPATH/bin
[ -f "/home/bond/.ghcup/env" ] && . "/home/bond/.ghcup/env" # ghcup-env


# ---------- Plugins (order matters: highlighting, then substring-search) ----------
source /usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh
source /usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
source /usr/share/zsh/plugins/zsh-history-substring-search/zsh-history-substring-search.zsh
bindkey '^[[A' history-substring-search-up
bindkey '^[[B' history-substring-search-down


