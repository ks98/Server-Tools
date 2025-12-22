#!/usr/bin/env bash
set -euo pipefail

REPO_URL_DEFAULT="https://github.com/ks98/Server-Tools.git"
REPO_REF_DEFAULT="main"
REPO_TARBALL_URL_DEFAULT=""

REPO_URL="${REPO_URL:-$REPO_URL_DEFAULT}"
REPO_REF="${REPO_REF:-$REPO_REF_DEFAULT}"
REPO_TARBALL_URL="${REPO_TARBALL_URL:-$REPO_TARBALL_URL_DEFAULT}"

SCRIPT_SOURCE="${BASH_SOURCE[0]:-}"
if [[ -n "$SCRIPT_SOURCE" && -f "$SCRIPT_SOURCE" ]]; then
  SCRIPT_DIR="$(cd "$(dirname "$SCRIPT_SOURCE")" && pwd -P)"
  if [[ -x "$SCRIPT_DIR/core/cli.sh" ]]; then
    exec "$SCRIPT_DIR/core/cli.sh" "$@"
  fi
fi

tmp_dir="$(mktemp -d)"
cleanup() {
  rm -rf "$tmp_dir"
}
trap cleanup EXIT

repo_dir="$tmp_dir/repo"

if command -v git >/dev/null 2>&1; then
  git clone --depth 1 --branch "$REPO_REF" "$REPO_URL" "$repo_dir"
else
  if [[ -z "$REPO_TARBALL_URL" ]]; then
    echo "git not found and REPO_TARBALL_URL is empty. Set REPO_TARBALL_URL or install git." >&2
    exit 1
  fi
  archive="$tmp_dir/repo.tar.gz"
  if command -v curl >/dev/null 2>&1; then
    curl -fsSL "$REPO_TARBALL_URL" -o "$archive"
  elif command -v wget >/dev/null 2>&1; then
    wget -qO "$archive" "$REPO_TARBALL_URL"
  else
    echo "Neither curl nor wget found for tarball download." >&2
    exit 1
  fi
  tar -xzf "$archive" -C "$tmp_dir"
  repo_dir="$(find "$tmp_dir" -mindepth 1 -maxdepth 1 -type d | head -n 1)"
fi

if [[ ! -x "$repo_dir/core/cli.sh" ]]; then
  echo "Missing core/cli.sh in repo." >&2
  exit 1
fi

exec "$repo_dir/core/cli.sh" "$@"
