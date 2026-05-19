#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
DEFAULT_POLICY_ENV="${REPO_ROOT}/config/policy.env"
DEFAULT_HOST_ENV="${REPO_ROOT}/config/nightly.env"

if [[ -f "${DEFAULT_POLICY_ENV}" ]]; then
  # shellcheck source=/dev/null
  source "${DEFAULT_POLICY_ENV}"
fi

usage() {
  cat <<'USAGE'
Usage: run-nightly-wrapper.sh [--gate PATH] [--env FILE] [--atlog DIR] [--incremental]

Runs illumos nightly against bifrost-gate using nightly-native logging.

Options:
  --gate PATH      Path to bifrost-gate checkout (default: ~/repos/bifrost-gate)
  --env FILE       Path to nightly env file (default: config/nightly.env)
  --atlog DIR      Nightly ATLOG root (default: ~/repos/bifrost-build/logs)
  --incremental    Compatibility flag: remove clobber ('C') and ensure 'i'
USAGE
}

GATE_PATH="${BIFROST_GATE_PATH:-${HOME}/repos/bifrost-gate}"
NIGHTLY_ENV="${BIFROST_NIGHTLY_ENV:-${DEFAULT_HOST_ENV}}"
ATLOG_ROOT="${BIFROST_ATLOG_ROOT:-${HOME}/repos/bifrost-build/logs}"
INCREMENTAL=0

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
    --atlog)
      ATLOG_ROOT="${2:?missing value for --atlog}"
      shift 2
      ;;
    --incremental)
      INCREMENTAL=1
      shift 1
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

mkdir -p "${ATLOG_ROOT}"
RUN_ENV="$(mktemp "${TMPDIR:-/tmp}/bifrost-nightly-env.XXXXXX")"
trap 'rm -f "${RUN_ENV}"' EXIT
cp "${NIGHTLY_ENV}" "${RUN_ENV}"
cat >> "${RUN_ENV}" <<RUNENV
export ATLOG="${ATLOG_ROOT}"
export LOGFILE="${ATLOG_ROOT}/nightly.log"
export MULTI_PROTO="no"
RUNENV

if ! grep -q '^export MACH=' "${RUN_ENV}"; then
  host_mach="$(uname -p)"
  echo "export MACH=\"${host_mach}\"" >> "${RUN_ENV}"
fi

if ! grep -q '^export MACH64=' "${RUN_ENV}"; then
  case "${host_mach:-$(uname -p)}" in
    sparc) mach64_default="sparcv9" ;;
    i386) mach64_default="amd64" ;;
    *) mach64_default="${host_mach:-$(uname -p)}" ;;
  esac
  echo "export MACH64=\"${mach64_default}\"" >> "${RUN_ENV}"
fi

if [[ "${INCREMENTAL}" -eq 1 ]]; then
  cat >> "${RUN_ENV}" <<'RUNENV'
NIGHTLY_OPTIONS="${NIGHTLY_OPTIONS//C/}"
case "${NIGHTLY_OPTIONS}" in
  *i*) ;;
  *) NIGHTLY_OPTIONS="${NIGHTLY_OPTIONS}i" ;;
esac
export NIGHTLY_OPTIONS
RUNENV
fi

echo "bifrost profile: ${BIFROST_PROFILE:-unknown}"
echo "gate path: ${GATE_PATH}"
echo "nightly env(base): ${NIGHTLY_ENV}"
echo "nightly env(run): ${RUN_ENV}"
echo "nightly bin: ${NIGHTLY_BIN}"
echo "atlog root: ${ATLOG_ROOT}"
echo "incremental mode: ${INCREMENTAL}"
echo "tail file: ${ATLOG_ROOT}/latest/nightly.log"

set -x
( cd "${GATE_PATH}" && "${NIGHTLY_BIN}" -n "${RUN_ENV}" )
set +x

echo "nightly completed"
echo "atlog latest: ${ATLOG_ROOT}/latest"
echo "nightly summary log: ${ATLOG_ROOT}/nightly.log"
