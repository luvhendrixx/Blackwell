# Created by newuser for 5.9
# Starship prompt
eval "$(starship init zsh)"

# Quality of life
autoload -U compinit && compinit
setopt autocd
HISTSIZE=1000
SAVEHIST=1000
source /usr/share/zsh/plugins/zsh-history-substring-search/zsh-history-substring-search.zsh
bindkey '^[[A' history-substring-search-up
bindkey '^[[B' history-substring-search-down

source /usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh
source /usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh


eval "$(zoxide init zsh)"

# . "$HOME/.local/share/../bin/env"


# Replace standard ls with eza + icons + colors
alias ls="eza --icons=always --color=always"

# Your new, upgraded version of 'ls -la' (Lists everything as a clean grid with file details)
alias ll="eza -la --icons=always --git"

# A brand new shortcut to see your folders as a beautiful visual tree
alias lt="eza --tree --level=2 --icons=always"


# Auto-start SSH agent if not running
# if [ -z "$SSH_AUTH_SOCK" ]; then
    eval "$(ssh-agent -s)" > /dev/null
# fi

# to make the agent...persistent across termianl sessinon changes
# eval $(keychain -q --eval ~/.ssh/hetzner_key)

# irssi chat
alias chat="irssi"

# Posting API client tester
# alias api="posting"

# Super file alias ..bin is spf
alias file="spf"

# zed
alias zed="zeditor"

# fastfetch
alias ff="fastfetch"

# rbw
# alias bw-unlock='export BW_SESSION=$(bw unlock --raw)'


export GOPATH=$HOME/go
export PATH=$PATH:$GOPATH/bin



# Haskell toolchain. Was hardcoded to /home/harry (and duplicated), so it
# silently did nothing for any other username.
[ -f "$HOME/.ghcup/env" ] && . "$HOME/.ghcup/env" # ghcup-env