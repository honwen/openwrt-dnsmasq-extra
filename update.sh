#!/bin/bash
#
# update.sh - Auto-check and upgrade versions in openwrt-dnsmasq-extra Makefiles
#
# Copyright (C) 2026 honwen <https://github.com/honwen>
#
# Usage:
#   ./update.sh                     # Check all packages for updates (dry-run)
#   ./update.sh --update            # Apply updates to all outdated packages
#   ./update.sh --pkg dnsproxy      # Check/update a specific package only
#   ./update.sh --update --pkg aiodns
#   ./update.sh --commit            # Check + auto-commit each update
#   ./update.sh --update --commit   # Update all + commit
#   ./update.sh --lock aiodns       # Pin a package (skip in future scans)
#   ./update.sh --unlock aiodns
#
# GitHub API token (optional, avoids rate limits):
#   export GITHUB_TOKEN=ghp_xxxx
#

set -euo pipefail

BASE_DIR="$(cd "$(dirname "$0")" && pwd)"
LOCK_FILE="${BASE_DIR}/.version-locks"
GITHUB_API="https://api.github.com"
TODAY="$(date +%Y%m%d)"
TODAY_DASH="$(date +%Y-%m-%d)"

# ─── colours ───────────────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

# ─── packages to skip entirely (no external upstream) ───────────────
SKIP_PACKAGES=()

# ─── version lock ──────────────────────────────────────────────────────────────
declare -A VERSION_LOCKS
load_locks() {
    VERSION_LOCKS=()
    if [[ -f "$LOCK_FILE" ]]; then
        while IFS= read -r line; do
            line="${line%%#*}"
            line="$(echo "$line" | xargs)"
            [[ -z "$line" ]] && continue
            local name="${line%%=*}"
            local ver="${line#*=}"
            [[ "$name" == "$ver" ]] && ver="*"
            VERSION_LOCKS["$name"]="$ver"
        done < "$LOCK_FILE"
    fi
}

is_locked() {
    local name="$1" current_ver="$2"
    local locked_ver="${VERSION_LOCKS[$name]:-}"
    [[ -z "$locked_ver" ]] && return 1
    [[ "$locked_ver" == "*" ]] && return 0
    [[ "$locked_ver" == "$current_ver" ]] && return 0
    return 1
}

lock_pkg() {
    local name="$1" ver="${2:-}"
    local entry="$name"
    [[ -n "$ver" ]] && entry="${name}=${ver}"
    if [[ -f "$LOCK_FILE" ]]; then
        grep -v "^${name}=" "$LOCK_FILE" | grep -v "^${name}$" > "${LOCK_FILE}.tmp" && mv "${LOCK_FILE}.tmp" "$LOCK_FILE"
    fi
    echo "$entry" >> "$LOCK_FILE"
    echo -e "${GREEN}locked${NC}  ${name}$([ -n "$ver" ] && echo " @ ${ver}")"
}

unlock_pkg() {
    local name="$1"
    if [[ -f "$LOCK_FILE" ]]; then
        grep -v "^${name}=" "$LOCK_FILE" | grep -v "^${name}$" > "${LOCK_FILE}.tmp" || true
        mv "${LOCK_FILE}.tmp" "$LOCK_FILE"
    fi
    echo -e "${YELLOW}unlocked${NC}  ${name}"
}

list_locks() {
    if [[ -f "$LOCK_FILE" ]] && [[ -s "$LOCK_FILE" ]]; then
        echo ""
        echo -e "${BOLD}version locks:${NC}"
        while IFS= read -r line; do
            line="${line%%#*}"
            line="$(echo "$line" | xargs)"
            [[ -z "$line" ]] && continue
            echo -e "  ${CYAN}🔒${NC} ${line}"
        done < "$LOCK_FILE"
        echo ""
    else
        echo ""
        echo -e "no version locks set."
        echo ""
    fi
}

# ─── flags ─────────────────────────────────────────────────────────────────────
DO_UPDATE=false
DO_COMMIT=false
TARGET_PKG=""
CHECK_ALL=true
DO_LOCK=false
DO_UNLOCK=false
LOCK_PKG_NAME=""
LOCK_PKG_VER=""

# ─── usage ─────────────────────────────────────────────────────────────────────
usage() {
    sed -n '2,15s/^# //p' "$0"
    exit 0
}

# ─── parse args ────────────────────────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
    case "$1" in
        --update|-u)    DO_UPDATE=true ;;
        --commit|-c)    DO_COMMIT=true ;;
        --pkg|-p)       TARGET_PKG="$2"; CHECK_ALL=false; shift ;;
        --lock|-l)      DO_LOCK=true; LOCK_PKG_NAME="$2"; shift ;;
        --unlock|-k)    DO_UNLOCK=true; LOCK_PKG_NAME="$2"; shift ;;
        --help|-h)      usage ;;
        *)              echo -e "${RED}Unknown option: $1${NC}"; usage ;;
    esac
    shift
done

load_locks

# ─── helpers ───────────────────────────────────────────────────────────────────

# Extract the first uncommented value of a Makefile variable.
make_get_var() {
    local f="$1" var="$2"
    grep -m1 "^${var}:=" "$f" 2>/dev/null | sed "s/^${var}:=//" | xargs
}

