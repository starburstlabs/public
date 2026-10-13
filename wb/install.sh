#!/bin/bash
# Wealthbox developer toolchain bootstrap
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/starburstlabs/public/main/wb/install.sh | bash
#   curl -fsSL https://raw.githubusercontent.com/starburstlabs/public/main/wb/install.sh | bash -s -- --ops
set -euo pipefail

log() { echo "$@" >&2; }
die() { log "$@"; exit 1; }

[[ "$(uname -m)" == "arm64" ]] || die "Apple Silicon (arm64) required."

case "${1:-}" in
  "") manifest=Brewfile; program=wb ;;
  --ops) manifest=Brewfile.ops; program=wbops ;;
  *) die "Usage: install.sh [--ops]" ;;
esac

export HOMEBREW_NO_AUTO_UPDATE=1
# Fail fast rather than hang on a Git credential prompt during the private-repo clone.
export GIT_TERMINAL_PROMPT=0

# Install Homebrew if missing
_fresh_homebrew=false
if ! command -v brew &>/dev/null; then
  log "Installing Homebrew..."
  homebrew_install_script="$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  /bin/bash -c "$homebrew_install_script" </dev/tty
  eval "$(/opt/homebrew/bin/brew shellenv)"  # /opt/homebrew is the ARM-only path; guarded above
  _fresh_homebrew=true
fi

# Install GitHub CLI if missing
command -v gh &>/dev/null || { log "Installing GitHub CLI..."; HOMEBREW_NO_ASK=1 brew install gh; }

# Authenticate, then wire gh into git's credential helper for the private clone.
# Probing the repo is stronger than `gh auth status`: a token can be valid yet
# lack the 'repo' scope or the starburstlabs org's SSO grant.
if ! gh api repos/starburstlabs/dev-tools --silent 2>/dev/null; then
  log "Log in with a GitHub account that can read starburstlabs/dev-tools:"
  gh auth login --hostname github.com </dev/tty
  gh api repos/starburstlabs/dev-tools --silent \
    || die "This GitHub account cannot read starburstlabs/dev-tools. Check repository access and organization SSO."
fi
gh auth setup-git
# Sandboxed Git downloads cannot read gh's token from the macOS keychain.
HOMEBREW_GITHUB_API_TOKEN="${HOMEBREW_GITHUB_API_TOKEN:-$(gh auth token --hostname github.com)}"
export HOMEBREW_GITHUB_API_TOKEN HOMEBREW_NO_ASK=1

# Refresh explicitly so an existing tap cannot install a stale release.
log "Refreshing Homebrew..."
brew update --quiet || die "Homebrew update failed (see output above)."

# Install or upgrade the CLI first, then apply the profile shipped by that release.
# The ops formula also installs wb-cli, which owns both profile files.
log "Installing $program..."
brew bundle --file=- <<EOF
tap "starburstlabs/dev-tools", trusted: true
brew "starburstlabs/dev-tools/${program}-cli"
EOF
log "Installing $manifest..."
brew bundle --file="$(brew --prefix wb-cli)/libexec/$manifest" \
  || die "Toolchain install failed (see output above)."

log ""
if [ "$_fresh_homebrew" = true ]; then
  log "Toolchain installed. Open a new terminal tab, then run:"
else
  log "Toolchain installed. Run:"
fi
log "  $program dev:bootstrap"
