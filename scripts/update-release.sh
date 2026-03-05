#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: scripts/update-release.sh [--tag vX.Y.Z] [--no-commit] [--allow-dirty]

Updates this flake to the latest badlogic/pi-mono release (or a provided tag):
1) updates pi-mono ref in flake.nix
2) updates flake.lock for input pi-mono
3) sets npmDepsHash = lib.fakeHash and builds .#pi to capture the real hash
4) writes the real npmDepsHash to nix/workspace.nix and rebuilds
5) runs .#pi -- --help
6) creates a commit (unless --no-commit)

Options:
  --tag vX.Y.Z   Use a specific upstream tag instead of querying GitHub
  --no-commit    Do not create a commit
  --allow-dirty  Allow running with uncommitted working tree changes
  -h, --help     Show this help
EOF
}

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "error: required command not found: $1" >&2
    exit 1
  }
}

extract_hash_from_log() {
  local log_file="$1"
  grep -Eo 'got:[[:space:]]*sha256-[A-Za-z0-9+/=]+' "$log_file" | head -n1 | sed -E 's/^got:[[:space:]]*//'
}

rewrite_npm_deps_hash() {
  local mode="$1" # fake | real
  local hash="${2:-}"
  local tmp

  tmp="$(mktemp "${TMPDIR:-/tmp}/pi-mono-nix-workspace.XXXXXX.nix")"

  awk -v mode="$mode" -v hash="$hash" '
    BEGIN { replaced=0 }
    {
      if ($0 ~ /^[[:space:]]*npmDepsHash[[:space:]]*=/) {
        if (!replaced) {
          if (mode == "fake") {
            print "  npmDepsHash = lib.fakeHash;"
          } else {
            print "  npmDepsHash = \"" hash "\";"
          }
          replaced=1
        }
        next
      }
      print
    }
    END {
      if (!replaced) exit 1
    }
  ' nix/workspace.nix > "$tmp"

  mv "$tmp" nix/workspace.nix
}

TAG=""
NO_COMMIT=0
ALLOW_DIRTY=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --tag)
      TAG="${2:-}"
      shift 2
      ;;
    --no-commit)
      NO_COMMIT=1
      shift
      ;;
    --allow-dirty)
      ALLOW_DIRTY=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "error: unknown argument: $1" >&2
      usage
      exit 1
      ;;
  esac
done

require_cmd git
require_cmd nix
require_cmd grep
require_cmd sed
require_cmd awk

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$REPO_ROOT"

if [[ "$ALLOW_DIRTY" -ne 1 ]] && ! git diff --quiet --ignore-submodules --; then
  echo "error: working tree is dirty. Commit/stash first or pass --allow-dirty." >&2
  exit 1
fi

if [[ -z "$TAG" ]]; then
  require_cmd curl
  TAG="$({
    curl -fsSL https://api.github.com/repos/badlogic/pi-mono/releases/latest \
      | grep -Eo '"tag_name"[[:space:]]*:[[:space:]]*"[^"]+"' \
      | head -n1 \
      | sed -E 's/.*"([^"]+)"/\1/'
  } || true)"
fi

if [[ -z "$TAG" ]]; then
  echo "error: could not determine upstream release tag" >&2
  exit 1
fi

if [[ ! "$TAG" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "error: tag must look like vX.Y.Z (got: $TAG)" >&2
  exit 1
fi

echo "==> Updating flake.nix pi-mono ref to $TAG"
OLD_REF_LINE="$(grep -E 'github:badlogic/pi-mono\?ref=' flake.nix || true)"
TMP_FLAKE="$(mktemp "${TMPDIR:-/tmp}/pi-mono-nix-flake.XXXXXX.nix")"
awk -v tag="$TAG" '{
  gsub(/github:badlogic\/pi-mono\?ref=[^"]+/, "github:badlogic/pi-mono?ref=" tag)
  print
}' flake.nix > "$TMP_FLAKE"
mv "$TMP_FLAKE" flake.nix
NEW_REF_LINE="$(grep -E 'github:badlogic/pi-mono\?ref=' flake.nix || true)"
if [[ "$OLD_REF_LINE" == "$NEW_REF_LINE" ]]; then
  echo "note: flake.nix ref was already $TAG"
fi

echo "==> Updating lock for input pi-mono"
nix flake lock --update-input pi-mono

echo "==> Forcing npmDepsHash refresh via lib.fakeHash"
rewrite_npm_deps_hash fake

BUILD_LOG="$(mktemp "${TMPDIR:-/tmp}/pi-mono-nix-update-build.XXXXXX.log")"
if nix build .#pi >"$BUILD_LOG" 2>&1; then
  echo "error: expected hash mismatch with lib.fakeHash, but build succeeded" >&2
  exit 1
fi

NEW_HASH="$(extract_hash_from_log "$BUILD_LOG" || true)"
if [[ -z "$NEW_HASH" ]]; then
  echo "error: forced hash refresh failed; could not parse reported hash" >&2
  echo "--- build log ---" >&2
  sed -n '1,200p' "$BUILD_LOG" >&2
  exit 1
fi

echo "==> Updating nix/workspace.nix npmDepsHash to $NEW_HASH"
rewrite_npm_deps_hash real "$NEW_HASH"

echo "==> Rebuilding .#pi"
nix build .#pi

echo "==> Validating CLI"
nix run .#pi -- --help >/dev/null

echo "==> Final changed files"
git status --short -- flake.nix flake.lock nix/workspace.nix

if [[ "$NO_COMMIT" -eq 0 ]]; then
  if git diff --quiet -- flake.nix flake.lock nix/workspace.nix; then
    echo "==> Nothing to commit"
  else
    git add flake.nix flake.lock nix/workspace.nix
    git commit -m "chore: update pi-mono to $TAG"
    echo "==> Created commit: chore: update pi-mono to $TAG"
  fi
else
  echo "==> --no-commit set; leaving changes unstaged"
fi

echo "Done."
