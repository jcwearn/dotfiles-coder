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

# Zsh shells - the NVM block is already in the repo .zshrc, but ensure it's
# present in case an older symlink target was used. ensure_block_in_file is
# idempotent (checks for the marker before appending).
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
# These persist on the PVC — skip if already present.
# ------------------------------------------------------------
if [ -s "$NVM_DIR/nvm.sh" ]; then
  log "nvm already installed; skipping"
else
  log "Installing nvm..."
  curl -fsSL https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash
fi

# Temporarily disable nounset for nvm
set +u
# shellcheck disable=SC1090
[ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"

if command -v node >/dev/null 2>&1; then
  log "Node already installed: $(node --version); skipping"
else
  log "Installing Node (LTS)..."
  nvm install --lts
  nvm use --lts
fi
set -u

# ------------------------------------------------------------
# 4) Install Claude Code CLI (persists on PVC via nvm prefix)
# ------------------------------------------------------------
if command -v claude >/dev/null 2>&1; then
  log "Claude Code CLI already installed; skipping"
else
  log "Installing Claude Code CLI..."
  npm install -g @anthropic-ai/claude-code
fi

# ------------------------------------------------------------
# 5) Install common dev CLI tools
# These install to the ephemeral container filesystem. We check
# whether key packages are present to skip re-installation on
# container restarts where the filesystem is intact.
# ------------------------------------------------------------
if command -v zsh >/dev/null 2>&1 && command -v gh >/dev/null 2>&1; then
  log "System packages already installed; skipping"
else
  log "Installing apt packages..."
  sudo apt-get update
  sudo apt-get install -y --no-install-recommends \
    jq \
    zsh \
    ripgrep \
    fd-find \
    bat \
    fzf \
    htop \
    tree \
    wget \
    unzip \
    nano

  # Install yq
  if ! command -v yq >/dev/null 2>&1; then
    log "Installing yq..."
    sudo wget -qO /usr/local/bin/yq https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64
    sudo chmod +x /usr/local/bin/yq
  else
    log "yq already installed; skipping"
  fi

  # Install GitHub CLI (gh)
  if ! command -v gh >/dev/null 2>&1; then
    log "Installing GitHub CLI..."
    curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg
    sudo chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null
    sudo apt-get update
    sudo apt-get install -y gh
  else
    log "GitHub CLI already installed; skipping"
  fi

fi

# Install Oh My Zsh (persists on PVC)
log "Installing Oh My Zsh..."
ZSH_DIR="$HOME/.oh-my-zsh"
if [ -d "$ZSH_DIR" ]; then
  log "Oh My Zsh already present at $ZSH_DIR; skipping clone"
else
  # Remove any partial state (e.g., a file instead of directory)
  rm -rf "$ZSH_DIR"
  # Strip any git env that Coder might inject in the dotfiles context
  env -u GIT_DIR -u GIT_WORK_TREE -u GIT_INDEX_FILE -u GIT_OBJECT_DIRECTORY -u GIT_ALTERNATE_OBJECT_DIRECTORIES \
      -u GIT_COMMON_DIR -u GIT_CONFIG_COUNT -u GIT_CONFIG_GLOBAL -u GIT_CONFIG_SYSTEM \
      -u GIT_ASKPASS -u GIT_SSH_COMMAND \
    git clone --depth=1 https://github.com/ohmyzsh/ohmyzsh.git "$ZSH_DIR"
fi

# ------------------------------------------------------------
# 6) Set zsh as default shell (may fail in containers; ignore)
# ------------------------------------------------------------
if [ "${SHELL:-}" != "/bin/zsh" ]; then
  log "Attempting to set default shell to zsh..."
  chsh -s /bin/zsh || true
fi

log "Dotfiles installation complete!"
log "Open a NEW terminal session (or run: source ~/.bashrc) for nvm/node/claude to be on PATH."
