#!/usr/bin/env bash
# Download helpers shared by linux/installs/common.sh and mac/installs/common.sh:
# GitHub API calls that use your token when one is available, and SHA-256
# verification for every release binary this repo fetches directly. The
# PowerShell counterparts are Get-GitHubLatestTag and Test-FileSha256 in
# windows/common.ps1.
#
# Source this file, do not execute it. Expects the warn/info helpers from the
# platform's common.sh. Runs under macOS's bash 3.2: no bash 4 features.

# ─── GitHub API ───────────────────────────────────────────────────────────────

# A GitHub token, if one can be found without prompting: $GH_TOKEN or
# $GITHUB_TOKEN, else the gh CLI's own login. Unauthenticated API calls are
# limited to 60 an hour per IP, which a couple of setup runs on a shared
# network (or one CI job) can exhaust; authenticated calls get 5,000.
github_token() {
    if [ -n "${GH_TOKEN:-}" ]; then
        printf '%s' "$GH_TOKEN"
    elif [ -n "${GITHUB_TOKEN:-}" ]; then
        printf '%s' "$GITHUB_TOKEN"
    elif command -v gh >/dev/null 2>&1; then
        gh auth token 2>/dev/null
    fi
}

# curl against api.github.com, authenticated when a token is available.
github_api() {
    local token
    token="$(github_token)"
    if [ -n "$token" ]; then
        curl -fsSL -H "Authorization: Bearer $token" -H "Accept: application/vnd.github+json" "https://api.github.com/$1"
    else
        curl -fsSL -H "Accept: application/vnd.github+json" "https://api.github.com/$1"
    fi
}

# Latest release tag for a GitHub repo, e.g. github_latest_tag zellij-org/zellij
github_latest_tag() {
    github_api "repos/$1/releases/latest" | grep '"tag_name"' | head -n1 | cut -d'"' -f4
}

# ─── Checksums ────────────────────────────────────────────────────────────────

# SHA-256 of a file, lowercase hex. sha256sum on Linux, shasum on macOS.
sha256_file() {
    if command -v sha256sum >/dev/null 2>&1; then
        sha256sum "$1" | awk '{print $1}'
    else
        shasum -a 256 "$1" | awk '{print $1}'
    fi
}

# Fail unless <file> hashes to <expected>. An empty <expected> -- a checksum
# that could not be fetched -- is a failure too, not a pass.
verify_sha256() {
    local file="$1" expected="$2" actual
    if [ -z "$expected" ]; then
        warn "No published checksum found for $(basename "$file"); refusing to install it"
        return 1
    fi
    actual="$(sha256_file "$file")"
    if [ "$actual" != "$expected" ]; then
        warn "Checksum mismatch for $(basename "$file")"
        warn "  expected $expected"
        warn "  got      $actual"
        return 1
    fi
    info "sha256 verified: $(basename "$file")"
}

# The checksum for <name> from a `sha256sum`-style listing at <url> -- the
# checksums.txt / SHA-256.txt files most projects publish next to their
# release assets.
checksum_from_list() {
    local url="$1" name="$2"
    curl -fsSL "$url" | awk -v n="$name" '{ f = $2; sub(/^\*/, "", f) } f == n { print $1; exit }'
}
