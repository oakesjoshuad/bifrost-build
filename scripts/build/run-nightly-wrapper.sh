#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
DEFAULT_POLICY_ENV="${REPO_ROOT}/config/policy.env"
DEFAULT_HOST_ENV="${REPO_ROOT}/config/nightly.env"

usage() {
  cat <<USAGE
Usage: run-nightly-wrapper.sh [--gate PATH] [--env FILE] [--log-dir DIR]

Runs illumos nightly against bifrost-gate with deterministic logs.

Options:
  --gate PATH     Path to bifrost-gate checkout (default: ~/repos/bifrost-gate)
  --env FILE      Path to illumos nightly env file (default: config/nightly.env)
  --log-dir DIR   Output log directory (default: /var/tmp/bifrost-build/logs/<timestamp>)
USAGE
}

GATE_PATH="${HOME}/repos/bifrost-gate"
NIGHTLY_ENV="${DEFAULT_HOST_ENV}"
LOG_DIR=""

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
    --log-dir)
      LOG_DIR="${2:?missing value for --log-dir}"
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

if [[ -z "${LOG_DIR}" ]]; then
  ts="$(date +%Y%m%d-%H%M%S)"
  LOG_DIR="/var/tmp/bifrost-build/logs/${ts}"
fi
mkdir -p "${LOG_DIR}"

RUN_ATLOG="${LOG_DIR}/atlog"
RUN_LOGFILE="${LOG_DIR}/nightly.log"
RUN_ENV="${LOG_DIR}/nightly.env"
mkdir -p "${RUN_ATLOG}"

cp "${NIGHTLY_ENV}" "${RUN_ENV}"
cat >> "${RUN_ENV}" <<RUNENV
export ATLOG="${RUN_ATLOG}"
export LOGFILE="${RUN_LOGFILE}"
export MULTI_PROTO="no"
RUNENV

echo "bifrost profile: ${BIFROST_PROFILE:-unknown}"
echo "gate path: ${GATE_PATH}"
echo "nightly env(base): ${NIGHTLY_ENV}"
echo "nightly env(run): ${RUN_ENV}"
echo "nightly bin: ${NIGHTLY_BIN}"
echo "log dir: ${LOG_DIR}"
echo "atlog dir: ${RUN_ATLOG}"
echo "nightly logfile: ${RUN_LOGFILE}"

set -x
( cd "${GATE_PATH}" && "${NIGHTLY_BIN}" -n "${RUN_ENV}" ) \
  > "${LOG_DIR}/nightly.stdout.log" \
  2> "${LOG_DIR}/nightly.stderr.log"
set +x

echo "nightly completed"
echo "stdout: ${LOG_DIR}/nightly.stdout.log"
echo "stderr: ${LOG_DIR}/nightly.stderr.log"
