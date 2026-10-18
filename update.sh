#!/usr/bin/env bash
#
# Blackwell — dotfiles / system update manager (interactive, mirrors omarchy).
#
# Usage:
#   bw -u|--update    full suite: yay + (fetch -> check -> pull) + symlink check
#   bw -f|--fetch     dotfiles fetch only
#   bw -p|--pull      dotfiles pull only
#   bw -y|--yay       yay/AUR updates only
#   bw -s|--status    repo status (branch, ahead/behind, dirtiness)
#   bw -d|--diff      dry run: what would change
#   bw -l|--log       last few commits
#   bw -h|--help      help

set -uo pipefail

REPO_DIR="$HOME/dotfiles"

# ─── colors ──────────────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BLUE='\033[0;34m'; BOLD='\033[1m'
NC='\033[0m'

log()   { echo -e "${BOLD}${CYAN}[blackwell]${NC} $*"; }
warn()  { echo -e "${YELLOW}[warn]${NC}     $*"; }
err()   { echo -e "${RED}[error]${NC}    $*"; }
ok()    { echo -e "${GREEN}[ok]${NC}       $*"; }
sep()   { echo -e "${BLUE}──────────────────────────────────────────────────────────${NC}"; }

banner() {
  sep
  echo -e "${BOLD}${GREEN}  BLACKWELL — dotfiles update${NC}"
  sep
  date '+  %a, %d %b %Y %H:%M:%S'
  sep
}

help() {
  cat <<EOF
Usage: bw {flag}

Flags:
  -u, --update      Full update suite (yay + fetch + pull + symlink check)
  -f, --fetch       Dotfiles fetch only
  -p, --pull        Dotfiles pull only
  -y, --yay         yay/AUR updates only
  -s, --status      Show repo status (branch, ahead/behind, dirtiness)
  -d, --diff        Dry run: commits/patch that would come in
  -l, --log         Show last 5 local & remote commits
  -h, --help        Show this help

Examples:
  bw -u          Run the full update suite
  bw update      Same as -u
  bw -s          Quick status
EOF
}

# ─── helpers ────────────────────────────────────────────────────────────────
ensure_repo() {
  if [[ ! -d $REPO_DIR/.git ]]; then
    err "Repo not found at $REPO_DIR"
    exit 1
  fi
}

# ─── system update ──────────────────────────────────────────────────────────
do_yay() {
  log "Updating system + AUR packages (yay -Syu)..."
  if yay -Syu; then
    ok "System updated"
  else
    err "yay failed — check output above"
    return 1
  fi
}

# ─── dotfiles fetch ─────────────────────────────────────────────────────────
do_fetch() {
  ensure_repo
  log "Fetching from remote..."
  (cd "$REPO_DIR" && git fetch --all --prune)
  local before after
  before=$(cd "$REPO_DIR" && git rev-parse HEAD)
  after=$(cd "$REPO_DIR" && git rev-parse '@{u}' 2>/dev/null)
  if [[ $before != $after ]]; then
    warn "New commits available on remote"
    echo "    local:  $before"
    echo "    remote: $after"
  else
    ok "Remote is at the same commit (nothing new to pull)"
  fi
}

# ─── dotfiles pull ──────────────────────────────────────────────────────────
do_pull() {
  ensure_repo
  (cd "$REPO_DIR" && git fetch --all --prune) || return 1

  local before remote local_head remote_head
  local_head=$(cd "$REPO_DIR" && git rev-parse HEAD)
  remote_head=$(cd "$REPO_DIR" && git rev-parse '@{u}' 2>/dev/null || echo "")

  if [[ -z $remote_head ]]; then
    warn "No upstream configured for HEAD"
    return 1
  fi
  if [[ $local_head != $remote_head ]]; then
    log "New updates available — pulling..."
    # check for dirty worktree and auto-stash
    if [[ -n $(cd "$REPO_DIR" && git status --porcelain) ]]; then
      warn "Uncommitted changes detected — stashing automatically"
      (cd "$REPO_DIR" && git stash push -u -m "bw auto-stash" )
      STASHED=1
    else
      STASHED=0
    fi
    if (cd "$REPO_DIR" && git pull --ff-only); then
      ok "Dotfiles pulled"
      do_new_packages "$local_head"
      if [[ $STASHED -eq 1 ]]; then
        log "Restoring stashed changes..."
        (cd "$REPO_DIR" && git stash pop) || \
          warn "Stash pop had conflicts — run 'git stash list' to resolve"
      fi
    else
      err "git pull failed (maybe divergent branches)"
      return 1
    fi
  else
    ok "Dotfiles already up to date"
  fi
}

# ─── status ─────────────────────────────────────────────────────────────────
do_status() {
  ensure_repo
  (cd "$REPO_DIR" && git fetch --quiet 2>/dev/null || true)
  local branch ahead behind
  branch=$(cd "$REPO_DIR" && git branch --show-current)
  ahead=$(cd "$REPO_DIR"  && git rev-list --count '@{u}..HEAD' 2>/dev/null || echo 0)
  behind=$(cd "$REPO_DIR" && git rev-list --count 'HEAD..@{u}' 2>/dev/null || echo 0)
  echo -e "${BOLD}Branch:${NC}   $branch"
  echo -e "${BOLD}Ahead:${NC}    $ahead"
  echo -e "${BOLD}Behind:${NC}   $behind"
  if (cd "$REPO_DIR" && git diff --quiet); then
    ok "Working tree clean"
  else
    warn "Working tree has uncommitted changes"
    (cd "$REPO_DIR" && git status --short)
  fi
}

