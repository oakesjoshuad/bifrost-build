#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
DEFAULT_POLICY_ENV="${REPO_ROOT}/config/policy.env"
DEFAULT_HOST_ENV="${REPO_ROOT}/config/nightly.env"

usage() {
  cat <<'USAGE'
Usage: run-nightly-wrapper.sh [--gate PATH] [--env FILE] [--log-root DIR] [--retain N]

Runs illumos nightly against bifrost-gate using nightly's native logging layout.

Options:
  --gate PATH      Path to bifrost-gate checkout (default: ~/repos/bifrost-gate)
  --env FILE       Path to nightly env file (default: config/nightly.env)
  --log-root DIR   Parent directory for per-run logs (default: /var/tmp/bifrost-build/logs)
  --retain N       Number of previous run-* dirs to keep (default: 0)
USAGE
}

GATE_PATH="${HOME}/repos/bifrost-gate"
NIGHTLY_ENV="${DEFAULT_HOST_ENV}"
LOG_ROOT="/var/tmp/bifrost-build/logs"
RETAIN_RUNS=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --gate)
      GATE_PATH="${2:?missing value for --gate}"
      shift 2
      ;;
    --env)
      NIGHTLY_ENV="${2:?missing value for --env}"
      shift 2
      ;;
    --log-root)
      LOG_ROOT="${2:?missing value for --log-root}"
      shift 2
      ;;
    --retain)
      RETAIN_RUNS="${2:?missing value for --retain}"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "unknown argument: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

if [[ -f "${DEFAULT_POLICY_ENV}" ]]; then
  # shellcheck source=/dev/null
  source "${DEFAULT_POLICY_ENV}"
fi

if [[ ! -d "${GATE_PATH}" ]]; then
  echo "missing gate checkout: ${GATE_PATH}" >&2
  exit 10
fi

if [[ ! -f "${NIGHTLY_ENV}" ]]; then
  echo "missing nightly env file: ${NIGHTLY_ENV}" >&2
  echo "copy config/nightly.env.example to config/nightly.env and edit paths" >&2
  exit 11
fi

NIGHTLY_BIN="${NIGHTLY_BIN:-/opt/onbld/bin/nightly}"
if [[ ! -x "${NIGHTLY_BIN}" ]]; then
  if command -v nightly >/dev/null 2>&1; then
    NIGHTLY_BIN="$(command -v nightly)"
  else
    echo "nightly command not found (tried /opt/onbld/bin/nightly and PATH)" >&2
    exit 12
  fi
fi

mkdir -p "${LOG_ROOT}"
ts="$(date +%Y%m%d-%H%M%S)"
RUN_DIR="${LOG_ROOT}/run-${ts}"
mkdir -p "${RUN_DIR}"

# Let nightly own its native log layout under ATLOG:
#   ATLOG/log.<date>/{nightly.log,mail_msg}, ATLOG/latest, ATLOG/nightly.lock
RUN_ENV="${RUN_DIR}/nightly.env"
cp "${NIGHTLY_ENV}" "${RUN_ENV}"
cat >> "${RUN_ENV}" <<RUNENV
export ATLOG="${RUN_DIR}"
export LOGFILE="${RUN_DIR}/nightly.log"
export MULTI_PROTO="no"
RUNENV

# Keep this run and optionally keep N older run-* dirs.
if [[ "${RETAIN_RUNS}" =~ ^[0-9]+$ ]]; then
  mapfile -t run_dirs < <(ls -1dt "${LOG_ROOT}"/run-* 2>/dev/null || true)
  keep_count=$((RETAIN_RUNS + 1))
  if (( ${#run_dirs[@]} > keep_count )); then
    for old in "${run_dirs[@]:keep_count}"; do
      rm -rf "${old}"
    done
  fi
fi

echo "bifrost profile: ${BIFROST_PROFILE:-unknown}"
echo "gate path: ${GATE_PATH}"
echo "nightly env(base): ${NIGHTLY_ENV}"
echo "nightly env(run): ${RUN_ENV}"
echo "nightly bin: ${NIGHTLY_BIN}"
echo "log root: ${LOG_ROOT}"
echo "run dir: ${RUN_DIR}"
echo "tail file: ${RUN_DIR}/latest/nightly.log"

set -x
( cd "${GATE_PATH}" && "${NIGHTLY_BIN}" -n "${RUN_ENV}" )
set +x

echo "nightly completed"
echo "run dir: ${RUN_DIR}"
echo "latest bundle: ${RUN_DIR}/latest"
echo "nightly summary log: ${RUN_DIR}/nightly.log"
