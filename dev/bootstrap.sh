#!/bin/bash
# Wealthbox developer toolchain bootstrap
# Usage: curl -fsSL https://raw.githubusercontent.com/starburstlabs/public/main/dev/bootstrap.sh | bash
set -euo pipefail

# Install Homebrew if missing
if ! command -v brew &>/dev/null; then
  echo "Installing Homebrew..."
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  eval "$(/opt/homebrew/bin/brew shellenv)"
fi

# Install GitHub CLI if missing
if ! command -v gh &>/dev/null; then
  echo "Installing GitHub CLI..."
  brew install gh
fi

# Authenticate GitHub CLI (needed for private repos)
if ! gh auth status &>/dev/null; then
  echo "Please authenticate with GitHub:"
  gh auth login </dev/tty
fi
gh auth setup-git

# Clone dev-tools
DEV_TOOLS_DIR="${WB_DEV_TOOLS_DIR:-$HOME/dev-tools}"
if [ ! -d "$DEV_TOOLS_DIR" ]; then
  echo "Cloning dev-tools to $DEV_TOOLS_DIR..."
  gh repo clone starburstlabs/dev-tools "$DEV_TOOLS_DIR"
else
  echo "dev-tools already at $DEV_TOOLS_DIR"
fi

# Install toolchain via Brewfile (tap trust declared inline with trusted: true)
echo "Installing toolchain..."
brew bundle --file "$DEV_TOOLS_DIR/Brewfile"

echo ""
echo "Toolchain installed. Run bootstrap to configure credentials:"
echo "  wb dev:bootstrap"