# Extract GitHub owner/repo from the Makefile.
# Handles both:
#   "https://github.com/AdguardTeam/dnsproxy/releases/download/v$(PKG_RELEASE)/"
#   "https://github.com/pymumu/smartdns.git"
make_get_github_repo() {
    local f="$1"
    local url raw_repo pkg_name

    url=$(grep -m1 '^PKG_SOURCE_URL:=https\?://github\.com/' "$f" 2>/dev/null)
    if [[ -z "$url" ]]; then
        echo ""
        return
    fi

    # Extract owner/repo from releases/download URL
    raw_repo=$(echo "$url" | sed -n 's|.*github\.com/\([^/]*/[^/]*\)/releases/download/.*|\1|p')
    if [[ -z "$raw_repo" ]]; then
        # Try git URL pattern: github.com/owner/repo.git
        raw_repo=$(echo "$url" | sed -n 's|.*github\.com/\([^/]*/[^/]*\)\.git.*|\1|p')
    fi

    # Expand $(PKG_NAME) if present
    if echo "$raw_repo" | grep -q '\$(PKG_NAME)'; then
        pkg_name=$(make_get_var "$f" "PKG_NAME")
        local search='$(PKG_NAME)'
        raw_repo="${raw_repo//$search/$pkg_name}"
    fi

    echo "$raw_repo"
}

# Determine package source type: "releases", "git", "generate", or "none"
make_get_source_type() {
    local f="$1"
    local dir
    dir="$(dirname "$f")"
    local url

    # Check for generate.sh first (generated data packages)
    if [[ -x "${dir}/generate.sh" ]]; then
        echo "generate"
        return
    fi

    url=$(grep -m1 '^PKG_SOURCE_URL:=' "$f" 2>/dev/null)

    if echo "$url" | grep -q '/releases/download/'; then
        echo "releases"
    elif echo "$url" | grep -q '\.git'; then
        echo "git"
    elif grep -qm1 '^PKG_SOURCE_PROTO:=git' "$f" 2>/dev/null; then
        echo "git"
    else
        echo "none"
    fi
}

# Determine which variable holds the upstream version by checking URL usage.
# Returns "PKG_VERSION", "PKG_RELEASE", or "composite" (both vars in URL).
make_get_upstream_var() {
    local f="$1" source_type="$2"
    local url

    if [[ "$source_type" == "releases" ]]; then
        url=$(grep -m1 '^PKG_SOURCE_URL:=' "$f" 2>/dev/null)
        local has_ver=false has_rel=false
        echo "$url" | grep -q '\$(PKG_VERSION)' && has_ver=true
        echo "$url" | grep -q '\$(PKG_RELEASE)' && has_rel=true
        if $has_ver && $has_rel; then
            echo "composite"
        elif $has_rel; then
            echo "PKG_RELEASE"
        else
            echo "PKG_VERSION"
        fi
    elif [[ "$source_type" == "git" ]]; then
        echo "PKG_RELEASE"
    else
        echo "PKG_VERSION"
    fi
}

# For composite tags: reconstruct the current full version string from the
# URL template by substituting actual PKG_VERSION and PKG_RELEASE values.
# E.g. template "build-$(PKG_VERSION)_$(PKG_RELEASE)" with ver=20220316 rel=1022
#      returns "build-20220316_1022"
make_get_composite_current() {
    local f="$1"
    local url ver rel
    url=$(grep -m1 '^PKG_SOURCE_URL:=' "$f" 2>/dev/null)
    ver=$(make_get_var "$f" "PKG_VERSION")
    rel=$(make_get_var "$f" "PKG_RELEASE")

    # Extract the tag portion from the URL (after "/download/" and before the next "/")
    local template
    template=$(echo "$url" | sed -n 's|.*/download/\(.*\)/.*|\1|p')
    [[ -z "$template" ]] && template=$(echo "$url" | sed -n 's|.*/download/\(.*\)|\1|p')

    # Substitute variables
    local result="$template"
    result="${result//\$(PKG_VERSION)/$ver}"
    result="${result//\$(PKG_RELEASE)/$rel}"
    echo "$result"
}

# For composite tags: parse a tag into PKG_VERSION and PKG_RELEASE parts
# using the URL template as a format string.
# Outputs two lines: PKG_VERSION value, then PKG_RELEASE value.
parse_composite_tag() {
    local f="$1" tag="$2"
    local url template
    url=$(grep -m1 '^PKG_SOURCE_URL:=' "$f" 2>/dev/null)
    template=$(echo "$url" | sed -n 's|.*/download/\(.*\)/.*|\1|p')
    [[ -z "$template" ]] && template=$(echo "$url" | sed -n 's|.*/download/\(.*\)|\1|p')

    # Build a sed pattern from the template to extract the two parts.
    # Escape regex special characters in the template except the variable placeholders.
    local pattern="$template"
    pattern="${pattern//\$(PKG_VERSION)/__PKG_VERSION__}"
    pattern="${pattern//\$(PKG_RELEASE)/__PKG_RELEASE__}"
    # Escape regex metacharacters
    pattern=$(echo "$pattern" | sed 's/[.[\*^$()+?{|]/\\&/g')
    # Put capture groups back
    pattern="${pattern//__PKG_VERSION__/\\(.*\\)}"
    pattern="${pattern//__PKG_RELEASE__/\\(.*\\)}"

    echo "$tag" | sed -n "s/^${pattern}$/\1/p"
    echo "$tag" | sed -n "s/^${pattern}$/\2/p"
}

# Check if a variable's value looks like a date stamp (YYYY-MM-DD or YYYYMMDD).
is_date_stamp() {
    local val="$1"
    [[ "$val" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]] && return 0
    [[ "$val" =~ ^[0-9]{8}$ ]] && return 0
    return 1
}

