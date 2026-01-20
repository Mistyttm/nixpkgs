#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NIX_FILE="${SCRIPT_DIR}/package.nix"

# Fetch the latest version from the versions.json endpoint
echo "Fetching latest version..." >&2
LATEST_VERSION=$(curl -s https://storage.tdarr.io/versions.json | jq -r 'keys_unsorted | .[0]')

if [[ -z "$LATEST_VERSION" ]]; then
    echo "Error: Could not fetch latest version from versions.json" >&2
    exit 1
fi

echo "Latest version: $LATEST_VERSION" >&2

# Check current version in package.nix
CURRENT_VERSION=$(grep -oP '(?<=version = ")[^"]+' "$NIX_FILE" 2>/dev/null)

if [[ "$CURRENT_VERSION" == "$LATEST_VERSION" ]]; then
    echo "Package is already on the latest version ($LATEST_VERSION)" >&2
    exit 0
fi

echo "Updating from $CURRENT_VERSION to $LATEST_VERSION..." >&2

fetch_and_convert() {
    local url=$1
    nix-prefetch-url --unpack "$url" 2>/dev/null | xargs nix hash convert --hash-algo sha256 --to sri
}

# Fetch all hashes
echo "Fetching hashes for version $LATEST_VERSION..." >&2
linux_x64=$(fetch_and_convert "https://storage.tdarr.io/versions/$LATEST_VERSION/linux_x64/Tdarr_Server.zip")
linux_arm64=$(fetch_and_convert "https://storage.tdarr.io/versions/$LATEST_VERSION/linux_arm64/Tdarr_Server.zip")
darwin_x64=$(fetch_and_convert "https://storage.tdarr.io/versions/$LATEST_VERSION/darwin_x64/Tdarr_Server.zip")
darwin_arm64=$(fetch_and_convert "https://storage.tdarr.io/versions/$LATEST_VERSION/darwin_arm64/Tdarr_Server.zip")

# Update the package.nix file in place
tmpfile=$(mktemp)

# Update version and hashes
awk -v ver="$LATEST_VERSION" -v lx64="$linux_x64" -v la64="$linux_arm64" -v dx64="$darwin_x64" -v da64="$darwin_arm64" '
/^  version = / {
    print "  version = \"" ver "\";"
    next
}
/^  hashes = {$/ {
    print $0
    getline; print "    linux_x64 = \"" lx64 "\";"
    getline; print "    linux_arm64 = \"" la64 "\";"
    getline; print "    darwin_x64 = \"" dx64 "\";"
    getline; print "    darwin_arm64 = \"" da64 "\";"
    getline; print $0
    next
}
{ print }
' "$NIX_FILE" > "$tmpfile"

mv "$tmpfile" "$NIX_FILE"
echo "Updated $NIX_FILE to version $LATEST_VERSION with new hashes" >&2
