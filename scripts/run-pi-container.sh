#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: scripts/run-pi-container.sh [options] [-- PI_ARGS...]

Run the pi container image with a mounted workspace and persistent pi state.

Options:
  --runtime <docker|podman>  Container runtime to use (default: auto-detect)
  --image <name:tag>         Image to run (default: pi:latest)
  --workspace <path>         Host directory to mount at /workspace (default: current dir)
  --state-dir <path>         Host directory for pi state/auth (default: ~/.pi)
  --no-user-map              Do not pass -u <uid:gid>
  -h, --help                 Show this help

Examples:
  scripts/run-pi-container.sh
  scripts/run-pi-container.sh --workspace ~/ai/projects
  scripts/run-pi-container.sh --runtime podman -- --help
EOF
}

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "error: required command not found: $1" >&2
    exit 1
  }
}

RUNTIME=""
IMAGE="pi:latest"
WORKSPACE="$PWD"
STATE_DIR="${HOME}/.pi"
USER_MAP=1
PI_ARGS=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --runtime)
      RUNTIME="${2:-}"
      shift 2
      ;;
    --image)
      IMAGE="${2:-}"
      shift 2
      ;;
    --workspace)
      WORKSPACE="${2:-}"
      shift 2
      ;;
    --state-dir)
      STATE_DIR="${2:-}"
      shift 2
      ;;
    --no-user-map)
      USER_MAP=0
      shift
      ;;
    --)
      shift
      PI_ARGS=("$@")
      break
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

if [[ -z "$RUNTIME" ]]; then
  if command -v docker >/dev/null 2>&1; then
    RUNTIME="docker"
  elif command -v podman >/dev/null 2>&1; then
    RUNTIME="podman"
  else
    echo "error: neither docker nor podman found" >&2
    exit 1
  fi
fi

if [[ "$RUNTIME" != "docker" && "$RUNTIME" != "podman" ]]; then
  echo "error: --runtime must be docker or podman" >&2
  exit 1
fi

require_cmd "$RUNTIME"
require_cmd id

if [[ ! -d "$WORKSPACE" ]]; then
  echo "error: workspace directory not found: $WORKSPACE" >&2
  exit 1
fi

mkdir -p "$STATE_DIR"
mkdir -p "$STATE_DIR/tmp"

WORKSPACE_ABS="$(cd "$WORKSPACE" && pwd)"
STATE_DIR_ABS="$(cd "$STATE_DIR" && pwd)"

CONTAINER_HOME="/tmp/pi-home"
CONTAINER_STATE_DIR="$CONTAINER_HOME/.pi"

RUN_ARGS=(
  run --rm -it
  -v "$WORKSPACE_ABS:/workspace"
  -w /workspace
  -v "$STATE_DIR_ABS:$CONTAINER_STATE_DIR"
  -e "HOME=$CONTAINER_HOME"
  -e "PI_CODING_AGENT_DIR=$CONTAINER_STATE_DIR/agent"
  -e "TMPDIR=$CONTAINER_STATE_DIR/tmp"
  -e "TMP=$CONTAINER_STATE_DIR/tmp"
  -e "TEMP=$CONTAINER_STATE_DIR/tmp"
)

if [[ "$USER_MAP" -eq 1 ]]; then
  RUN_ARGS+=( -u "$(id -u):$(id -g)" )
fi

RUN_ARGS+=( "$IMAGE" )
if [[ ${#PI_ARGS[@]} -gt 0 ]]; then
  RUN_ARGS+=( "${PI_ARGS[@]}" )
fi

exec "$RUNTIME" "${RUN_ARGS[@]}"