# Fetch the latest stable release tag for a GitHub repo.
# Uses git ls-remote (no rate limit) with GitHub API fallback.
# Returns the tag name as-is (caller handles prefix stripping).
github_latest_tag() {
    local owner_repo="$1" hint_prefix="${2:-}" hint_shape="${3:-}"
    local tag="" all_tags=""

    # ── method 1: git ls-remote ──────────────────────────────────────────
    # Use a temp variable to avoid pipefail issues with empty results
    all_tags=$(git ls-remote --tags "https://github.com/${owner_repo}.git" 2>/dev/null \
        | sed -n 's|.*refs/tags/||p' \
        | sed 's|\^{}||' \
        | grep -vE '(rc|alpha|beta|dev|pre|canary|nightly|not-quite|test|experimental|unstable|draft)' || true)

    if [[ -n "$all_tags" ]]; then
        # First, prefer tags matching the current version's shape (e.g. vYYYY.MMDD),
        # so legacy tags in a different format (v20220524) don't win sort -V
        if [[ -n "$hint_shape" ]]; then
            tag=$(echo "$all_tags" \
                | grep -E "^${hint_shape}$" \
                | sort -V | tail -1 2>/dev/null || true)
            tag="${tag:-}"
        fi

        # Next, try to match version-like tags (digits or v+digit)
        if [[ -z "$tag" ]]; then
            tag=$(echo "$all_tags" \
                | grep -E '^(v?[0-9]|[0-9])' \
                | sort -V | tail -1 2>/dev/null || true)
            tag="${tag:-}"
        fi

        # If no numeric tags, try the hint prefix (e.g., "Release", "build-")
        if [[ -z "$tag" ]] && [[ -n "$hint_prefix" ]]; then
            tag=$(echo "$all_tags" \
                | grep "^${hint_prefix}" \
                | sort -V | tail -1 2>/dev/null || true)
            tag="${tag:-}"
        fi

        # Last resort: take the last tag from sort -V of all tags
        if [[ -z "$tag" ]]; then
            tag=$(echo "$all_tags" | sort -V | tail -1 2>/dev/null || true)
            tag="${tag:-}"
        fi
    fi

    # ── method 2: fallback to GitHub API ─────────────────────────────────
    if [[ -z "$tag" ]]; then
        local url="${GITHUB_API}/repos/${owner_repo}/releases/latest"
        local curl_opts=(-s -f -L --connect-timeout 10 --max-time 15)
        local header=()

        if [[ -n "${GITHUB_TOKEN:-}" ]]; then
            header=(-H "Authorization: Bearer ${GITHUB_TOKEN}")
        fi

        local resp http_code
        resp=$(curl "${curl_opts[@]}" "${header[@]}" -w '\n%{http_code}' "$url" 2>/dev/null) || true
        resp="${resp:-}"
        http_code=$(echo "$resp" | tail -1)
        resp=$(echo "$resp" | sed '$d')

        if [[ "$http_code" != "200" ]]; then
            echo ""
            return 0
        fi

        tag=$(echo "$resp" | grep -m1 '"tag_name"' | sed 's/.*"tag_name": *"\([^"]*\)".*/\1/')
        tag="${tag:-}"
    fi

    [[ -z "$tag" ]] && { echo ""; return 0; }
    echo "$tag"
}

# Get the HEAD commit hash for a GitHub repo (default branch).
github_head_commit() {
    local owner_repo="$1"
    git ls-remote "https://github.com/${owner_repo}.git" HEAD 2>/dev/null \
        | awk '{print $1}' \
        | head -1
}

# Get the UTC committer date (YYYY-MM-DD) of a commit via the GitHub API.
# Prints "" on failure (caller falls back to TODAY_DASH).
github_commit_date() {
    local owner_repo="$1" commit="$2"
    local curl_opts=(-s -f -L --connect-timeout 10 --max-time 15)
    local header=()
    [[ -n "${GITHUB_TOKEN:-}" ]] && header=(-H "Authorization: Bearer ${GITHUB_TOKEN}")
    local resp
    resp=$(curl "${curl_opts[@]}" "${header[@]}" \
        "${GITHUB_API}/repos/${owner_repo}/commits/${commit}" 2>/dev/null) || true
    [[ -z "$resp" ]] && { echo ""; return 0; }
    local date
    date=$(echo "$resp" | grep -m1 -A3 '"committer"' | grep -m1 '"date"' | sed 's/.*"date": *"\([^"]*\)".*/\1/')
    [[ -z "$date" ]] && date=$(echo "$resp" | grep -m1 '"date"' | sed 's/.*"date": *"\([^"]*\)".*/\1/')
    echo "${date%%T*}"
}

# Get the commit hash for a specific tag from git ls-remote.
# Annotated tags are dereferenced (refs/tags/X^{}) to the commit they point to.
github_tag_commit() {
    local owner_repo="$1" tag="$2"
    local out commit
    # Query the tag and its ^{} peel explicitly: an exact tag pattern alone
    # does not return the deref line of annotated tags
    out=$(git ls-remote --tags "https://github.com/${owner_repo}.git" "refs/tags/${tag}^{}" "refs/tags/${tag}" 2>/dev/null)
    commit=$(echo "$out" | grep -F '^{}' | awk '{print $1}' | head -1)
    [[ -z "$commit" ]] && commit=$(echo "$out" | awk '{print $1}' | head -1)
    echo "$commit"
}

