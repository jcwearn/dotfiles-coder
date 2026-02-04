#!/bin/bash
set -e

# Install Node.js via nvm
export NVM_DIR="$HOME/.nvm"
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash
source "$NVM_DIR/nvm.sh"
nvm install --lts
nvm use --lts

# Install Claude Code CLI
npm install -g @anthropic-ai/claude-code

# Install common dev CLI tools
sudo apt-get update && sudo apt-get install -y \
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
sudo wget -qO /usr/local/bin/yq https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64
sudo chmod +x /usr/local/bin/yq

# Set zsh as default shell
if [ "$SHELL" != "/bin/zsh" ]; then
    chsh -s /bin/zsh || true
fi

# Install oh-my-zsh
if [ ! -d "$HOME/.oh-my-zsh" ]; then
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
fi

echo "Dotfiles installation complete!"