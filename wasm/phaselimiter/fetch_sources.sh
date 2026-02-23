#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SOURCE_ROOT="${1:-$SCRIPT_DIR/src_original}"
REPOSITORY_URL="${PHASELIMITER_REPO_URL:-https://github.com/ai-mastering/phaselimiter.git}"
PINNED_COMMIT="${PHASELIMITER_PINNED_COMMIT:-3c951f40ea7e95e08c23c7b5654430f333939698}"
PINNED_TREE="${PHASELIMITER_PINNED_TREE:-ae5bf02a1380ac1edbff9ada0fee6d9bc32c78ea}"
BOOST_ARCHIVE_URL="${BOOST_ARCHIVE_URL:-https://archives.boost.io/release/1.89.0/source/boost_1_89_0.tar.gz}"
BOOST_ARCHIVE_SHA256="${BOOST_ARCHIVE_SHA256:-9de758db755e8330a01d995b0a24d09798048400ac25c03fc5ea9be364b13c93}"
FORCE_FETCH="${FORCE_FETCH:-0}"

if [[ "${2:-}" == "--force" ]]; then
  FORCE_FETCH=1
fi

require_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Missing required command: $1" >&2
    exit 1
  fi
}

already_pinned() {
  local manifest="$SOURCE_ROOT/.slowverb_source_pin.json"
  [[ -f "$manifest" ]] || return 1
  [[ -f "$SOURCE_ROOT/boost_1_89_0/boost/version.hpp" ]] || return 1
  [[ -f "$SOURCE_ROOT/src/phase_limiter/auto_mastering5.cpp" ]] || return 1
  grep -q "\"pinnedCommit\": \"$PINNED_COMMIT\"" "$manifest" &&
    grep -q "\"pinnedTree\": \"$PINNED_TREE\"" "$manifest" &&
    grep -q "\"boostArchiveSha256\": \"${BOOST_ARCHIVE_SHA256,,}\"" "$manifest"
}

require_command git
require_command tar
require_command curl
require_command sha256sum

if [[ "$FORCE_FETCH" != "1" && -d "$SOURCE_ROOT" ]] && already_pinned; then
  echo "PhaseLimiter source tree already pinned and verified: $SOURCE_ROOT"
  exit 0
fi

tmp_dir="$(mktemp -d)"
checkout_dir="$tmp_dir/checkout"
boost_archive="$tmp_dir/boost_1_89_0.tar.gz"
mkdir -p "$checkout_dir"

cleanup() {
  rm -rf "$tmp_dir"
}
trap cleanup EXIT

echo "Fetching PhaseLimiter commit $PINNED_COMMIT from $REPOSITORY_URL..."
git init -q "$checkout_dir"
git -C "$checkout_dir" remote add origin "$REPOSITORY_URL"
git -C "$checkout_dir" fetch --depth 1 origin "$PINNED_COMMIT"
git -C "$checkout_dir" checkout -q --detach FETCH_HEAD

actual_commit="$(git -C "$checkout_dir" rev-parse HEAD)"
actual_tree="$(git -C "$checkout_dir" rev-parse "HEAD^{tree}")"

if [[ "$actual_commit" != "$PINNED_COMMIT" ]]; then
  echo "Pinned commit mismatch. Expected $PINNED_COMMIT, got $actual_commit." >&2
  exit 1
fi
if [[ "$actual_tree" != "$PINNED_TREE" ]]; then
  echo "Pinned tree checksum mismatch. Expected $PINNED_TREE, got $actual_tree." >&2
  exit 1
fi

echo "Updating PhaseLimiter submodules recursively..."
git -C "$checkout_dir" submodule update --init --recursive --depth 1

echo "Downloading Boost archive with checksum verification..."
curl -L --fail --silent --show-error "$BOOST_ARCHIVE_URL" -o "$boost_archive"
actual_boost_hash="$(sha256sum "$boost_archive" | awk '{print tolower($1)}')"

if [[ "$actual_boost_hash" != "${BOOST_ARCHIVE_SHA256,,}" ]]; then
  echo "Boost checksum mismatch. Expected ${BOOST_ARCHIVE_SHA256,,}, got $actual_boost_hash." >&2
  exit 1
fi

tar -xzf "$boost_archive" -C "$checkout_dir"

if [[ ! -f "$checkout_dir/boost_1_89_0/boost/version.hpp" ]]; then
  echo "Extracted Boost tree missing expected files." >&2
  exit 1
fi
if [[ ! -f "$checkout_dir/src/phase_limiter/auto_mastering5.cpp" ]]; then
  echo "Fetched source missing expected file: src/phase_limiter/auto_mastering5.cpp" >&2
  exit 1
fi

rm -rf "$SOURCE_ROOT"
mkdir -p "$SOURCE_ROOT"
(cd "$checkout_dir" && tar --exclude=.git -cf - .) | (cd "$SOURCE_ROOT" && tar -xf -)

cat >"$SOURCE_ROOT/.slowverb_source_pin.json" <<JSON
{
  "repository": "$REPOSITORY_URL",
  "pinnedCommit": "$PINNED_COMMIT",
  "pinnedTree": "$PINNED_TREE",
  "boostArchiveUrl": "$BOOST_ARCHIVE_URL",
  "boostArchiveSha256": "${BOOST_ARCHIVE_SHA256,,}"
}
JSON

echo "PhaseLimiter source bootstrap completed: $SOURCE_ROOT"