# Find the highest (sort -V) tag pointing at the given commit.
# Optional hint_prefix restricts matches (e.g. "Release"); pre-release-style
# tags (nightly, rc, ...) are excluded. Prints "" if no tag matches.
github_tag_at_commit() {
    local owner_repo="$1" commit="$2" hint_prefix="${3:-}"
    local tags
    tags=$(git ls-remote --tags "https://github.com/${owner_repo}.git" 2>/dev/null \
        | awk -v c="$commit" '$1 == c {print $2}' \
        | sed -n 's|refs/tags/||p' \
        | sed 's|\^{}||' \
        | grep -vE '(rc|alpha|beta|dev|pre|canary|nightly|not-quite|test|experimental|unstable|draft)' || true)
    [[ -z "$tags" ]] && { echo ""; return 0; }
    if [[ -n "$hint_prefix" ]]; then
        tags=$(echo "$tags" | grep "^${hint_prefix}" || true)
    fi
    [[ -z "$tags" ]] && { echo ""; return 0; }
    echo "$tags" | sort -V | tail -1
}

# Strip leading 'v'/'V' from a version string (for releases-based packages).
# For git-based packages or non-standard tags, returns the tag as-is.
strip_version_prefix() {
    local tag="$1"
    # Only strip 'v'/'V' if the tag looks like a version (v+digits)
    if [[ "$tag" =~ ^[vV][0-9] ]]; then
        tag="${tag#v}"
        tag="${tag#V}"
    fi
    echo "$tag"
}

# Build a regex matching tags of the same "shape" as the given version:
# digit runs become [0-9]+, dots escaped, leading v/V made optional.
# E.g. "v2025.1121" -> "[vV]?[0-9]+\.[0-9]+"  (excludes old "v20220524"-style tags)
version_shape_re() {
    local ver="${1#[vV]}"
    ver="${ver//./\\.}"
    ver=$(echo "$ver" | sed 's/[0-9]\+/[0-9]+/g')
    echo "[vV]?${ver}"
}

# Compare two version strings using sort -V.
# Returns 0 (true) if $1 < $2 (i.e. an update is available).
version_lt() {
    local a="$1" b="$2"
    [[ "$a" != "$b" ]] && [[ "$(printf '%s\n%s\n' "$a" "$b" | sort -V | head -1)" == "$a" ]]
}

# ─── API cache ─────────────────────────────────────────────────────────────────
declare -A TAG_CACHE
declare -A COMMIT_CACHE

# ─── process a "generate" type package (data generated by generate.sh) ──────────
# Returns: 0 = up-to-date, 1 = error, 2 = update available, 3 = locked
process_generate() {
    local dir="$1" mf="$2" pkg_name="$3" pkg_dir="$4"
    local gen_script="${dir}/generate.sh"

    local current_date
    current_date=$(make_get_var "$mf" "PKG_VERSION")

    if [[ -z "$current_date" ]]; then
        echo -e "  ${YELLOW}skip${NC}  ${pkg_dir} (${pkg_name}): PKG_VERSION not found"
        return 1
    fi

    # Check version lock
    if is_locked "$pkg_name" "$current_date"; then
        local lock_info="🔒"
        [[ "${VERSION_LOCKS[$pkg_name]}" != "*" ]] && lock_info="🔒 @${VERSION_LOCKS[$pkg_name]}"
        echo -e "  ${CYAN}lock${NC}  ${pkg_dir} (${pkg_name}): ${current_date} ${lock_info}"
        return 3
    fi

    # Compare date stamps: YYYY-MM-DD format
    if [[ "$current_date" != "$TODAY_DASH" ]]; then
        echo -e "  ${GREEN}UPDATE${NC} ${pkg_dir} (${pkg_name}): data ${current_date} -> ${BOLD}${TODAY_DASH}${NC}  [generate.sh]"

        if $DO_UPDATE; then
            echo -e "         -> running ${gen_script}..."
            if bash "$gen_script"; then
                echo -e "         -> ${GREEN}generate.sh completed, PKG_VERSION -> ${TODAY_DASH}${NC}"

                if $DO_COMMIT; then
                    local msg="update data: ${pkg_name} @${TODAY_DASH}"
                    git -C "$BASE_DIR" add "${dir}/"
                    if git -C "$BASE_DIR" diff --cached --quiet; then
                        echo -e "         -> ${YELLOW}no changes to commit${NC}"
                    else
                        git -C "$BASE_DIR" commit -m "${msg}" \
                            -m "Regenerated data files via generate.sh" \
                            -m "Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>" \
                            >/dev/null 2>&1
                        echo -e "         -> ${GREEN}committed: ${msg}${NC}"
                    fi
                fi
            else
                echo -e "         -> ${RED}generate.sh failed${NC}"
                return 1
            fi
        fi
        return 2
    else
        echo -e "  ok     ${pkg_dir} (${pkg_name}): ${current_date}  [generate.sh]"
        return 0
    fi
}

