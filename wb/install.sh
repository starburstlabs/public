#!/bin/bash
# Wealthbox developer toolchain bootstrap
# Usage: curl -fsSL https://raw.githubusercontent.com/starburstlabs/public/main/wb/install.sh | bash
set -euo pipefail

log() { echo "$@" >&2; }
die() { log "$@"; exit 1; }

[[ "$(uname -m)" == "arm64" ]] || die "Apple Silicon (arm64) required."

export HOMEBREW_NO_AUTO_UPDATE=1
# Fail fast rather than hang on a Git credential prompt during the private-repo clone.
export GIT_TERMINAL_PROMPT=0

# Install Homebrew if missing
_fresh_homebrew=false
if ! command -v brew &>/dev/null; then
  log "Installing Homebrew..."
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  eval "$(/opt/homebrew/bin/brew shellenv)"  # /opt/homebrew is the ARM-only path; guarded above
  _fresh_homebrew=true
fi

# Install GitHub CLI if missing
command -v gh &>/dev/null || { log "Installing GitHub CLI..."; brew install gh; }

# Authenticate, then wire gh into git's credential helper for the private clone.
# Probing the repo is stronger than `gh auth status`: a token can be valid yet
# lack the 'repo' scope or the starburstlabs org's SSO grant.
if ! gh api repos/starburstlabs/dev-tools --silent 2>/dev/null; then
  log "Log in with a GitHub account that can read starburstlabs/dev-tools:"
  gh auth login </dev/tty
fi
gh auth setup-git

# Fetch the Brewfile and install the toolchain
log "Installing toolchain..."
WB_DIR="$HOME/.wb"
mkdir -p "$WB_DIR"
gh api repos/starburstlabs/dev-tools/contents/Brewfile -H "Accept: application/vnd.github.raw" > "$WB_DIR/Brewfile"
brew bundle --file "$WB_DIR/Brewfile" \
  || die "Toolchain install failed (see output above). If wb-cli hit a Git auth error, run 'gh auth setup-git', update Homebrew, then re-run."

log ""
if [ "$_fresh_homebrew" = true ]; then
  log "Toolchain installed. Open a new terminal tab, then run:"
else
  log "Toolchain installed. Run:"
fi
log "  wb dev:bootstrap"
