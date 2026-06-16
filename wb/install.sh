#!/bin/bash
# Wealthbox developer toolchain bootstrap
# Usage: curl -fsSL https://raw.githubusercontent.com/starburstlabs/public/main/wb/install.sh | bash
set -euo pipefail

[[ "$(uname -m)" == "arm64" ]] || { echo "Error: Apple Silicon (arm64) required."; exit 1; }

# Install Homebrew if missing
_fresh_homebrew=false
if ! command -v brew &>/dev/null; then
  echo "Installing Homebrew..."
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  eval "$(/opt/homebrew/bin/brew shellenv)"  # /opt/homebrew is the ARM-only path; guarded above
  _fresh_homebrew=true
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

# Fetch Brewfile from dev-tools and install toolchain
echo "Installing toolchain..."
WB_DIR="$HOME/.wb"
mkdir -p "$WB_DIR"
gh api repos/starburstlabs/dev-tools/contents/Brewfile -H "Accept: application/vnd.github.raw" > "$WB_DIR/Brewfile"
brew bundle --file "$WB_DIR/Brewfile"

echo ""
if [ "$_fresh_homebrew" = true ]; then
  echo "Toolchain installed. Open a new terminal tab, then run:"
else
  echo "Toolchain installed. Run:"
fi
echo "  wb dev:bootstrap"
