#!/usr/bin/env bash
set -Eeuo pipefail

# Lightweight framework helpers for ETK

# Generate a short run id
etk__gen_run_id() {
  local t r
  t=$(date +%Y%m%d-%H%M%S)
  if command -v hexdump >/dev/null 2>&1; then
    r=$(hexdump -n 3 -v -e '3/1 "%02x"' /dev/urandom 2>/dev/null || echo rnd)
  else
    r=$RANDOM
  fi
  echo "${t}-${r}"
}

# Initialize run logging to a central logfile
etk_setup_run_logging() {
  local root_dir="$1"
  local log_dir="$2"
  mkdir -p "$log_dir"
  if [[ -z "${ETK_RUN_ID:-}" ]]; then
    export ETK_RUN_ID="$(etk__gen_run_id)"
  fi
  export ETK_RUN_LOG="${log_dir}/etk_${ETK_RUN_ID}.log"
  # Redirect stdout/stderr to tee when allowed
  if [[ "${ETK_LOG_ALL:-1}" == "1" ]]; then
    exec > >(tee -a "$ETK_RUN_LOG") 2>&1
  fi
}

# Logging helpers
etk_log() { printf "%s [%s] %s\n" "$(date '+%F %T')" "$1" "$2"; }
etk_info() { etk_log INFO "$*"; }
etk_warn() { etk_log WARN "$*"; }
etk_error(){ etk_log ERROR "$*"; }

# Scan helpers: timing, counters, and summaries
# usage: etk_scan_begin "Name" ; etk_scan_hit ; etk_scan_end
etk_scan_begin() {
  ETK_SCAN_NAME="$1"; shift || true
  ETK_SCAN_START_TS=$(date +%s)
  ETK_SCAN_HITS=0
  ETK_SCAN_FILES=0
}
etk_scan_file_inc() { ETK_SCAN_FILES=$((ETK_SCAN_FILES+1)); }
etk_scan_hit() { ETK_SCAN_HITS=$((ETK_SCAN_HITS+1)); }
etk_scan_end() {
  local end=$(date +%s)
  local dur=$(( end - ETK_SCAN_START_TS ))
  etk_info "${ETK_SCAN_NAME:-Scan} 完成: 用时 ${dur}s, 文件 ${ETK_SCAN_FILES:-0}, 命中 ${ETK_SCAN_HITS:-0}"
  if [[ ${ETK_SCAN_HITS:-0} -eq 0 && "${ETK_SCAN_SUPPRESS_NOHIT:-0}" != "1" ]]; then
    echo "${ETK_SCAN_NAME:-Scan} 未发现命中。"
  fi
}

# Prompt helper with env fallback and default
# usage: etk_prompt VAR_NAME "提示" "默认值" ENV_NAME
etk_prompt() {
  local __var="$1"; shift
  local __msg="$1"; shift
  local __def="$1"; shift
  local __env="${1:-}"
  local __val=""
  if [[ -n "${__env}" && -n "${!__env:-}" ]]; then
    __val="${!__env}"
  else
    printf "%s (默认: %s): " "$__msg" "$__def"
    read -r __val || true
    if [[ -z "${__val// /}" ]]; then
      __val="$__def"
    fi
  fi
  printf -v "$__var" '%s' "$__val"
}

# Yes/No confirm with default 'N' unless CONFIRM_DEFAULT=Y
etk_confirm() {
  local msg=${1:-"确认继续?"}
  local def=${CONFIRM_DEFAULT:-N}
  printf "%s [y/N]: " "$msg"
  read -r ans || true
  local a=${ans:-$def}
  [[ $a == y || $a == Y ]]
}