# ─── process one Makefile ──────────────────────────────────────────────────────
# Returns: 0 = up-to-date, 1 = skipped/error, 2 = update available, 3 = locked
process_makefile() {
    local dir="$1"
    local mf="${dir}/Makefile"
    local pkg_dir
    pkg_dir="$(basename "$dir")"

    # Parse Makefile
    local pkg_name source_type upstream_var current_ver github_repo
    pkg_name=$(make_get_var "$mf" "PKG_NAME")
    source_type=$(make_get_source_type "$mf")
    github_repo=$(make_get_github_repo "$mf")

    if [[ -z "$pkg_name" ]]; then
        echo -e "  ${YELLOW}skip${NC}  ${pkg_dir}: PKG_NAME not found"
        return 1
    fi

    # Skip internal packages
    for skip in "${SKIP_PACKAGES[@]}"; do
        if [[ "$pkg_name" == "$skip" ]]; then
            echo -e "  ${YELLOW}skip${NC}  ${pkg_dir} (${pkg_name}): internal package, no external upstream"
            return 1
        fi
    done

    # ── handle "generate" type (data packages with generate.sh) ─────────
    if [[ "$source_type" == "generate" ]]; then
        process_generate "$dir" "$mf" "$pkg_name" "$pkg_dir"
        return $?
    fi

    if [[ "$source_type" == "none" ]]; then
        echo -e "  ${YELLOW}skip${NC}  ${pkg_dir} (${pkg_name}): no GitHub source URL found"
        return 1
    fi

    if [[ -z "$github_repo" ]]; then
        echo -e "  ${YELLOW}skip${NC}  ${pkg_dir} (${pkg_name}): unable to parse GitHub repo"
        return 1
    fi

    # Determine current upstream version
    upstream_var=$(make_get_upstream_var "$mf" "$source_type")
    local is_composite=false

    if [[ "$upstream_var" == "composite" ]]; then
        is_composite=true
        # For composite tags, the "current version" is the full reconstructed tag
        current_ver=$(make_get_composite_current "$mf")
    elif [[ "$source_type" == "releases" ]]; then
        current_ver=$(make_get_var "$mf" "$upstream_var")
    else
        # For git-based packages, track the latest HEAD commit
        current_ver=$(make_get_var "$mf" "PKG_SOURCE_VERSION")
        # Resolve $(PKG_RELEASE) reference if present
        if echo "$current_ver" | grep -q '\$(PKG_RELEASE)'; then
            local rel_val
            rel_val=$(make_get_var "$mf" "PKG_RELEASE")
            current_ver="${current_ver//\$(PKG_RELEASE)/$rel_val}"
        fi
        # Fallback: if no PKG_SOURCE_VERSION, use PKG_RELEASE (may be a commit hash)
        [[ -z "$current_ver" ]] && current_ver=$(make_get_var "$mf" "PKG_RELEASE")
        upstream_var="PKG_SOURCE_VERSION"
        [[ -z "$current_ver" ]] && upstream_var="PKG_RELEASE"
    fi

    if [[ -z "$current_ver" ]]; then
        echo -e "  ${YELLOW}skip${NC}  ${pkg_dir} (${pkg_name}): ${upstream_var} not found"
        return 1
    fi

    # Check version lock (use the display version: for composites, use PKG_VERSION)
    local lock_ver="$current_ver"
    if $is_composite; then
        lock_ver=$(make_get_var "$mf" "PKG_VERSION")
    elif [[ "$source_type" == "git" ]]; then
        # For git packages, lock by PKG_RELEASE (the human-readable version tag)
        local rel_ver
        rel_ver=$(make_get_var "$mf" "PKG_RELEASE")
        [[ -n "$rel_ver" ]] && lock_ver="$rel_ver"
    fi
    if is_locked "$pkg_name" "$lock_ver"; then
        local lock_info="🔒"
        [[ "${VERSION_LOCKS[$pkg_name]}" != "*" ]] && lock_info="🔒 @${VERSION_LOCKS[$pkg_name]}"
        echo -e "  ${CYAN}lock${NC}  ${pkg_dir} (${pkg_name}): ${lock_ver} ${lock_info}"
        return 3
    fi

    # Determine the tag prefix hint (for non-standard tag formats)
    local hint_prefix=""
    if $is_composite; then
        # For composite tags, extract the literal prefix from the URL template
        local url
        url=$(grep -m1 '^PKG_SOURCE_URL:=' "$mf" 2>/dev/null)
        local template
        template=$(echo "$url" | sed -n 's|.*/download/\(.*\)/.*|\1|p')
        [[ -z "$template" ]] && template=$(echo "$url" | sed -n 's|.*/download/\(.*\)|\1|p')
        # Extract the literal prefix before $(PKG_VERSION)
        hint_prefix="${template%%\$(*}"
    elif [[ "$source_type" == "releases" ]]; then
        local url
        url=$(grep -m1 '^PKG_SOURCE_URL:=' "$mf" 2>/dev/null)
        if echo "$url" | grep -q "v\$(PKG_RELEASE)"; then
            hint_prefix="v"
        elif echo "$url" | grep -q "v\$(PKG_VERSION)"; then
            hint_prefix="v"
        fi
    fi

    # ── fetch latest version ──────────────────────────────────────────────
    local latest_tag="" latest_ver=""

    if [[ "$source_type" == "git" ]]; then
        # Git-based packages: fetch latest HEAD commit
        local cache_key="${github_repo}|HEAD"
        local latest_commit
        if [[ -n "${COMMIT_CACHE[$cache_key]:-}" ]]; then
            latest_commit="${COMMIT_CACHE[$cache_key]}"
        else
            latest_commit=$(github_head_commit "$github_repo")
            COMMIT_CACHE[$cache_key]="$latest_commit"
        fi

        if [[ -z "$latest_commit" ]]; then
            echo -e "  ${RED}fail${NC}  ${pkg_dir} (${pkg_name}): unable to fetch HEAD commit from ${github_repo}"
            return 1
        fi

        latest_ver="$latest_commit"

        # If PKG_RELEASE holds an upstream tag (not a commit hash), resolve the
        # tag pointing at the tracked commit so PKG_RELEASE can be synced too
        # (e.g. smartdns: Release48.3 -> Release48.4 on the same commit).
        local pkg_rel latest_rel_tag=""
        pkg_rel=$(make_get_var "$mf" "PKG_RELEASE")
        if [[ -n "$pkg_rel" ]] && [[ ! "$pkg_rel" =~ ^[0-9a-f]{7,40}$ ]]; then
            latest_rel_tag=$(github_tag_at_commit "$github_repo" "$latest_commit" "${pkg_rel%%[0-9]*}")
        fi

        # The PKG_VERSION date stamp tracks the upstream commit date
        local cur_pkg_ver latest_commit_date=""
        cur_pkg_ver=$(make_get_var "$mf" "PKG_VERSION")
        if is_date_stamp "$cur_pkg_ver"; then
            latest_commit_date=$(github_commit_date "$github_repo" "$latest_commit")
        fi

        # Compare commit hashes directly (string comparison)
        if [[ "$current_ver" != "$latest_ver" ]]; then
            local display_cur="${current_ver:0:10}"
            local display_new="${latest_ver:0:10}"
            local rel_disp=""
            [[ -n "$latest_rel_tag" && "$latest_rel_tag" != "$pkg_rel" ]] && rel_disp=" -> ${latest_rel_tag}"
            echo -e "  ${GREEN}UPDATE${NC} ${pkg_dir} (${pkg_name}): ${display_cur}... -> ${BOLD}${display_new}...${NC}  [${github_repo}#${pkg_rel}${rel_disp}]"

            if $DO_UPDATE; then
                apply_update "$dir" "$mf" "$source_type" "PKG_SOURCE_VERSION" \
                    "$current_ver" "$latest_ver" "$latest_tag" "$pkg_name" "$github_repo" "false" "$latest_rel_tag" "$latest_commit_date"
            fi
            return 2
        else
            # Commit unchanged: sync tag (PKG_RELEASE) / date (PKG_VERSION) if stale
            local reason=""
            if [[ -n "$latest_rel_tag" && "$latest_rel_tag" != "$pkg_rel" ]]; then
                reason="tag ${pkg_rel} -> ${latest_rel_tag}"
            fi
            if [[ -n "$latest_commit_date" && "$latest_commit_date" != "$cur_pkg_ver" ]]; then
                reason="${reason:+$reason, }date ${cur_pkg_ver} -> ${latest_commit_date}"
            fi
            if [[ -z "$reason" ]]; then
                echo -e "  ok     ${pkg_dir} (${pkg_name}): ${current_ver:0:10}...  [${github_repo}#${pkg_rel}]"
                return 0
            fi
            echo -e "  ${GREEN}UPDATE${NC} ${pkg_dir} (${pkg_name}): ${reason}  [${github_repo} @ ${current_ver:0:10}]"

            if $DO_UPDATE; then
                apply_update "$dir" "$mf" "$source_type" "PKG_SOURCE_VERSION" \
                    "$current_ver" "$latest_ver" "$latest_tag" "$pkg_name" "$github_repo" "false" "$latest_rel_tag" "$latest_commit_date"
            fi
            return 2
        fi
    else
        # Releases-based / composite: fetch latest tag
        # Restrict candidates to the current version's tag shape (e.g. vYYYY.MMDD)
        local hint_shape
        hint_shape=$(version_shape_re "$current_ver")
        local cache_key="${github_repo}|${hint_prefix}|${hint_shape}"
        if [[ -n "${TAG_CACHE[$cache_key]:-}" ]]; then
            latest_tag="${TAG_CACHE[$cache_key]}"
        else
            latest_tag=$(github_latest_tag "$github_repo" "$hint_prefix" "$hint_shape")
            TAG_CACHE[$cache_key]="$latest_tag"
        fi

        if [[ -z "$latest_tag" ]]; then
            echo -e "  ${RED}fail${NC}  ${pkg_dir} (${pkg_name}): unable to fetch latest tag from ${github_repo}"
            return 1
        fi

        if $is_composite; then
            latest_ver="$latest_tag"
        else
            latest_ver=$(strip_version_prefix "$latest_tag")
        fi

        # Resolve the tag's commit date — it drives the date-stamp variable
        # (non-composite only; composite versions come from the tag itself)
        local rel_date_var="" rel_date_cur="" latest_tag_date=""
        if ! $is_composite; then
            if [[ "$upstream_var" == "PKG_VERSION" ]]; then rel_date_var="PKG_RELEASE"; else rel_date_var="PKG_VERSION"; fi
            rel_date_cur=$(make_get_var "$mf" "$rel_date_var")
            if is_date_stamp "$rel_date_cur"; then
                local tag_commit
                tag_commit=$(github_tag_commit "$github_repo" "$latest_tag")
                [[ -n "$tag_commit" ]] && latest_tag_date=$(github_commit_date "$github_repo" "$tag_commit")
            fi
        fi

        # Compare prefix-normalized versions: the current value may carry a
        # 'v' prefix while latest_ver is stripped (e.g. aiodns v2025.1121)
        local cmp_cur
        cmp_cur=$(strip_version_prefix "$current_ver")

        if version_lt "$cmp_cur" "$latest_ver"; then
            local display_cur="$current_ver"
            $is_composite && display_cur="$(make_get_var "$mf" PKG_VERSION)/$(make_get_var "$mf" PKG_RELEASE)"
            local display_new="$latest_ver"
            [[ "$current_ver" =~ ^[vV][0-9] ]] && display_new="$latest_tag"
            echo -e "  ${GREEN}UPDATE${NC} ${pkg_dir} (${pkg_name}): ${display_cur} -> ${BOLD}${display_new}${NC}  [${github_repo}]"

            if $DO_UPDATE; then
                apply_update "$dir" "$mf" "$source_type" "$upstream_var" \
                    "$current_ver" "$latest_ver" "$latest_tag" "$pkg_name" "$github_repo" "$is_composite" "" "$latest_tag_date"
            fi
            return 2
        fi

        # Version current: sync the date-stamp var with the tag's commit date
        if [[ -n "$latest_tag_date" && -n "$rel_date_cur" ]]; then
            local want_date="$latest_tag_date"
            [[ "$rel_date_cur" =~ ^[0-9]{8}$ ]] && want_date="${latest_tag_date//-/}"
            if [[ "$rel_date_cur" != "$want_date" ]]; then
                echo -e "  ${GREEN}UPDATE${NC} ${pkg_dir} (${pkg_name}): date ${rel_date_cur} -> ${BOLD}${want_date}${NC}  [${github_repo} @ ${latest_ver}]"
                if $DO_UPDATE; then
                    apply_update "$dir" "$mf" "$source_type" "$upstream_var" \
                        "$current_ver" "$current_ver" "$latest_tag" "$pkg_name" "$github_repo" "$is_composite" "" "$latest_tag_date"
                fi
                return 2
            fi
        fi

        echo -e "  ok     ${pkg_dir} (${pkg_name}): ${current_ver}  [${github_repo}]"
        return 0
    fi
}

