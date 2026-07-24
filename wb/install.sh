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
  "") brewfiles=(Brewfile); manifest=Brewfile; program=wb ;;
  --ops) brewfiles=(Brewfile Brewfile.ops); manifest=Brewfile.ops; program=wbops ;;
  *) die "Usage: install.sh [--ops]" ;;
esac

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
command -v gh &>/dev/null || { log "Installing GitHub CLI..."; HOMEBREW_NO_ASK=1 brew install gh; }

# Authenticate, then wire gh into git's credential helper for the private clone.
# Probing the repo is stronger than `gh auth status`: a token can be valid yet
# lack the 'repo' scope or the starburstlabs org's SSO grant.
if ! gh api repos/starburstlabs/dev-tools --silent 2>/dev/null; then
  log "Log in with a GitHub account that can read starburstlabs/dev-tools:"
  gh auth login </dev/tty
fi
gh auth setup-git

# Refresh explicitly so an existing tap cannot install a stale release.
log "Refreshing Homebrew..."
brew update --quiet || die "Homebrew update failed (see output above)."

# Keep profile files together so Brewfile.ops can include Brewfile.
bundle_dir="$(mktemp -d)"
trap 'rm -rf "$bundle_dir"' EXIT
for brewfile in "${brewfiles[@]}"; do
  gh api "repos/starburstlabs/dev-tools/contents/$brewfile" \
    -H "Accept: application/vnd.github.raw" \
    > "$bundle_dir/$brewfile" \
    || die "Could not fetch $brewfile. Run 'gh auth setup-git', then re-run."
done
log "Installing $manifest..."
HOMEBREW_NO_ASK=1 brew bundle --file="$bundle_dir/$manifest" \
  || die "Toolchain install failed (see output above)."

log ""
if [ "$_fresh_homebrew" = true ]; then
  log "Toolchain installed. Open a new terminal tab, then run:"
else
  log "Toolchain installed. Run:"
fi
log "  $program dev:bootstrap"