# ─── dry run ────────────────────────────────────────────────────────────────
do_diff() {
  ensure_repo
  (cd "$REPO_DIR" && git fetch --all --prune 2>/dev/null)
  log "Commits that would arrive:"
  (cd "$REPO_DIR" && git log --oneline --no-decorate '..@{u}' 2>/dev/null || echo "  (none)")
  echo
  log "Diff summary:"
  (cd "$REPO_DIR" && git diff --stat HEAD..@{u} 2>/dev/null || echo "  (none)")
}

# ─── log ────────────────────────────────────────────────────────────────────
do_log() {
  ensure_repo
  echo -e "${BOLD}Local (last 5):${NC}"
  (cd "$REPO_DIR" && git log --oneline -5)
  echo
  echo -e "${BOLD}Remote (last 5):${NC}"
  (cd "$REPO_DIR" && git log --oneline -5 '@{u}' 2>/dev/null || echo "  (none)")
}

# ─── newly added packages (delta install after a pull) ─────────────────────
# If an update adds packages to packages-repo.txt / packages-aur.txt, they need
# to be installed too — otherwise new dotfiles features fail silently. Compute
# the delta between the OLD commit's lists and the pulled ones and install only
# what's new. Failures are non-fatal (warn) so an update never bricks itself.
do_new_packages() {
  local old_head="$1"
  local added_repo added_aur all_new repo_pkgs="" strays=""
  cd "$REPO_DIR" || return 1

  added_repo=$(comm -13 \
    <(git show "$old_head:packages-repo.txt" 2>/dev/null | grep -vE '^[[:space:]]*(#|$)' | sort -u) \
    <(grep -vE '^[[:space:]]*(#|$)' packages-repo.txt 2>/dev/null | sort -u) || true)
  added_aur=$(comm -13 \
    <(git show "$old_head:packages-aur.txt" 2>/dev/null | grep -vE '^[[:space:]]*(#|$)' | sort -u) \
    <(grep -vE '^[[:space:]]*(#|$)' packages-aur.txt 2>/dev/null | sort -u) || true)
  cd - > /dev/null

  all_new=$(printf '%s\n' $added_repo $added_aur | tr '\n' ' ')
  if [[ -z ${all_new// /} ]]; then
    ok "No new packages to install"
    return 0
  fi

  log "New packages in the update: ${all_new// /', '}"
  # split against the sync databases, like install.sh does
  local sync_db
  sync_db=$(pacman -Slq 2>/dev/null)
  for p in $added_repo $added_aur; do
    if grep -qxF "$p" <<< "$sync_db"; then
      repo_pkgs="$repo_pkgs $p"
    else
      strays="$strays $p"
    fi
  done

  if [[ -n ${repo_pkgs// /} ]]; then
    log "Installing new packages from official repos"
    sudo pacman -S --needed --noconfirm $repo_pkgs || warn "Some new packages failed to install — try manually"
  fi
  if [[ -n ${strays// /} ]]; then
    local helper
    if command -v yay >/dev/null 2>&1; then helper=yay
    elif command -v paru >/dev/null 2>&1; then helper=paru
    else
      warn "No AUR helper found — install these manually: $strays"
      return 0
    fi
    log "Installing new AUR packages with $helper"
    $helper -S --needed --noconfirm $strays || warn "Some new AUR packages failed to install — try manually"
  fi
}

# ─── broken symlinks ────────────────────────────────────────────────────────
check_broken_symlinks() {
  local broken
  broken=$(find "$HOME" -maxdepth 3 -type l ! -exec test -e {} \; -print 2>/dev/null | head -30)
  if [[ -n $broken ]]; then
    warn "Broken symlinks detected under \$HOME:"
    echo "$broken"
    echo
    warn "You probably lost files or a symlink target. Re-run the install:"
    echo "    bash $REPO_DIR/install.sh"
  else
    ok "No broken symlinks at shallow levels"
  fi
}

# ─── main ───────────────────────────────────────────────────────────────────
banner 2>/dev/null || true
STASHED=0
rc=0

case "${1:-}" in
  -u|--update|update)
    do_yay || rc=1
    do_pull || rc=1
    check_broken_symlinks
    ;;
  -f|--fetch)
    do_fetch || rc=1
    ;;
  -p|--pull)
    do_pull || rc=1
    check_broken_symlinks
    ;;
  -y|--yay)
    do_yay || rc=1
    ;;
  -s|--status)
    do_status
    ;;
  -d|--diff)
    do_diff
    ;;
  -l|--log)
    do_log
    ;;
  -h|--help|"")
    help
    ;;
  *)
    err "Unknown argument: $1"
    help
    exit 1
    ;;
esac

exit "$rc"