# ─── apply update to Makefile ──────────────────────────────────────────────────
apply_update() {
    local dir="$1" mf="$2" source_type="$3" upstream_var="$4"
    local old_ver="$5" new_ver="$6" new_tag="$7"
    local pkg_name="$8" github_repo="$9" is_composite="${10:-false}"
    local rel_tag="${11:-}" new_date="${12:-}"

    local extra_info=""

    if $is_composite; then
        # ── composite tag (both PKG_VERSION and PKG_RELEASE in URL) ──────
        local new_pkg_ver new_pkg_rel
        new_pkg_ver=$(parse_composite_tag "$mf" "$new_tag" | head -1)
        new_pkg_rel=$(parse_composite_tag "$mf" "$new_tag" | tail -1)

        if [[ -n "$new_pkg_ver" ]] && [[ -n "$new_pkg_rel" ]]; then
            sed -i "s/^\(PKG_VERSION:=\).*/\1${new_pkg_ver}/" "$mf"
            sed -i "s/^\(PKG_RELEASE:=\).*/\1${new_pkg_rel}/" "$mf"
            extra_info="PKG_VERSION -> ${new_pkg_ver}, PKG_RELEASE -> ${new_pkg_rel}"
        else
            echo -e "         -> ${RED}failed to parse composite tag: ${new_tag}${NC}"
            return 1
        fi

    elif [[ "$source_type" == "releases" ]]; then
        # ── standard releases-based packages ──────────────────────────────
        # Preserve a 'v' prefix if the current value carries one (e.g. aiodns)
        local write_ver="$new_ver"
        [[ "$old_ver" =~ ^[vV][0-9] ]] && write_ver="$new_tag"
        sed -i "s/^\(${upstream_var}:=\).*/\1${write_ver}/" "$mf"
        new_ver="$write_ver"

        # Sync the "other" variable:
        #  - date stamp  -> the tag's commit date (fallback: today)
        #  - commit hash -> the tag's commit hash, same length (e.g. aiodns asset suffix)
        local other_var other_old
        if [[ "$upstream_var" == "PKG_VERSION" ]]; then other_var="PKG_RELEASE"; else other_var="PKG_VERSION"; fi
        other_old=$(make_get_var "$mf" "$other_var")
        if is_date_stamp "$other_old"; then
            local stamp="$new_date"
            if [[ "$other_old" =~ ^[0-9]{8}$ ]]; then
                stamp="${stamp//-/}"
                stamp="${stamp:-$TODAY}"
            else
                stamp="${stamp:-$TODAY_DASH}"
            fi
            if [[ "$stamp" != "$other_old" ]]; then
                sed -i "s/^\(${other_var}:=\).*/\1${stamp}/" "$mf"
                extra_info="${extra_info}, ${other_var} -> ${stamp}"
            fi
        elif [[ "$other_old" =~ ^[0-9a-f]{7,12}$ ]]; then
            local new_commit new_hash
            new_commit=$(github_tag_commit "$github_repo" "$new_tag")
            if [[ -n "$new_commit" ]]; then
                new_hash="${new_commit:0:${#other_old}}"
                if [[ "$new_hash" != "$other_old" ]]; then
                    sed -i "s/^\(${other_var}:=\).*/\1${new_hash}/" "$mf"
                    extra_info="${extra_info}, ${other_var} -> ${new_hash}"
                fi
            fi
        fi

    elif [[ "$source_type" == "git" ]]; then
        # ── git-based packages: update to latest HEAD commit ─────────────
        # Check if PKG_SOURCE_VERSION references $(PKG_RELEASE)
        local sv_val
        sv_val=$(make_get_var "$mf" "PKG_SOURCE_VERSION")
        if echo "$sv_val" | grep -q '\$(PKG_RELEASE)'; then
            # PKG_SOURCE_VERSION points to PKG_RELEASE; update PKG_RELEASE instead
            sed -i "s/^\(PKG_RELEASE:=\).*/\1${new_ver}/" "$mf"
            extra_info="PKG_RELEASE -> ${new_ver:0:10}..."
        elif grep -qm1 '^PKG_SOURCE_VERSION:=' "$mf" 2>/dev/null; then
            # Direct PKG_SOURCE_VERSION; update it (skip if unchanged — tag-only sync)
            if [[ "$sv_val" != "$new_ver" ]]; then
                sed -i "s/^\(PKG_SOURCE_VERSION:=\).*/\1${new_ver}/" "$mf"
                extra_info="PKG_SOURCE_VERSION -> ${new_ver:0:10}..."
            fi
        fi

        # Sync tag-like PKG_RELEASE with the tag pointing at the tracked commit
        if [[ -n "$rel_tag" ]]; then
            local cur_rel
            cur_rel=$(make_get_var "$mf" "PKG_RELEASE")
            if [[ -n "$cur_rel" ]] && [[ "$rel_tag" != "$cur_rel" ]]; then
                sed -i "s/^\(PKG_RELEASE:=\).*/\1${rel_tag}/" "$mf"
                extra_info="${extra_info}, PKG_RELEASE -> ${rel_tag}"
            fi
        fi

        # Update date stamp in PKG_VERSION (tracks the upstream commit date)
        if grep -qm1 '^PKG_VERSION:=' "$mf" 2>/dev/null; then
            local cur_date_var
            cur_date_var=$(make_get_var "$mf" "PKG_VERSION")
            if is_date_stamp "$cur_date_var"; then
                local stamp="${new_date:-$TODAY_DASH}"
                if [[ "$stamp" != "$cur_date_var" ]]; then
                    sed -i "s/^\(PKG_VERSION:=\).*/\1${stamp}/" "$mf"
                    extra_info="${extra_info}, PKG_VERSION -> ${stamp}"
                fi
            fi
        fi

        # Keep PKG_RELEASE unchanged for non-reference case (release tag)
    fi

    if [[ "$old_ver" == "$new_ver" ]]; then
        echo -e "         -> synced${extra_info#,}"
    else
        echo -e "         -> updated ${upstream_var} to ${new_ver}${extra_info}"
    fi

    if $DO_COMMIT; then
        local msg="bump ${pkg_name} ${old_ver:0:10} -> ${new_ver:0:10}"
        if [[ "$old_ver" == "$new_ver" ]]; then
            msg="bump ${pkg_name}${extra_info:+:${extra_info#,}} (sync)"
        fi
        git -C "$BASE_DIR" add "${dir}/Makefile"
        if git -C "$BASE_DIR" diff --cached --quiet; then
            echo -e "         -> ${YELLOW}no changes to commit${NC}"
        else
            local source_ref="Source: https://github.com/${github_repo}/releases/tag/${new_tag}"
            if [[ "$source_type" == "git" ]]; then
                source_ref="Source: https://github.com/${github_repo}/commit/${new_ver}"
            fi
            git -C "$BASE_DIR" commit -m "${msg}" \
                -m "${source_ref}" \
                -m "Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>" \
                >/dev/null 2>&1
            echo -e "         -> ${GREEN}committed: ${msg}${NC}"
        fi
    fi
}

