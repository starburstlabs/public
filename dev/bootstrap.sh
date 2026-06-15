#!/bin/bash
# Wealthbox developer toolchain bootstrap
# Usage: curl -fsSL https://raw.githubusercontent.com/starburstlabs/public/main/dev/bootstrap.sh | bash
set -euo pipefail

# Install Homebrew if missing
_fresh_homebrew=false
if ! command -v brew &>/dev/null; then
  echo "Installing Homebrew..."
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  eval "$(/opt/homebrew/bin/brew shellenv)"
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

# Clone dev-tools
WB_DIR="$HOME/.wb"
WB_DEV_TOOLS_PATH_FILE="$WB_DIR/dev-tools-path"

if [ -n "${WB_DEV_TOOLS_DIR:-}" ]; then
  DEV_TOOLS_DIR="$WB_DEV_TOOLS_DIR"
elif [ -f "$WB_DEV_TOOLS_PATH_FILE" ]; then
  DEV_TOOLS_DIR="$(cat "$WB_DEV_TOOLS_PATH_FILE")"
  echo "dev-tools location: $DEV_TOOLS_DIR"
else
  while true; do
    printf "Where should dev-tools be cloned? [~/git/dev-tools]: "
    read -r _input </dev/tty
    DEV_TOOLS_DIR="${_input:-$HOME/git/dev-tools}"
    DEV_TOOLS_DIR="${DEV_TOOLS_DIR/#\~/$HOME}"
    printf "Clone to %s? [Y/n]: " "$DEV_TOOLS_DIR"
    read -r _confirm </dev/tty
    [[ "${_confirm:-y}" =~ ^[Yy]$ ]] && break
  done
fi

if [ ! -d "$DEV_TOOLS_DIR" ]; then
  mkdir -p "$(dirname "$DEV_TOOLS_DIR")"
  echo "Cloning dev-tools to $DEV_TOOLS_DIR..."
  gh repo clone starburstlabs/dev-tools "$DEV_TOOLS_DIR"
else
  echo "dev-tools already at $DEV_TOOLS_DIR"
fi

mkdir -p "$WB_DIR"
echo "$DEV_TOOLS_DIR" > "$WB_DEV_TOOLS_PATH_FILE"

# Install toolchain via Brewfile (tap trust declared inline with trusted: true)
echo "Installing toolchain..."
brew bundle --file "$DEV_TOOLS_DIR/Brewfile"

echo ""
if [ "$_fresh_homebrew" = true ]; then
  echo "Toolchain installed. Open a new terminal tab, then run:"
else
  echo "Toolchain installed. Run:"
fi
echo "  wb dev:bootstrap"
