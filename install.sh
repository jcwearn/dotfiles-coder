#!/bin/bash
set -euo pipefail

# Where this install.sh lives (Coder runs it from the cloned dotfiles repo)
DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

log() { echo "[dotfiles] $*"; }

backup_if_needed() {
  local target="$1"
  # If target exists and is not the symlink we want, back it up.
  if [ -e "$target" ] || [ -L "$target" ]; then
    # If it's a symlink, we still back it up unless it already points to what we want.
    local ts
    ts="$(date +%Y%m%d_%H%M%S)"
    mv -f "$target" "${target}.bak.${ts}"
    log "Backed up $target -> ${target}.bak.${ts}"
  fi
}

link_dotfile() {
  local name="$1"
  local src="${DOTFILES_DIR}/${name}"
  local dst="${HOME}/${name}"

  if [ ! -e "$src" ]; then
    log "Skipping ${name}: not found in repo at $src"
    return 0
  fi

  # If dst already symlinks to src, do nothing
  if [ -L "$dst" ] && [ "$(readlink "$dst")" = "$src" ]; then
    log "Symlink already correct: $dst -> $src"
    return 0
  fi

  backup_if_needed "$dst"
  ln -s "$src" "$dst"
  log "Linked $dst -> $src"
}

ensure_block_in_file() {
  local file="$1"
  local marker="$2"
  local block="$3"

  touch "$file"
  if ! grep -Fq "$marker" "$file"; then
    {
      echo ""
      echo "$marker"
      echo "$block"
      echo "$marker"
      echo ""
    } >> "$file"
    log "Added block to $file"
  else
    log "Block already present in $file"
  fi
}

# ------------------------------------------------------------
# 1) Symlink dotfiles from the repo into $HOME
# ------------------------------------------------------------
# Add more here as you add files to the repo:
link_dotfile ".gitconfig"
link_dotfile ".zshrc"

# ------------------------------------------------------------
# 2) Ensure shells load NVM so node/claude are on PATH in NEW shells
# ------------------------------------------------------------
export NVM_DIR="$HOME/.nvm"

NVM_BLOCK_MARKER="# >>> dotfiles-coder nvm >>>"
NVM_BLOCK_CONTENT=$(cat <<'EOF'
export NVM_DIR="$HOME/.nvm"
# Load nvm if installed
[ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"
# Load nvm bash_completion if available
[ -s "$NVM_DIR/bash_completion" ] && . "$NVM_DIR/bash_completion"
EOF
)

# Bash interactive shells
ensure_block_in_file "$HOME/.bashrc" "$NVM_BLOCK_MARKER" "$NVM_BLOCK_CONTENT"

# Bash login shells should source ~/.bashrc
BASH_PROFILE_MARKER="# >>> dotfiles-coder bash_profile >>>"
BASH_PROFILE_CONTENT=$(cat <<'EOF'
# Load ~/.bashrc for login shells
if [ -f "$HOME/.bashrc" ]; then
  . "$HOME/.bashrc"
fi
EOF
)
ensure_block_in_file "$HOME/.bash_profile" "$BASH_PROFILE_MARKER" "$BASH_PROFILE_CONTENT"

# Zsh shells (your repo .zshrc will be symlinked into $HOME)
ZSH_NVM_BLOCK_MARKER="# >>> dotfiles-coder nvm >>>"
ZSH_NVM_BLOCK_CONTENT=$(cat <<'EOF'
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"
EOF
)
ensure_block_in_file "$HOME/.zshrc" "$ZSH_NVM_BLOCK_MARKER" "$ZSH_NVM_BLOCK_CONTENT"

# ------------------------------------------------------------
# 2b) Prefer zsh for interactive web-terminal sessions
# Web terminal tends to start bash directly; this swaps into zsh.
# Guarded so non-interactive shells/scripts are unaffected.
# ------------------------------------------------------------
PREFER_ZSH_MARKER="# >>> dotfiles-coder prefer zsh >>>"
PREFER_ZSH_BLOCK=$(cat <<'EOF'
# If this is an interactive bash shell, replace it with zsh (if available).
case "$-" in
  *i*) ;;
  *) return ;;
esac

# Avoid loops if we're already in zsh.
if [ -n "${ZSH_VERSION:-}" ]; then
  return
fi

# Only exec if zsh exists.
if command -v zsh >/dev/null 2>&1; then
  export SHELL="$(command -v zsh)"
  exec zsh -l
fi
EOF
)
ensure_block_in_file "$HOME/.bashrc" "$PREFER_ZSH_MARKER" "$PREFER_ZSH_BLOCK"

# ------------------------------------------------------------
# 3) Install nvm + Node (LTS)
# IMPORTANT: nvm isn't always compatible with `set -u`,
# so temporarily disable nounset around sourcing/using nvm.
# ------------------------------------------------------------
log "Installing nvm..."
curl -fsSL https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash

# Temporarily disable nounset for nvm
set +u
# shellcheck disable=SC1090
[ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"

log "Installing Node (LTS)..."
nvm install --lts
nvm use --lts
set -u

# ------------------------------------------------------------
# 4) Install Claude Code CLI
# ------------------------------------------------------------
log "Installing Claude Code CLI..."
npm install -g @anthropic-ai/claude-code

# ------------------------------------------------------------
# 5) Install common dev CLI tools
# ------------------------------------------------------------
log "Installing apt packages..."
sudo apt-get update
sudo apt-get install -y \
  jq \
  zsh \
  ripgrep \
  fd-find \
  bat \
  fzf \
  htop \
  tree \
  wget \
  unzip

# Install yq
log "Installing yq..."
sudo wget -qO /usr/local/bin/yq https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64
sudo chmod +x /usr/local/bin/yq

# ------------------------------------------------------------
# 6) Set zsh as default shell (may fail in containers; ignore)
# ------------------------------------------------------------
if [ "${SHELL:-}" != "/bin/zsh" ]; then
  log "Attempting to set default shell to zsh..."
  chsh -s /bin/zsh || true
fi

log "Dotfiles installation complete!"
log "Open a NEW terminal session (or run: source ~/.bashrc) for nvm/node/claude to be on PATH."