# ─── main ──────────────────────────────────────────────────────────────────────
main() {
    if $DO_LOCK; then
        load_locks
        lock_pkg "$LOCK_PKG_NAME"
        exit 0
    fi
    if $DO_UNLOCK; then
        load_locks
        unlock_pkg "$LOCK_PKG_NAME"
        exit 0
    fi

    list_locks

    echo -e "${BOLD}openwrt-dnsmasq-extra :: version check${NC}"
    echo -e "date: ${TODAY_DASH}  |  mode: $($DO_UPDATE && echo 'update' || echo 'dry-run')$($DO_COMMIT && echo ' + commit')"
    echo ""

    local dirs=()
    if $CHECK_ALL; then
        for d in "$BASE_DIR"/*/; do
            local name
            name="$(basename "$d")"
            # Skip hidden directories and deprecated
            [[ "$name" == .* ]] && continue
            [[ "$name" == ".deprecated" ]] && continue
            [[ -f "${d}/Makefile" ]] && dirs+=("$d")
        done
    else
        local d="${BASE_DIR}/${TARGET_PKG}"
        if [[ -d "$d" ]] && [[ -f "${d}/Makefile" ]]; then
            dirs+=("$d")
        else
            echo -e "${RED}Error: package '${TARGET_PKG}' not found${NC}"
            exit 1
        fi
    fi

    # Split into regular and generate dirs; generate (dnsmasq-extra) runs last
    local regular_dirs=() generate_dirs=()
    for d in "${dirs[@]}"; do
        if [[ -x "${d}/generate.sh" ]]; then
            generate_dirs+=("$d")
        else
            regular_dirs+=("$d")
        fi
    done

    # Sort each group for consistent output
    readarray -t regular_dirs < <(printf '%s\n' "${regular_dirs[@]}" | sort)
    readarray -t generate_dirs < <(printf '%s\n' "${generate_dirs[@]}" | sort)

    local total=0 skipped=0 updates=0 locked=0
    for d in "${regular_dirs[@]}" "${generate_dirs[@]}"; do
        local rc=0
        process_makefile "$d" || rc=$?
        total=$((total + 1))
        case $rc in
            0)  ;;
            1)  skipped=$((skipped + 1)) ;;
            2)  updates=$((updates + 1)) ;;
            3)  locked=$((locked + 1)) ;;
        esac
    done

    echo ""
    echo -e "${BOLD}Summary:${NC} ${total} packages scanned, ${GREEN}${updates}${NC} update(s) available"
    if [[ $locked -gt 0 ]]; then
        echo -e "         ${CYAN}${locked}${NC} locked (skipped)"
    fi
    if [[ $skipped -gt 0 ]]; then
        echo -e "         ${YELLOW}${skipped}${NC} skipped (no releases source / internal package / API error)"
    fi

    if [[ $updates -gt 0 ]] && ! $DO_UPDATE; then
        echo ""
        echo -e "Run ${CYAN}./update.sh --update${NC} to apply these updates."
    fi
    echo ""
}

main