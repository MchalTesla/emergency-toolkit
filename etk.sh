#!/usr/bin/env bash
# Author: FightnvrGP
# Project: https://github.com/MchalTesla/emergency-toolkit
set -euo pipefail

# 引导与环境（在缺省环境/容器内也能自洽运行）
ROOT_DIR="${ROOT_DIR:-$(cd "$(dirname "$0")" && pwd)}"
BIN_DIR="${BIN_DIR:-${ROOT_DIR}/bin}"
LOG_DIR="${LOG_DIR:-${ROOT_DIR}/logs}"
CONF_DIR="${CONF_DIR:-${ROOT_DIR}/conf}"
mkdir -p "${LOG_DIR}" "${CONF_DIR}/frp"
export PATH="${BIN_DIR}:${PATH}"

# 可选加载框架工具（若存在）
if [[ -f "${ROOT_DIR}/scripts/lib/framework.sh" ]]; then
  # shellcheck disable=SC1091
  source "${ROOT_DIR}/scripts/lib/framework.sh"
  if declare -F etk_setup_run_logging >/dev/null 2>&1; then
    etk_setup_run_logging "${ROOT_DIR}" "${LOG_DIR}"
    etk_info "ETK 启动，日志目录=${LOG_DIR}"
  fi
fi

# 兜底函数：在未加载框架时提供最小实现，避免报错
if ! declare -F print_header >/dev/null 2>&1; then
  print_header() {
    ui_theme_init
    local ticon=""; if [[ -n "${UI_EMOJI_ON:-}" ]]; then ticon="🛠️ "; fi
    local line spaces w
    w=${UI_W:-74}
    printf -v spaces "%*s" "$w" ""
    line="${spaces// /$UI_H}"
    printf "%s%s%s\n" "$C_BLUE" "$line" "$C_RESET"
    printf "%s%sEmergency Toolkit%s  %s时间%s %s  %s位置%s %s\n" \
      "$C_BOLD" "$ticon" "$C_RESET" "$C_DIM" "$C_RESET" "$(date '+%F %T')" \
      "$C_DIM" "$C_RESET" "$ROOT_DIR"
    printf "%s%s%s\n" "$C_BLUE" "$line" "$C_RESET"
  }
fi
if ! declare -F ts >/dev/null 2>&1; then
  ts() { date +%Y%m%d_%H%M%S; }
fi
for f in etk_scan_begin etk_scan_end etk_scan_hit etk_info etk_prompt; do
  if ! declare -F "$f" >/dev/null 2>&1; then eval "$f(){ :; }"; fi
done
# 兜底：pause 等待用户输入；无 TTY 时跳过
if ! declare -F pause >/dev/null 2>&1; then
  pause() {
    if [[ -e /dev/tty && -r /dev/tty ]]; then
      printf "按回车继续..." > /dev/tty 2>/dev/null || true
      read -r _ < /dev/tty || true
    elif [[ -t 0 ]]; then
      read -r -p "按回车继续..." _ || true
    fi
  }
fi

# 统一 UI 样式（可复用到所有功能）
if ! declare -F ui_theme_init >/dev/null 2>&1; then
  ui_theme_init() {
    UI_W=${UI_W:-74}
    # UTF-8/框线字符检测与强制开关
    local enc="${LC_ALL:-${LC_CTYPE:-${LANG:-}}}"
    local force_utf8="${ETK_FORCE_UTF8:-${ETK_UTF8:-}}"   # 仅当为 "1" 时强制启用 UTF-8 框线
    local force_ascii="${ETK_FORCE_ASCII:-}"               # 为 "1" 时强制 ASCII 框线
    if [[ "${force_ascii}" == "1" ]]; then
      UI_TL="+"; UI_TR="+"; UI_BL="+"; UI_BR="+"; UI_H="-"; UI_V="|"; UI_UTF8=0
    elif [[ "${force_utf8}" == "1" ]]; then
      UI_TL="┌"; UI_TR="┐"; UI_BL="└"; UI_BR="┘"; UI_H="─"; UI_V="│"; UI_UTF8=1
    else
      if printf '%s' "$enc" | grep -qi 'utf-8'; then
        UI_TL="┌"; UI_TR="┐"; UI_BL="└"; UI_BR="┘"; UI_H="─"; UI_V="│"; UI_UTF8=1
      else
        UI_TL="+"; UI_TR="+"; UI_BL="+"; UI_BR="+"; UI_H="-"; UI_V="|"; UI_UTF8=0
      fi
    fi
    # 颜色（可通过 ETK_NO_COLOR=1 关闭；ETK_FORCE_COLOR=1 强制启用；缺少 tput 时回退 ANSI）
    C_RESET=""; C_BOLD=""; C_DIM=""; C_RED=""; C_GREEN=""; C_YELLOW=""; C_BLUE=""; C_CYAN=""
    if [[ -z "${ETK_NO_COLOR:-}" ]]; then
      if command -v tput >/dev/null 2>&1 && { [[ -t 1 ]] || [[ -n "${ETK_FORCE_COLOR:-}" ]]; }; then
        C_RESET="$(tput sgr0)"; C_BOLD="$(tput bold)"; C_DIM="$(tput dim)"
        C_RED="$(tput setaf 1)"; C_GREEN="$(tput setaf 2)"; C_YELLOW="$(tput setaf 3)"; C_BLUE="$(tput setaf 4)"; C_CYAN="$(tput setaf 6)"
      elif { [[ -t 1 ]] || [[ -n "${ETK_FORCE_COLOR:-}" ]]; } && [[ "${TERM:-}" != "dumb" ]]; then
        # ANSI 回退
        C_RESET=$'\033[0m'; C_BOLD=$'\033[1m'; C_DIM=$'\033[2m'
        C_RED=$'\033[31m'; C_GREEN=$'\033[32m'; C_YELLOW=$'\033[33m'; C_BLUE=$'\033[34m'; C_CYAN=$'\033[36m'
      fi
    fi
    # Emoji（需 UTF-8；可用 ETK_FORCE_EMOJI=1 强制，但若 ASCII 框线已强制则不启用）
    if [[ -z "${ETK_NO_EMOJI:-}" ]] && [[ -z "${ETK_FORCE_ASCII:-}" ]] && { [[ ${UI_UTF8:-0} -eq 1 ]] || [[ "${ETK_FORCE_EMOJI:-}" == "1" ]]; }; then
      UI_EMOJI_ON=1
    else
      UI_EMOJI_ON=""
    fi
  }
  # 安全重复字符串（支持多字节字符），返回不换行的结果
  ui_repeat() { # $1 str $2 count
    local str="$1"; local n="$2"; local spaces
    printf -v spaces "%*s" "$n" ""
    printf "%s" "${spaces// /$str}"
  }
  ui_line() { # $1 char
    local ch="${1:-$UI_H}"; local w=${UI_W:-74}
    ui_repeat "$ch" "$w"
    printf "\n"
  }
  ui_title() { # $1 title
    ui_theme_init
    local t="$1"; local w=${UI_W:-74}
    local inner=$(( w>2 ? w-2 : 0 ))
    printf "%s%s" "$C_BOLD" "$UI_TL"
    ui_repeat "$UI_H" "$inner"
    printf "%s %s %s\n" "$UI_TR" "$t" "$C_RESET"
  }
  # 根据标题推断一个图标
  ui_icon_for() { # $1 title
    local t="${1:-}"
    if [[ -z "${UI_EMOJI_ON:-}" ]]; then echo ""; return; fi
    case "$t" in
      *ClamAV*|*病毒*|*木马*) echo "🦠";;
      *LOKI*|*IOC*|*恶意*|*威胁*) echo "🕵️";;
      *Lynis*|*审计*) echo "📝";;
      *rkhunter*|*Rootkit*|*检查*) echo "🛡️";;
      *LMD*|*maldet*|*恶意代码*) echo "🧬";;
      *Web*|*日志*|*GoAccess*) echo "📊";;
      *系统信息*|*System*) echo "💻";;
      *网络*|*进程*) echo "🌐";;
      *文件*|*取证*) echo "🗂️";;
      *账号*|*认证*|*SSH*) echo "🔐";;
      *计划任务*|*服务*) echo "🧩";;
      *) echo "";;
    esac
  }
  ui_box_start() { # $1 title
    ui_theme_init
    local t="$1"; local w=${UI_W:-74}
    local inner=$(( w>2 ? w-2 : 0 ))
    printf "%s%s" "$C_BLUE" "$UI_TL"; ui_repeat "$UI_H" "$inner"; printf "%s%s\n" "$UI_TR" "$C_RESET"
    if [[ -n "$t" ]]; then
      local icon="$(ui_icon_for "$t")"
      if [[ -n "$icon" ]]; then
        printf "%s%s %s%s%s %s\n" "$C_BLUE$UI_V$C_RESET" "$C_BOLD" "$icon" "$C_RESET" "$t" ""
      else
        printf "%s%s %s%s%s\n" "$C_BLUE$UI_V$C_RESET" "$C_BOLD" "$t" "$C_RESET" ""
      fi
    fi
    printf "%s" "$C_BLUE$UI_V$C_RESET"; printf "\n"
  }
  ui_box_sep() { printf "%s" "$C_BLUE$UI_V$C_RESET"; printf "\n"; }
  ui_box_end() {
    ui_theme_init
    local w=${UI_W:-74}
    local inner=$(( w>2 ? w-2 : 0 ))
    printf "%s%s" "$C_BLUE" "$UI_BL"; ui_repeat "$UI_H" "$inner"; printf "%s%s\n" "$UI_BR" "$C_RESET"
  }
  ui_kv() { # key value
    local k="$1"; shift; local v="$*"
    printf "%s %s%-18s%s : %s\n" "$C_BLUE$UI_V$C_RESET" "$C_BOLD" "$k" "$C_RESET" "$v"
  }
  ui_badges() { # name=value;color ... (use ;red|yellow|green)
    local part color name val
    for part in "$@"; do
      name="${part%%=*}"; val="${part#*=}"; color=""
      if echo "$val" | grep -q ';'; then
        color="${val#*;}"; val="${val%%;*}"
      fi
      # 贴心 emoji：在 UTF-8 且未禁用时自动附加
      if [[ -n "${UI_EMOJI_ON:-}" ]]; then
        case "$name" in
          Hits|命中|命中文件) name="${name} 🎯";;
          Alerts|告警) name="${name} 🚨";;
          Warnings|警告) name="${name} ⚠️";;
          Notices|提示) name="${name} ℹ️";;
          日志|Log|LOG) name="${name} 📄";;
          时间) name="${name} ⏱️";;
        esac
      fi
      case "$color" in
        red) printf "%s [%s: %s]%s " "$C_RED" "$name" "$val" "$C_RESET";;
        yellow) printf "%s [%s: %s]%s " "$C_YELLOW" "$name" "$val" "$C_RESET";;
        green) printf "%s [%s: %s]%s " "$C_GREEN" "$name" "$val" "$C_RESET";;
        *) printf "[%s: %s] " "$name" "$val";;
      esac
    done
    printf "\n"
  }
fi

# ===== 通用扫描路径选择与展开（排除工具箱） =====
etk_now() { date +%s; }
etk_fmt_dur() { # $1 seconds (integer or float)
  local s="$1"
  # keep simple: show in s with 1 decimal if float-like
  if echo "$s" | grep -q '[.]'; then printf "%ss" "$s"; else
    if [[ "$s" -ge 3600 ]] 2>/dev/null; then
      local h=$((s/3600)); local m=$(( (s%3600)/60 )); local r=$(( s%60 ))
      printf "%dh%02dm%02ds" "$h" "$m" "$r"
    elif [[ "$s" -ge 60 ]] 2>/dev/null; then
      local m=$(( s/60 )); local r=$(( s%60 ))
      printf "%dm%02ds" "$m" "$r"
    else
      printf "%ds" "$s"
    fi
  fi
}

scan_prompt_paths() { 
  # 新用法: scan_prompt_paths "提示" "默认" -> 通过 stdout 回显结果
  # 兼容旧用法: scan_prompt_paths outvar "提示" "默认" -> 同时设置变量并回显
  local __outvar="" __prompt __def paths_line
  if [[ $# -ge 3 ]]; then
    __outvar="$1"; __prompt="$2"; __def="$3"
  else
    __prompt="$1"; __def="$2"
  fi
  # 直接通过 /dev/tty 进行交互，避免被管道/tee 影响
  if [[ -e /dev/tty && -r /dev/tty ]]; then
    printf "%s " "$__prompt" > /dev/tty 2>/dev/null || true
    read -r paths_line < /dev/tty || true
  else
    printf "%s " "$__prompt"
    read -r paths_line || true
  fi
  paths_line=${paths_line:-$__def}
  if [[ -n "$__outvar" ]]; then
    printf -v "$__outvar" '%s' "$paths_line"
  fi
  echo "$paths_line"
}

expand_excluding_root() { # $1 base
  local base="$1"; local rd="$ROOT_DIR"
  case "$base" in /proc|/sys|/dev|/run) return 0;; esac
  if [[ "$rd" != "$base" && "$rd" != "$base"/* ]]; then
    echo "$base"; return 0
  fi
  if [[ "$rd" == "$base" ]]; then return 0; fi
  local c
  for c in "$base"/*; do
    [[ -e "$c" ]] || continue
    case "$c" in /proc|/sys|/dev|/run) continue;; esac
    if [[ "$rd" == "$c" || "$rd" == "$c"/* ]]; then
      expand_excluding_root "$c"
    else
      echo "$c"
    fi
  done
}

scan_expand_targets() { # $1 paths_line -> prints targets line-by-line
  local line="$1"; local p
  for p in $line; do
    if [[ "$p" == "/" ]]; then
      for d in /*; do [[ -e "$d" ]] || continue; expand_excluding_root "$d"; done
    else
      expand_excluding_root "$p"
    fi
  done | awk '!seen[$0]++'
}

# 解析 Loki 目录：优先 tools/Loki，其次 tools/Loki-*/
loki_dir_resolve() {
  local base="${ROOT_DIR}/tools"
  if [[ -f "${base}/Loki/loki.py" ]]; then echo "${base}/Loki"; return 0; fi
  local cand
  cand=$(ls -d "${base}"/Loki*/ 2>/dev/null | head -n1 || true)
  if [[ -n "${cand:-}" ]] && [[ -f "${cand%/}/loki.py" ]]; then
    echo "${cand%/}"
    return 0
  fi
  echo "${base}/Loki"
}

# 查找本地 Python3（优先工具箱本地版本）
py_find_local() {
  # 1) bin/python3（工具箱优先）
  if [[ -x "${BIN_DIR}/python3" ]]; then echo "${BIN_DIR}/python3"; return 0; fi
  # 2) tools/python*/bin/python3
  local c
  for c in "${ROOT_DIR}/tools"/python*/bin/python3; do
    [[ -x "$c" ]] && { echo "$c"; return 0; }
  done
  # 3) tools/*/bin/python3（例如嵌套目录）
  for c in "${ROOT_DIR}/tools"/*/bin/python3; do
    [[ -x "$c" ]] && { echo "$c"; return 0; }
  done
  # 4) tools/python3 可执行
  if [[ -x "${ROOT_DIR}/tools/python3" ]]; then echo "${ROOT_DIR}/tools/python3"; return 0; fi
  # 5) PATH 中的 python3
  if command -v python3 >/dev/null 2>&1; then command -v python3; return 0; fi
  return 1
}
generate_summary_report() {
  echo "[生成汇总报告]"
  mkdir -p "$LOG_DIR"
  local t0=$(etk_now)
  local out="${LOG_DIR}/summary_$(ts).log"
  local last_clam last_lynis last_rk last_lmd last_web last_loki
  last_clam=$(ls -1t "${LOG_DIR}"/clamscan_*.log 2>/dev/null | head -n1 || true)
  last_lynis=$(ls -1t "${LOG_DIR}"/lynis_*.log 2>/dev/null | head -n1 || true)
  last_rk=$(ls -1t "${LOG_DIR}"/rkhunter_*.log 2>/dev/null | head -n1 || true)
  last_lmd=$(ls -1t "${LOG_DIR}"/lmd_*.log 2>/dev/null | head -n1 || true)
  last_web=$(ls -1t "${LOG_DIR}"/weblog_*.log 2>/dev/null | head -n1 || true)
  last_loki=$(ls -1t "${LOG_DIR}"/loki_*.log 2>/dev/null | head -n1 || true)
  {
    echo "==== Emergency Toolkit 汇总报告 ($(date '+%F %T')) ===="
    echo
    echo "-- ClamAV --"
    if [[ -n "$last_clam" ]]; then
      echo "日志: $last_clam"
  echo "命中: $(grep -c ' FOUND' "$last_clam" 2>/dev/null || printf '0')"
      grep ' FOUND' "$last_clam" 2>/dev/null | sed -n '1,20p' || true
    else
      echo "(无最近日志)"
    fi
    echo
    echo "-- LOKI --"
    if [[ -n "$last_loki" ]]; then
      echo "日志: $last_loki"
      # 解析LOKI结果统计
      local loki_alerts loki_warnings loki_notices
      local res_line=$(grep -E '\[NOTICE\] Results: [0-9]+ alerts?, [0-9]+ warnings?, [0-9]+ notices?' "$last_loki" | tail -n1 || true)
      if [[ -n "$res_line" ]]; then
        loki_alerts=$(echo "$res_line" | awk '{print $3}' | tr -d ',')
        loki_warnings=$(echo "$res_line" | awk '{print $5}' | tr -d ',')
        loki_notices=$(echo "$res_line" | awk '{print $7}' | tr -d ',')
      else
        loki_alerts=0; loki_warnings=0; loki_notices=0
      fi
      echo "Alerts: ${loki_alerts:-0}, Warnings: ${loki_warnings:-0}, Notices: ${loki_notices:-0}"
      # 显示威胁详情
      grep -E '^\[WARNING\]' "$last_loki" 2>/dev/null | sed -n '1,10p' || true
    else
      echo "(无最近日志)"
    fi
    echo
    echo "-- Lynis --"
    if [[ -n "$last_lynis" ]]; then
      echo "日志: $last_lynis"
  echo "WARNING: $(grep -Ec '\\[ *WARNING *\\]' "$last_lynis" 2>/dev/null || printf '0')"
      grep -E '\\[ *WARNING *\\]' "$last_lynis" 2>/dev/null | sed -n '1,20p' || true
    else
      echo "(无最近日志)"
    fi
    echo
    echo "-- rkhunter --"
    if [[ -n "$last_rk" ]]; then
      echo "日志: $last_rk"
      # 解析rkhunter结果统计
      local rk_warnings rk_found
      rk_warnings=$(grep -Ec '^\s*Warning:' "$last_rk" 2>/dev/null || printf '0')
      rk_found=$(grep -Ec '\[ Found \]$' "$last_rk" 2>/dev/null || printf '0')
      echo "Warnings: ${rk_warnings}, Found: ${rk_found}"
      # 显示威胁详情
      if [[ $rk_warnings -gt 0 ]]; then
        grep -E '^\s*Warning:' "$last_rk" 2>/dev/null | sed -n '1,10p' || true
      fi
      if [[ $rk_found -gt 0 ]]; then
        [[ $rk_warnings -gt 0 ]] && echo ""
        grep '\[ Found \]$' "$last_rk" 2>/dev/null | sed 's/\s*\[ Found \]$//' | sed -n '1,10p' || true
      fi
    else
      echo "(无最近日志)"
    fi
    echo
    echo "-- LMD (maldet) --"
    if [[ -n "$last_lmd" ]]; then
      echo "日志: $last_lmd"
  echo "可疑行: $({ grep -Ei 'malware|quarantine|quarantined|FOUND' "$last_lmd" 2>/dev/null || true; } | wc -l | tr -d ' ')"
      grep -Ei 'malware|quarantine|quarantined|FOUND' "$last_lmd" 2>/dev/null | sed -n '1,20p' || true
    else
      echo "(无最近日志)"
    fi
    echo
    echo "-- Web 日志猎杀 --"
    if [[ -n "$last_web" ]]; then
      echo "日志: $last_web"
  echo "命中: $(grep -Ec '^(WEB_HIT|WEB_STAT):' "$last_web" 2>/dev/null || printf '0')"
      grep -E '^(WEB_HIT|WEB_STAT):' "$last_web" 2>/dev/null | sed -n '1,20p' || true
    else
      echo "(无最近日志)"
    fi
  } | tee "$out"
  local t1=$(etk_now); local dur=$((t1-t0))
  ui_box_start "统计"
  printf "%s " "$C_BLUE$UI_V$C_RESET"; ui_badges "耗时=$(etk_fmt_dur "$dur")" "日志=$(basename "$out")"
  ui_box_end
}

# ========== 基础取证功能（最小可用实现） ==========
sys_info() {
  ui_theme_init; ui_box_start "系统信息采集"
  local t0=$(etk_now)
  
  # 基本信息
  ui_kv "主机名" "$(hostname 2>/dev/null || echo '-')"
  ui_kv "内核版本" "$(uname -r 2>/dev/null || echo '-')"
  ui_kv "系统架构" "$(uname -m 2>/dev/null || echo '-')"
  ui_kv "发行版" "$(cat /etc/*release 2>/dev/null | head -n1 | tr -d '\r' || echo '-')"
  ui_kv "当前时间" "$(date '+%F %T %Z' 2>/dev/null || echo '-')"
  ui_kv "运行时长" "$(uptime -p 2>/dev/null || uptime 2>/dev/null | awk -F'up' '{print $2}' | sed 's/^ *//' || echo '-')"
  
  ui_box_sep
  
  # CPU和内存信息
  echo "CPU 信息:"; ui_box_sep
  local cpu_model cpu_cores cpu_load
  cpu_model=$(grep -m1 'model name' /proc/cpuinfo 2>/dev/null | cut -d: -f2 | sed 's/^ *//' || echo '-')
  cpu_cores=$(grep -c '^processor' /proc/cpuinfo 2>/dev/null || echo '-')
  cpu_load=$(uptime 2>/dev/null | awk -F'load average:' '{print $2}' | sed 's/^ *//' || echo '-')
  ui_kv "CPU 型号" "$cpu_model"
  ui_kv "CPU 核心数" "$cpu_cores"
  ui_kv "系统负载" "$cpu_load"
  
  echo "内存信息:"; ui_box_sep
  local mem_total mem_used mem_free
  if command -v free >/dev/null 2>&1; then
    mem_total=$(free -h 2>/dev/null | awk 'NR==2{print $2}')
    mem_used=$(free -h 2>/dev/null | awk 'NR==2{print $3}')
    mem_free=$(free -h 2>/dev/null | awk 'NR==2{print $4}')
  else
    mem_total=$(cat /proc/meminfo 2>/dev/null | awk '/MemTotal/{print $2/1024/1024 " GB"}' | head -n1)
    mem_used=$(cat /proc/meminfo 2>/dev/null | awk '/MemAvailable/{print ($2/1024/1024) " GB"}' | head -n1)
    mem_free="-"
  fi
  ui_kv "总内存" "$mem_total"
  ui_kv "已用内存" "$mem_used"
  ui_kv "可用内存" "$mem_free"
  
  ui_box_sep
  
  # 磁盘信息
  echo "磁盘使用情况:"; ui_box_sep
  local disk_info
  disk_info=$(df -h 2>/dev/null | awk 'NR>1 && $1 !~ /^tmpfs|^devtmpfs|^overlay/ {print $1 ": " $3 "/" $2 " (" $5 " used)"}' | head -n5)
  if [[ -n "$disk_info" ]]; then
    printf "%s\n" "$disk_info" | while IFS= read -r line; do
      printf "%s %s\n" "$C_BLUE$UI_V$C_RESET" "$line"
    done
  else
    printf "%s %s\n" "$C_BLUE$UI_V$C_RESET" "(无法获取磁盘信息)"
  fi
  
  ui_box_sep
  
  # 网络接口
  echo "网络接口:"; ui_box_sep
  local net_info
  net_info=$(ip addr 2>/dev/null | grep -E '^[0-9]+:' | head -n5 | sed 's/@.*//' || ifconfig 2>/dev/null | grep -E '^[a-zA-Z]' | head -n5 || echo '(无网络工具)')
  if [[ -n "$net_info" ]]; then
    printf "%s\n" "$net_info" | while IFS= read -r line; do
      printf "%s %s\n" "$C_BLUE$UI_V$C_RESET" "$line"
    done
  fi
  
  ui_box_sep
  
  # 系统状态检查
  echo "系统状态:"; ui_box_sep
  local selinux_status apparmor_status firewall_status
  if command -v getenforce >/dev/null 2>&1; then
    selinux_status=$(getenforce 2>/dev/null || echo 'Disabled')
  else
    selinux_status="N/A"
  fi
  
  if command -v apparmor_status >/dev/null 2>&1; then
    apparmor_status=$(apparmor_status 2>/dev/null | grep -c 'profiles are in' || echo 'Not loaded')
    [[ "$apparmor_status" -gt 0 ]] && apparmor_status="Active" || apparmor_status="Inactive"
  else
    apparmor_status="N/A"
  fi
  
  if command -v ufw >/dev/null 2>&1; then
    firewall_status=$(ufw status 2>/dev/null | grep -q 'Status: active' && echo 'UFW Active' || echo 'UFW Inactive')
  elif command -v firewall-cmd >/dev/null 2>&1; then
    firewall_status=$(firewall-cmd --state 2>/dev/null || echo 'Firewalld Unknown')
  else
    firewall_status="Unknown"
  fi
  
  ui_kv "SELinux" "$selinux_status"
  ui_kv "AppArmor" "$apparmor_status"
  ui_kv "防火墙" "$firewall_status"
  
  ui_box_end
  local t1=$(etk_now); local dur=$((t1-t0))
  ui_box_start "统计"
  local sys_score="green"
  [[ "$selinux_status" == "Disabled" || "$selinux_status" == "Permissive" ]] && sys_score="yellow"
  [[ "$firewall_status" == "Unknown" ]] && sys_score="yellow"
  printf "%s " "$C_BLUE$UI_V$C_RESET"; ui_badges "耗时=$(etk_fmt_dur "$dur")" "系统评分=${sys_score};${sys_score}"
  if [[ -n "${ETK_CURRENT_LOG:-}" ]]; then
    ui_badges "日志=$(basename "$ETK_CURRENT_LOG")"
  fi
  ui_box_end
}

net_process_audit() {
  ui_theme_init; ui_box_start "网络与进程排查"
  local t0=$(etk_now)
  
  # 网络连接统计
  ui_kv "网络工具" "$(command -v ss >/dev/null 2>&1 && echo 'ss' || command -v netstat >/dev/null 2>&1 && echo 'netstat' || echo '无')"
  
  echo "网络连接统计:"; ui_box_sep
  local conn_stats
  if command -v ss >/dev/null 2>&1; then
    conn_stats=$(ss -ant 2>/dev/null | awk '
      NR>1 {
        if ($1 == "LISTEN") listen++
        else if ($1 == "ESTABLISHED") established++
        else if ($1 == "TIME-WAIT") timewait++
        else other++
      }
      END {
        print "监听端口: " listen
        print "已建立连接: " established
        print "TIME_WAIT: " timewait
        print "其他状态: " other
      }
    ')
  elif command -v netstat >/dev/null 2>&1; then
    conn_stats=$(netstat -ant 2>/dev/null | awk '
      NR>2 {
        if ($6 == "LISTEN") listen++
        else if ($6 == "ESTABLISHED") established++
        else if ($6 == "TIME_WAIT") timewait++
        else other++
      }
      END {
        print "监听端口: " listen
        print "已建立连接: " established
        print "TIME_WAIT: " timewait
        print "其他状态: " other
      }
    ')
  else
    conn_stats="(无法获取网络统计)"
  fi
  
  if [[ -n "$conn_stats" ]]; then
    while IFS= read -r line; do
      printf "%s %s\n" "$C_BLUE$UI_V$C_RESET" "$line"
    done <<< "$conn_stats"
  fi
  
  ui_box_sep
  
  # 监听端口详情
  echo "关键监听端口:"; ui_box_sep
  local listen_ports
  if command -v ss >/dev/null 2>&1; then
    listen_ports=$(ss -lnt 2>/dev/null | awk 'NR>1 {split($4,a,":"); port=a[length(a)]; if (port < 1024 || port == 22 || port == 80 || port == 443) print $1, $4}' | head -n10)
  elif command -v netstat >/dev/null 2>&1; then
    listen_ports=$(netstat -lnt 2>/dev/null | awk 'NR>2 {split($4,a,":"); port=a[length(a)]; if (port < 1024 || port == 22 || port == 80 || port == 443) print $1, $4}' | head -n10)
  else
    listen_ports="(无网络工具)"
  fi
  
  if [[ -n "$listen_ports" ]]; then
    while IFS= read -r line; do
      printf "%s %s\n" "$C_BLUE$UI_V$C_RESET" "$line"
    done <<< "$listen_ports"
  fi
  
  ui_box_sep
  
  # 进程统计
  echo "进程统计:"; ui_box_sep
  local proc_stats total_procs running_procs zombie_procs
  if [[ -r /proc/stat ]]; then
    total_procs=$(ps aux 2>/dev/null | wc -l)
    running_procs=$(ps aux 2>/dev/null | grep -c ' R ')
    zombie_procs=$(ps aux 2>/dev/null | grep -c ' Z ')
    
    ui_kv "总进程数" "$((total_procs - 1))"  # 减去标题行
    ui_kv "运行中进程" "$running_procs"
    ui_kv "僵尸进程" "$zombie_procs"
  else
    total_procs=0
    running_procs=0
    zombie_procs=0
    printf "%s %s\n" "$C_BLUE$UI_V$C_RESET" "(无法获取进程统计)"
  fi
  
  ui_box_sep
  
  # 可疑进程检测
  echo "安全检查:"; ui_box_sep
  local suspicious_procs root_procs hidden_procs
  suspicious_procs=$(ps aux 2>/dev/null | grep -E '/tmp|/\.ssh|/\.[a-zA-Z0-9]' | grep -v grep | wc -l 2>/dev/null | sed 's/[^0-9]//g' || echo "0")
  root_procs=$(ps aux 2>/dev/null | awk '$1=="root" {count++} END {print count+0}' 2>/dev/null | sed 's/[^0-9]//g' || echo "0")
  hidden_procs=$(ps aux 2>/dev/null | grep -c '\[.*\]' 2>/dev/null | sed 's/[^0-9]//g' || echo "0")
  
  ui_kv "可疑路径进程" "$suspicious_procs"
  ui_kv "root用户进程" "$root_procs"
  ui_kv "隐藏进程" "$hidden_procs"
  
  # 高危进程检查
  local high_risk_procs
  high_risk_procs=$(ps aux 2>/dev/null | awk '$3 > 80 || $4 > 80 {print $2, $11, $3"%", $4"%"}' | head -n5)
  if [[ -n "$high_risk_procs" ]]; then
    ui_box_sep
    echo "高资源占用进程:"; ui_box_sep
    while IFS= read -r line; do
      printf "%s %s\n" "$C_BLUE$UI_V$C_RESET" "$line"
    done <<< "$high_risk_procs"
  fi
  
  ui_box_end
  local t1=$(etk_now); local dur=$((t1-t0))
  ui_box_start "统计"
  local net_score="green"
  # 确保变量是纯数字
  suspicious_procs=$(echo "$suspicious_procs" | sed 's/[^0-9]//g')
  zombie_procs=$(echo "$zombie_procs" | sed 's/[^0-9]//g')
  suspicious_procs=${suspicious_procs:-0}
  zombie_procs=${zombie_procs:-0}
  [[ $suspicious_procs -gt 0 ]] && net_score="yellow"
  [[ $zombie_procs -gt 0 ]] && net_score="red"
  printf "%s " "$C_BLUE$UI_V$C_RESET"; ui_badges "耗时=$(etk_fmt_dur "$dur")" "网络评分=${net_score};${net_score}"
  if [[ -n "${ETK_CURRENT_LOG:-}" ]]; then
    ui_badges "日志=$(basename "$ETK_CURRENT_LOG")"
  fi
  ui_box_end
}

files_audit() {
  ui_theme_init; ui_box_start "文件系统排查"
  local t0=$(etk_now)
  # 时间窗口输入（默认 24h；支持 30m/24h/7d）
  local win="24h"; local win_in
  if [[ -e /dev/tty && -r /dev/tty ]]; then
    printf "时间窗口(如 30m/24h/7d，默认 24h): " > /dev/tty; read -r win_in < /dev/tty || true
  else
    printf "时间窗口(如 30m/24h/7d，默认 24h): "; read -r win_in || true
  fi
  win=${win_in:-$win}
  # 解析窗口为分钟/天
  local unit="h" num="24"
  if echo "$win" | grep -Eq '^[0-9]+[mhd]$'; then
    num=${win%[mhd]}; unit=${win#$num}
  elif echo "$win" | grep -Eq '^[0-9]+$'; then
    # 纯数字默认按小时处理
    num=$win; unit="h"
  fi
  local mmin=1440 c_use_mtime=0 c_days=1
  case "$unit" in
    m) mmin=$((num));;  # 分钟
    h) mmin=$((num*60));;
    d) mmin=$((num*1440)); c_use_mtime=1; c_days=$((num));;
    *) mmin=1440;;
  esac
  # 显示时间窗口
  local unit_desc
  case "$unit" in
    m) unit_desc="分钟";;
    h) unit_desc="小时";;
    d) unit_desc="天";;
    *) unit_desc="小时";;
  esac
  echo "时间窗口: 最近 $num $unit_desc 内"

  echo "SUID/SGID 文件 (前 200):"; (
    find / -xdev -path "$ROOT_DIR" -prune -o \
      \( -perm -4000 -o -perm -2000 \) -type f -print 2>/dev/null | sed -n '1,200p'
  ) || true; echo
  echo "世界可写目录 (前 200):"; (
    find / -xdev -path "$ROOT_DIR" -prune -o -type d -perm -0002 -print 2>/dev/null | sed -n '1,200p'
  ) || true; echo
  echo "隐藏文件/目录 (前 200):"; (
    find / -xdev -path "$ROOT_DIR" -prune -o -name '.*' -not -path '/proc/*' -not -path '/sys/*' -print 2>/dev/null | sed -n '1,200p'
  ) || true; echo

  echo "最近修改文件 (前 200):"; (
    if [[ $c_use_mtime -eq 1 ]]; then
      find / -xdev -path "$ROOT_DIR" -prune -o -type f -mtime -$c_days -print 2>/dev/null | sed -n '1,200p'
    else
      find / -xdev -path "$ROOT_DIR" -prune -o -type f -mmin -$mmin -print 2>/dev/null | sed -n '1,200p'
    fi
  ) || true; echo

  echo "最近元数据变更(近似创建) (前 200):"; (
    if [[ $c_use_mtime -eq 1 ]]; then
      find / -xdev -path "$ROOT_DIR" -prune -o -type f -ctime -$c_days -print 2>/dev/null | sed -n '1,200p'
    else
      find / -xdev -path "$ROOT_DIR" -prune -o -type f -cmin -$mmin -print 2>/dev/null | sed -n '1,200p'
    fi
  ) || true; echo

  echo "临时目录可执行(最近变更，前 100):"; (
    for d in /tmp /var/tmp /dev/shm; do
      [[ -d "$d" ]] || continue
      if [[ $c_use_mtime -eq 1 ]]; then
        find "$d" -type f -perm -111 -mtime -$c_days -print 2>/dev/null
      else
        find "$d" -type f -perm -111 -mmin -$mmin -print 2>/dev/null
      fi
    done | sed -n '1,100p'
  ) || true; echo

  echo "Web 目录可疑 PHP(最近变更，前 100):"; (
    web_roots=""
    for w in /var/www /usr/share/nginx/html /srv/www /data/www; do [[ -d "$w" ]] && web_roots="$web_roots $w"; done
    if [[ -n "$web_roots" ]]; then
      if [[ $c_use_mtime -eq 1 ]]; then
        find $web_roots -type f -name '*.php' -mtime -$c_days -print0 2>/dev/null \
          | xargs -0 -r grep -El 'eval\(|base64_decode\(|gzinflate\(|system\(|shell_exec' 2>/dev/null | sed -n '1,100p'
      else
        find $web_roots -type f -name '*.php' -mmin -$mmin -print0 2>/dev/null \
          | xargs -0 -r grep -El 'eval\(|base64_decode\(|gzinflate\(|system\(|shell_exec' 2>/dev/null | sed -n '1,100p'
      fi
    else
      echo '(未发现常见 Web 目录)'
    fi
  ) || true; echo

  echo "PATH 目录最近新增/修改可执行(前 100):"; (
    IFS=: read -r -a pdirs <<< "${PATH}"
    for d in "${pdirs[@]}"; do
      [[ -d "$d" ]] || continue
      # 跳过工具箱的bin目录
      if [[ "$d" == "$ROOT_DIR/bin" ]]; then
        continue
      fi
      if [[ $c_use_mtime -eq 1 ]]; then
        find "$d" -type f -perm -111 -mtime -$c_days -print 2>/dev/null
      else
        find "$d" -type f -perm -111 -mmin -$mmin -print 2>/dev/null
      fi
    done | sed -n '1,100p'
  ) || true; echo

  echo "可疑双扩展(最近变更，前 100):"; (
    if [[ $c_use_mtime -eq 1 ]]; then
      find / -xdev -path "$ROOT_DIR" -prune -o -type f -mtime -$c_days -print 2>/dev/null \
        | grep -Ei '\\.(jpg|png|gif|txt|pdf|docx|xls|xlsx|ppt|pptx)\\.(php|exe|sh|bin)$' | sed -n '1,100p'
    else
      find / -xdev -path "$ROOT_DIR" -prune -o -type f -mmin -$mmin -print 2>/dev/null \
        | grep -Ei '\\.(jpg|png|gif|txt|pdf|docx|xls|xlsx|ppt|pptx)\\.(php|exe|sh|bin)$' | sed -n '1,100p'
    fi
  ) || true; echo

  echo "大体积最近变更文件(>100M，前 50):"; (
    if [[ $c_use_mtime -eq 1 ]]; then
      find / -xdev -path "$ROOT_DIR" -prune -o -type f -size +100M -mtime -$c_days -print 2>/dev/null | sed -n '1,50p'
    else
      find / -xdev -path "$ROOT_DIR" -prune -o -type f -size +100M -mmin -$mmin -print 2>/dev/null | sed -n '1,50p'
    fi
  ) || true; echo
  ui_box_end
  local t1=$(etk_now); local dur=$((t1-t0))
  ui_box_start "统计"
  if [[ -n "${ETK_CURRENT_LOG:-}" ]]; then
    printf "%s " "$C_BLUE$UI_V$C_RESET"; ui_badges "耗时=$(etk_fmt_dur "$dur")" "日志=$(basename "$ETK_CURRENT_LOG")"
  else
    printf "%s " "$C_BLUE$UI_V$C_RESET"; ui_badges "耗时=$(etk_fmt_dur "$dur")"
  fi
  ui_box_end
}

auth_audit() {
  ui_theme_init; ui_box_start "账号与认证排查"
  local t0=$(etk_now)
  
  # 用户账号统计
  echo "用户账号统计:"; ui_box_sep
  local total_users shell_users system_users empty_passwd sudo_users
  total_users=$(wc -l < /etc/passwd 2>/dev/null || echo 0)
  shell_users=$(grep -v '/nologin\|/false\|/bin/sync' /etc/passwd 2>/dev/null | wc -l)
  system_users=$(awk -F: '$3 < 1000 {count++} END {print count}' /etc/passwd 2>/dev/null || echo 0)
  empty_passwd=$(awk -F: 'length($2)==0 {count++} END {print count}' /etc/shadow 2>/dev/null || echo 0)
  sudo_users=$(grep -c '^[^#]*ALL.*ALL' /etc/sudoers 2>/dev/null || echo 0)
  
  ui_kv "总用户数" "$total_users"
  ui_kv "有shell用户" "$shell_users"
  ui_kv "系统用户" "$system_users"
  ui_kv "空密码用户" "$empty_passwd"
  ui_kv "sudo权限用户" "$sudo_users"
  
  ui_box_sep
  
  # 特权用户检查
  echo "特权账号检查:"; ui_box_sep
  local root_login uid_zero_users
  if [[ -f /etc/shadow ]]; then
    root_login=$(grep '^root:' /etc/shadow 2>/dev/null | cut -d: -f2 | grep -q '^[^!*]' && echo "启用" || echo "禁用")
  else
    root_login="未知"
  fi
  uid_zero_users=$(awk -F: '$3 == 0 {print $1}' /etc/passwd 2>/dev/null | wc -l)
  
  ui_kv "root登录" "$root_login"
  ui_kv "UID=0用户数" "$uid_zero_users"
  
  # 显示特权用户列表
  if [[ "$uid_zero_users" -gt 1 ]]; then
    local privileged_users
    privileged_users=$(awk -F: '$3 == 0 {print $1}' /etc/passwd 2>/dev/null)
    ui_box_sep
    echo "特权用户列表:"; ui_box_sep
    printf "%s\n" "$privileged_users" | while IFS= read -r user; do
      printf "%s %s\n" "$C_BLUE$UI_V$C_RESET" "$user"
    done
  fi
  
  ui_box_sep
  
  # SSH安全检查
  echo "SSH安全配置:"; ui_box_sep
  local ssh_port="22" ssh_root_login="yes" ssh_password_auth="yes" ssh_pubkey_auth="yes"
  if [[ -f /etc/ssh/sshd_config ]]; then
    ssh_port=$(grep -E '^Port' /etc/ssh/sshd_config 2>/dev/null | awk '{print $2}' | head -n1)
    ssh_root_login=$(grep -E '^PermitRootLogin' /etc/ssh/sshd_config 2>/dev/null | awk '{print $2}' | head -n1)
    ssh_password_auth=$(grep -E '^PasswordAuthentication' /etc/ssh/sshd_config 2>/dev/null | awk '{print $2}' | head -n1)
    ssh_pubkey_auth=$(grep -E '^PubkeyAuthentication' /etc/ssh/sshd_config 2>/dev/null | awk '{print $2}' | head -n1)
    
    ui_kv "SSH端口" "${ssh_port:-22}"
    ui_kv "root SSH登录" "${ssh_root_login:-yes}"
    ui_kv "密码认证" "${ssh_password_auth:-yes}"
    ui_kv "公钥认证" "${ssh_pubkey_auth:-yes}"
  else
    printf "%s %s\n" "$C_BLUE$UI_V$C_RESET" "(SSH配置文件不存在)"
  fi
  
  ui_box_sep
  
  # 最近登录记录
  echo "最近登录活动:"; ui_box_sep
  local recent_logins failed_logins
  recent_logins=$(timeout 5 last -n 5 2>/dev/null | wc -l 2>/dev/null || echo 0)
  failed_logins=$(timeout 5 grep -c "Failed password" /var/log/auth.log 2>/dev/null || timeout 5 grep -c "authentication failure" /var/log/secure 2>/dev/null || echo 0)
  
  ui_kv "最近登录记录" "$recent_logins"
  ui_kv "失败登录尝试" "$failed_logins"
  
  ui_box_end
  local t1=$(etk_now); local dur=$((t1-t0))
  ui_box_start "统计"
  local auth_score="green"
  [[ "$empty_passwd" -gt 0 ]] && auth_score="red"
  [[ "$ssh_root_login" == "yes" ]] && auth_score="yellow"
  [[ "$ssh_password_auth" == "yes" ]] && auth_score="yellow"
  [[ "$failed_logins" -gt 10 ]] && auth_score="yellow"
  printf "%s " "$C_BLUE$UI_V$C_RESET"; ui_badges "耗时=$(etk_fmt_dur "$dur")" "认证评分=${auth_score};${auth_score}"
  if [[ -n "${ETK_CURRENT_LOG:-}" ]]; then
    ui_badges "日志=$(basename "$ETK_CURRENT_LOG")"
  fi
  ui_box_end
}

tasks_audit() {
  ui_theme_init; ui_box_start "计划任务排查"
  local t0=$(etk_now)
  echo "当前用户 crontab:"; (crontab -l 2>/dev/null || echo '(无)'); echo
  echo "/etc/crontab:"; (sed -n '1,200p' /etc/crontab 2>/dev/null || echo '(无)'); echo
  echo "/etc/cron.* 目录:"; (for d in /etc/cron.hourly /etc/cron.daily /etc/cron.weekly /etc/cron.d; do [[ -d "$d" ]] && { echo "-- $d --"; ls -l "$d"; }; done) || true; echo
  ui_box_end
  local t1=$(etk_now); local dur=$((t1-t0))
  ui_box_start "统计"
  if [[ -n "${ETK_CURRENT_LOG:-}" ]]; then
    printf "%s " "$C_BLUE$UI_V$C_RESET"; ui_badges "耗时=$(etk_fmt_dur "$dur")" "日志=$(basename "$ETK_CURRENT_LOG")"
  else
    printf "%s " "$C_BLUE$UI_V$C_RESET"; ui_badges "耗时=$(etk_fmt_dur "$dur")"
  fi
  ui_box_end
}

services_audit() {
  ui_theme_init; ui_box_start "服务与自启动排查"
  local t0=$(etk_now)
  
  # 服务管理系统检测
  local init_system="unknown"
  if command -v systemctl >/dev/null 2>&1 && [[ -d /run/systemd ]]; then
    init_system="systemd"
  elif [[ -f /etc/init.d/cron && -d /etc/init.d ]]; then
    init_system="sysvinit"
  elif command -v service >/dev/null 2>&1; then
    init_system="upstart/sysv"
  fi
  
  ui_kv "初始化系统" "$init_system"
  
  # 初始化服务相关变量
  local total_services=0 enabled_services=0 active_services=0 failed_services=0
  
  # systemd服务分析
  if [[ "$init_system" == "systemd" ]]; then
    echo "systemd服务状态:"; ui_box_sep
    total_services=$(systemctl list-unit-files --type=service 2>/dev/null | grep -c '\.service' || echo 0)
    enabled_services=$(systemctl list-unit-files --type=service --state=enabled 2>/dev/null | grep -c '\.service' || echo 0)
    active_services=$(systemctl list-units --type=service --state=active 2>/dev/null | grep -c '\.service' || echo 0)
    failed_services=$(systemctl list-units --type=service --state=failed 2>/dev/null | grep -c '\.service' || echo 0)
    
    ui_kv "总服务数" "$total_services"
    ui_kv "已启用服务" "$enabled_services"
    ui_kv "正在运行服务" "$active_services"
    ui_kv "失败服务" "$failed_services"
    
    # 显示失败的服务
    if [[ "$failed_services" -gt 0 ]]; then
      ui_box_sep
      echo "失败的服务:"; ui_box_sep
      local failed_list
      failed_list=$(systemctl list-units --type=service --state=failed 2>/dev/null | awk 'NR>1 && NF>0 {print $1}' | head -n5)
      if [[ -n "$failed_list" ]]; then
        printf "%s\n" "$failed_list" | while IFS= read -r service; do
          printf "%s %s\n" "$C_BLUE$UI_V$C_RESET" "$service"
        done
      fi
    fi
    
    # 显示关键服务状态
    ui_box_sep
    echo "关键服务状态:"; ui_box_sep
    local critical_services="sshd cron rsyslog network-manager"
    for svc in $critical_services; do
      if systemctl is-active "$svc" 2>/dev/null | grep -q active; then
        printf "%s %s: %s\n" "$C_BLUE$UI_V$C_RESET" "$svc" "运行中"
      elif systemctl is-enabled "$svc" 2>/dev/null | grep -q enabled; then
        printf "%s %s: %s\n" "$C_BLUE$UI_V$C_RESET" "$svc" "已启用"
      else
        printf "%s %s: %s\n" "$C_BLUE$UI_V$C_RESET" "$svc" "未启用"
      fi
    done
  else
    # SysVinit/Upstart系统
    echo "SysVinit服务状态:"; ui_box_sep
    local total_init_scripts=0 running_services=0
    if [[ -d /etc/init.d ]]; then
      total_init_scripts=$(ls -1 /etc/init.d 2>/dev/null | wc -l)
      ui_kv "初始化脚本数" "$total_init_scripts"
    fi
    
    if command -v service >/dev/null 2>&1; then
      running_services=$(service --status-all 2>/dev/null | grep -c 'is running' || echo 0)
      ui_kv "运行中服务" "$running_services"
    fi
  fi
  
  ui_box_sep
  
  # 自启动程序检查
  echo "自启动程序:"; ui_box_sep
  local cron_jobs rc_local_entries
  cron_jobs=$(find /etc/cron* -type f -exec grep -l '^[^*#]' {} \; 2>/dev/null | wc -l)
  rc_local_entries=$(grep -c '^[[:space:]]*[^#]' /etc/rc.local 2>/dev/null || echo 0)
  
  ui_kv "定时任务文件" "$cron_jobs"
  ui_kv "/etc/rc.local条目" "$rc_local_entries"
  
  # 检查可疑的自启动项
  local suspicious_startup
  suspicious_startup=$(find /etc/init.d /etc/rc*.d -name "*backdoor*" -o -name "*trojan*" -o -name "*hack*" 2>/dev/null | wc -l)
  if [[ "$suspicious_startup" -gt 0 ]]; then
    ui_kv "可疑启动脚本" "$suspicious_startup"
  fi
  
  ui_box_end
  local t1=$(etk_now); local dur=$((t1-t0))
  ui_box_start "统计"
  local service_score="green"
  [[ "$failed_services" -gt 0 ]] && service_score="red"
  [[ "$suspicious_startup" -gt 0 ]] && service_score="red"
  printf "%s " "$C_BLUE$UI_V$C_RESET"; ui_badges "耗时=$(etk_fmt_dur "$dur")" "服务评分=${service_score};${service_score}"
  if [[ -n "${ETK_CURRENT_LOG:-}" ]]; then
    ui_badges "日志=$(basename "$ETK_CURRENT_LOG")"
  fi
  ui_box_end
}

clamav_scan() {
  ui_theme_init; ui_box_start "ClamAV 扫描"
  local cl_bin
  if [[ -x "${ROOT_DIR}/bin/clamscan" ]]; then
    cl_bin="${ROOT_DIR}/bin/clamscan"
  elif [[ -x "${ROOT_DIR}/clamav/bin/clamscan" ]]; then
    cl_bin="${ROOT_DIR}/clamav/bin/clamscan"
  else
    echo "[!] 未找到 clamscan 可执行文件"; ui_box_end; return 1
  fi
  # 统一扩展 ClamAV 依赖库搜索路径（若存在本地 lib）
  if [[ -d "${ROOT_DIR}/clamav/lib" ]]; then
    export LD_LIBRARY_PATH="${ROOT_DIR}/clamav/lib:${LD_LIBRARY_PATH:-}"
  fi
  local db="${ROOT_DIR}/vendor/clamav/db"
  # 病毒库存在性与内容检查
  if [[ ! -d "$db" ]]; then
    echo "[!] 未找到病毒库目录: $db"
    ui_box_end
    ui_box_start "统计"
    printf "%s " "$C_BLUE$UI_V$C_RESET"; ui_badges "Hits=0;green" "文件=0" "耗时=$(etk_fmt_dur 0)" "日志=无(病毒库缺失)"
    ui_box_end
    return 2
  fi
  if [ -z "$(ls -A "$db"/*.cvd "$db"/*.cld 2>/dev/null)" ]; then
    echo "[!] 病毒库为空: $db (需要 *.cvd 或 *.cld，例如 main.cvd/daily.cvd/bytecode.cvd)"
    ui_box_end
    ui_box_start "统计"
    printf "%s " "$C_BLUE$UI_V$C_RESET"; ui_badges "Hits=0;yellow" "文件=0" "耗时=$(etk_fmt_dur 0)" "日志=无(病毒库为空)"
    ui_box_end
    echo "提示: 请确保将离线病毒库放置于 vendor/clamav/db 目录后重试。"
    return 3
  fi
  local target_line
  target_line=$(scan_prompt_paths "请输入扫描路径(空格分隔，回车=全盘 /)" "/")
  local ex target_line
  if declare -F etk_prompt >/dev/null 2>&1; then
    etk_prompt ex     "额外排除正则(例 .*cache.*)" "" ETK_CLAMAV_EXCLUDE
  else
    if [[ -e /dev/tty && -r /dev/tty ]]; then
      printf "额外排除正则(例如 .*cache.*)，直接回车跳过: " > /dev/tty; read -r ex < /dev/tty || true
    else
      printf "额外排除正则(例如 .*cache.*)，直接回车跳过: "; read -r ex || true
    fi
  fi
  local logf="${LOG_DIR}/clamscan_$(ts).log"
  local t0=$(etk_now)
  local ROOT_RE
  ROOT_RE=$(printf '%s' "$ROOT_DIR" | sed -e 's/[][^$.*/+?(){}|]/\\&/g')
  local cmd="$cl_bin --database='$db' --recursive --exclude-dir='^/(proc|sys|dev)(/|$)' --exclude-dir='^${ROOT_RE}(/|$)'"
  if [[ -n "${ex// /}" ]]; then
    cmd="$cmd --exclude-regex='$ex'"
  fi
  cmd="$cmd $target_line"
  echo "命令: $cmd" | tee "$logf"
  set +e
  eval "$cmd" 2>&1 | tee -a "$logf"
  local rc=${PIPESTATUS[0]:-0}
  set -e
  local hits; hits=$(grep -c ' FOUND' "$logf" 2>/dev/null || true); hits=${hits:-0}
  ui_box_end
  
  # 显示发现的病毒文件详情
  if [[ "$hits" -gt 0 ]]; then
    ui_box_start "发现的威胁"
    echo "发现 $hits 个可疑文件："
    ui_box_sep

    # 显示命中文件
    echo "📁 命中文件 ($hits 个):"
    while IFS= read -r line; do
      printf "%s %s\n" "$C_RED$UI_V$C_RESET" "$line"
    done < <(grep ' FOUND' "$logf" | head -20)
    if [[ "$hits" -gt 20 ]]; then
      printf "%s ... (还有 %d 个文件，详见日志)\n" "$C_RED$UI_V$C_RESET" "$((hits-20))"
    fi

    ui_box_end
  fi
  
  local t1=$(etk_now); local dur=$((t1-t0))
  ui_box_start "统计"
  local hcol="green"; [[ "$hits" -gt 0 ]] && hcol="red"
  # 尝试解析扫描文件数
  local scanned
  scanned=$({ grep -E "^Scanned files: *[0-9]+" "$logf" 2>/dev/null || true; } | tail -n1 | awk -F: '{gsub(/ /,"",$2); if ($2=="") print 0; else print $2+0}')
  printf "%s " "$C_BLUE$UI_V$C_RESET"; ui_badges "Hits=${hits};${hcol}" "文件=${scanned}" "耗时=$(etk_fmt_dur "$dur")" "日志=$(basename "$logf")"
  ui_box_end
  return 0
}

quick_triage() {
  ui_theme_init; ui_box_start "快速取证"
  local t0=$(etk_now)
  
  # 执行各个检查模块
  echo "执行安全检查模块..."
  ui_kv "1/4 系统信息检查" "进行中..."
  local lf1="${LOG_DIR}/sysinfo_$(ts).log"
  ETK_CURRENT_LOG="$lf1" sys_info | tee "$lf1"
  
  ui_kv "2/4 网络进程检查" "进行中..."
  local lf2="${LOG_DIR}/netproc_$(ts).log"
  ETK_CURRENT_LOG="$lf2" net_process_audit | tee "$lf2"
  
  ui_kv "3/4 文件系统检查" "进行中..."
  local lf3="${LOG_DIR}/files_$(ts).log"
  ETK_CURRENT_LOG="$lf3" files_audit | tee "$lf3"
  
  ui_kv "4/4 账号认证检查" "进行中..."
  local lf4="${LOG_DIR}/auth_$(ts).log"
  ETK_CURRENT_LOG="$lf4" auth_audit | tee "$lf4"
  
  collect_logs
  
  # 综合评分计算
  local t1=$(etk_now); local dur=$((t1-t0))
  
  # 从日志中提取各个模块的评分
  local sys_score="unknown" net_score="unknown" auth_score="unknown"
  
  # 尝试从日志中解析评分（如果有的话）
  # 这里可以根据实际的评分逻辑来调整
  
  ui_box_start "综合安全评估"
  
  echo "检查结果汇总:"; ui_box_sep
  ui_kv "系统配置评分" "分析中..."
  ui_kv "网络安全评分" "分析中..."
  ui_kv "认证安全评分" "分析中..."
  
  ui_box_sep
  echo "风险等级评估:"; ui_box_sep
  
  # 基于发现的问题给出综合评估
  local high_risks=0 medium_risks=0 low_risks=0

  echo "Checking log file: $lf4"
  # 检查关键安全问题
  if grep -q "root.*启用\|空密码用户.*[1-9]" "$lf4" 2>/dev/null; then
    high_risks=$((high_risks + 1))
  fi
  if grep -q "僵尸进程.*[1-9]\|可疑路径进程.*[1-9]" "$lf2" 2>/dev/null; then
    medium_risks=$((medium_risks + 1))
  fi
  if grep -q "SELinux.*Disabled\|防火墙.*Unknown" "$lf1" 2>/dev/null; then
    low_risks=$((low_risks + 1))
  fi
  
  # 确保变量是数字
  high_risks=$((high_risks + 0))
  medium_risks=$((medium_risks + 0))
  low_risks=$((low_risks + 0))
  
  ui_kv "高风险项目" "$high_risks"
  ui_kv "中风险项目" "$medium_risks"
  ui_kv "低风险项目" "$low_risks"
  
  ui_box_sep
  echo "安全建议:"; ui_box_sep
  
  # 根据风险等级给出建议
  local overall_score="green"
  if [[ $high_risks -gt 0 ]]; then
    overall_score="red"
    printf "%s %s\n" "$C_BLUE$UI_V$C_RESET" "🔴 发现高风险问题，建议立即处理"
  elif [[ $medium_risks -gt 0 ]]; then
    overall_score="yellow"
    printf "%s %s\n" "$C_BLUE$UI_V$C_RESET" "🟡 发现中等风险问题，建议关注"
  else
    printf "%s %s\n" "$C_BLUE$UI_V$C_RESET" "🟢 系统安全状态良好"
  fi
  
  ui_box_end
  
  ui_box_start "统计"
  printf "%s " "$C_BLUE$UI_V$C_RESET"; ui_badges "耗时=$(etk_fmt_dur "$dur")" "综合评分=${overall_score};${overall_score}" "日志文件=4个"
  ui_box_end
}


lynis_run() {
  echo "[Lynis 审计]"
  local lydir="${ROOT_DIR}/vendor/lynis/lynis"
  local ly="${lydir}/lynis"
  if [[ ! -x "$ly" ]]; then
    echo "[!] 未找到 Lynis：$ly"
    return 1
  fi
  
  # 检测BusyBox环境 - Lynis在BusyBox环境中无法正常工作
  if stat --version 2>/dev/null | grep -q "BusyBox" || find --version 2>/dev/null | grep -q "BusyBox"; then
    echo "[!] 检测到BusyBox环境，Lynis无法在此环境中正常运行"
    echo "[!] BusyBox的stat和find命令不支持Lynis所需的GNU选项"
    echo "[!] 建议在完整Linux环境中运行Lynis审计"
    echo "[!] 跳过Lynis审计功能"
    return 1
  fi
  
  local logf="${LOG_DIR}/lynis_$(ts).log"
  local t0=$(etk_now)
  (
    cd "$lydir" && env -u LD_LIBRARY_PATH -u LD_PRELOAD ./lynis audit system --quick --no-colors ${ETK_LYNIS_OPTS:-}
  ) 2>&1 | tee "$logf"
  local rc=${PIPESTATUS[0]:-0}
  local t1=$(etk_now); local dur=$((t1-t0))
  if [[ $rc -ne 0 ]]; then
    echo "[!] Lynis 运行失败，请检查日志：$logf"
  else
    echo "完成。日志已保存：$logf"
  fi
}

rkhunter_run() {
  echo "[rkhunter 检查]"
  local rkroot="${ROOT_DIR}/vendor/rkhunter/rkhunter-1.4.6/files"
  local rk="$rkroot/rkhunter"
  if [[ ! -x "$rk" ]]; then
    echo "[!] 未找到 rkhunter 可执行文件：$rk"
    return 1
  fi
  local logf="${LOG_DIR}/rkhunter_$(ts).log"
  local t0=$(etk_now)
  # 生成本地覆盖配置，确保路径基于当前运行目录
  local conf_local="$rkroot/rkhunter.conf.local"
  {
    echo "TMPDIR=$rkroot"
    echo "DBDIR=$rkroot"
    echo "SCRIPTDIR=$rkroot"
    echo "INSTALLDIR=$rkroot"
    # 避免非必要网络操作
    echo "ROTATE_MIRRORS=0"
    echo "UPDATE_MIRRORS=0"
  } >"$conf_local"
  # 使用 --sk 跳过键盘输入，--nocolors 便于日志解析；指定随包配置与数据目录
  env -u LD_LIBRARY_PATH -u LD_PRELOAD \
    "$rk" --check --sk --nocolors \
    --configfile "$rkroot/rkhunter.conf" \
    --dbdir "$rkroot" \
    --tmpdir "$rkroot" \
    --logfile "$logf" ${ETK_RKHUNTER_OPTS:-} 2>&1 | tee "$logf" || true
  local t1=$(etk_now); local dur=$((t1-t0))
  echo "完成。日志已保存：$logf"
}

loki_scan() {
  ui_theme_init; ui_box_start "LOKI 扫描"
  local lokidir
  lokidir="$(loki_dir_resolve)"
  local logf="${LOG_DIR}/loki_$(ts).log"
  local t0=$(etk_now)
  # 自动确保 Loki 可用
  if [[ ! -f "${lokidir}/loki.py" ]]; then
    echo "[LOKI] 未发现 loki.py，尝试自动安装..."
    ensure_python3_and_loki || true
  fi
  # 确保签名库存在且非空，避免 LOKI 触发联网更新流程
  ensure_loki_signatures "$lokidir"
  if [[ ! -f "${lokidir}/loki.py" ]]; then
    echo "[!] 仍未找到 LOKI：${lokidir}/loki.py，请将 Neo23x0/Loki 放到 tools/Loki 或提供 tools/Loki.tar.gz"
    ui_box_end; return 1
  fi
  # 选择 python3：优先使用 bin/python3
  local pycmd
  # 优先使用本地 venv
  if [[ -x "${BIN_DIR}/py" ]]; then
    pycmd="${BIN_DIR}/py"
  elif [[ -x "${ROOT_DIR}/tools/loki_venv/bin/python3" ]]; then
    pycmd="${ROOT_DIR}/tools/loki_venv/bin/python3"
  else
    pycmd="$(py_find_local || true)"
  fi
  if [[ -z "${pycmd:-}" ]]; then
    echo "[!] 未检测到 python3，请先安装/准备 python3 环境"
    ui_box_end; return 1
  fi
  # 供 LOKI 调用子进程时使用的 python 解释器
  local py_for_loki
  if [[ -x "${ROOT_DIR}/tools/loki_venv/bin/python3" ]]; then
    py_for_loki="${ROOT_DIR}/tools/loki_venv/bin/python3"
  elif [[ -x "${BIN_DIR}/python3" ]]; then
    py_for_loki="${BIN_DIR}/python3"
  else
    py_for_loki="$pycmd"
  fi
  # 预展示关键信息
  local sigdir="${lokidir}/signature-base"
  local yar_cnt="$(find "$sigdir/yara" -type f -name '*.yar' 2>/dev/null | wc -l | tr -d ' ')"
  local custom_cnt="$(find "${ROOT_DIR}/rules/custom-yara" -type f \( -iname '*.yar' -o -iname '*.yara' \) 2>/dev/null | wc -l | tr -d ' ')"
  ui_kv "Python" "$pycmd"
  ui_kv "规则目录" "$sigdir"
  ui_kv "YARA 规则(加载后)" "$yar_cnt 条 (+ custom $custom_cnt)"
  ui_box_end
  # 预检依赖模块（yara, psutil, colorama），缺失则尝试离线安装相应包
  missing_modules=$(env -u LD_PRELOAD "$pycmd" - <<'PY'
mods = ["yara", "psutil", "colorama", "rfc5424logging", "netaddr", "future"]
missing = []
for m in mods:
    try:
        __import__(m)
    except Exception:
        missing.append(m)
print(" ".join(missing))
PY
  ) || true
  if [[ -n "${missing_modules// /}" ]]; then
    echo "[PY] 缺少模块：${missing_modules}，尝试离线安装..."
    # 将模块名映射为 pip 包名
    to_install=()
    for m in $missing_modules; do
      case "$m" in
        yara) to_install+=("yara-python") ;;
        psutil) to_install+=("psutil") ;;
        colorama) to_install+=("colorama") ;;
        rfc5424logging) to_install+=("rfc5424-logging-handler") ;;
        netaddr) to_install+=("netaddr") ;;
        future) to_install+=("future") ;;
      esac
    done
    if [[ ${#to_install[@]} -gt 0 ]]; then
      wheels_dir="${ROOT_DIR}/tools/wheels"
      target_dir="${ROOT_DIR}/tools/pydeps"
      if [[ -x "${ROOT_DIR}/tools/loki_venv/bin/python3" && -d "$wheels_dir" ]]; then
        "${ROOT_DIR}/tools/loki_venv/bin/python3" -m pip install --no-index --find-links="$wheels_dir" "${to_install[@]}" || true
      elif [[ -n "${pycmd:-}" && -d "$wheels_dir" ]]; then
        mkdir -p "$target_dir"
        "$pycmd" - <<PY
import sys, subprocess
args = [sys.executable, "-m", "pip", "install", "--no-index", "--find-links", "${wheels_dir}", "-t", "${target_dir}"] + ${#to_install[@]}*[None]
PY
        # 由于在 here-doc 中构造复杂列表不便，改为分开执行
        for pkg in "${to_install[@]}"; do
          "$pycmd" - <<PY
import sys, subprocess
subprocess.call([sys.executable, "-m", "pip", "install", "--no-index", "--find-links", "${wheels_dir}", "-t", "${target_dir}", "${pkg}"], cwd="${ROOT_DIR}")
PY
        done
        export PYTHONPATH="${ROOT_DIR}/tools/pydeps:${PYTHONPATH:-}"
      else
        echo "[!] 未发现 wheels 目录，且无可用 venv。请将 whl 放至 ${wheels_dir} 后重试。"
      fi
    fi
    # 二次检查
  missing_modules=$(env -u LD_PRELOAD "$pycmd" - <<'PY'
mods = ["yara", "psutil", "colorama", "rfc5424logging", "netaddr", "future"]
missing = []
for m in mods:
    try:
        __import__(m)
    except Exception:
        missing.append(m)
print(" ".join(missing))
PY
    ) || true
    if [[ -n "${missing_modules// /}" ]]; then
      # 仅将 yara 视为致命缺失；psutil/colorama 自动创建 shim 以便在 --noprocscan 下继续运行
      need_fail=0
      for m in $missing_modules; do
        if [[ "$m" == "yara" ]]; then
          need_fail=1
        fi
      done
      if [[ $need_fail -eq 1 ]]; then
        echo "[!] 仍缺少 yara。请在 tools/wheels 放置匹配的 yara-python*.whl（manylinux x86_64/cpXX），或提供本地 venv。"
        return 1
      fi
    # 为 psutil/colorama/netaddr/rfc5424logging 创建轻量 shim
      shim_dir="${ROOT_DIR}/tools/pyshims"
      mkdir -p "$shim_dir"
      for m in $missing_modules; do
        if [[ "$m" == "psutil" ]]; then
          cat >"$shim_dir/psutil.py" <<'PY'
__version__ = "stub"
class NoSuchProcess(Exception):
    pass
class AccessDenied(Exception):
    pass
class ZombieProcess(Exception):
    pass
def process_iter(*args, **kwargs):
    return []
def pid_exists(pid):
    return False
def cpu_count():
    return 1
PY
    elif [[ "$m" == "colorama" ]]; then
          mkdir -p "$shim_dir/colorama"
          cat >"$shim_dir/colorama/__init__.py" <<'PY'
def init(*args, **kwargs):
    return None
class AnsiToWin32:
    pass
class Fore:
    RESET = RED = GREEN = YELLOW = BLUE = MAGENTA = CYAN = WHITE = ""
class Back:
    RESET = RED = GREEN = YELLOW = BLUE = MAGENTA = CYAN = WHITE = ""
class Style:
    RESET_ALL = BRIGHT = DIM = NORMAL = ""
PY
    elif [[ "$m" == "rfc5424logging" ]]; then
      cat >"$shim_dir/rfc5424logging.py" <<'PY'
from logging.handlers import SysLogHandler

class Rfc5424SysLogHandler(SysLogHandler):
  def __init__(self, *args, **kwargs):
    # Fallback to standard SysLogHandler if real handler not available
    super().__init__(*args, **kwargs)
PY
    elif [[ "$m" == "netaddr" ]]; then
      cat >"$shim_dir/netaddr.py" <<'PY'
import ipaddress as _ip

def valid_ipv4(s):
  try:
    _ip.IPv4Address(s)
    return True
  except Exception:
    return False

def valid_ipv6(s):
  try:
    _ip.IPv6Address(s)
    return True
  except Exception:
    return False

def IPNetwork(s):
  try:
    return _ip.ip_network(s, strict=False)
  except Exception:
    raise

def IPAddress(s):
  try:
    return _ip.ip_address(s)
  except Exception:
    raise
PY
        fi
      done
      export PYTHONPATH="${shim_dir}:${PYTHONPATH:-}"
    echo "[PY] 已启用缺失模块 shim（psutil/colorama/rfc5424logging/netaddr），继续执行 LOKI 扫描（--noprocscan）"
    fi
  fi
  local paths_line
    # 兼容：若未定义 print_header（可能未加载到框架扩展），提供一个简易页眉
    if ! declare -F print_header >/dev/null 2>&1; then
      print_header() {
        echo "================ Emergency Toolkit ================"
        echo "时间: $(date '+%F %T')  位置: ${ROOT_DIR}"
        echo "=================================================="
      }
    fi
  # 使用命令替换获取路径输入（兼容 etk_prompt），避免未绑定变量
  paths_line=$(scan_prompt_paths "输入扫描路径（空格分隔，回车=全盘 /）" "/")
  local targets=()
  mapfile -t targets < <(scan_expand_targets "$paths_line")
  echo "== 目录: ${targets[*]} ==" | tee "$logf"
  set +e
  for p in "${targets[@]}"; do
    if [[ -e "$p" ]]; then
  (cd "$lokidir" && env -u LD_PRELOAD "$pycmd" loki.py --intense --printall --noprocscan --noindicator --python "$py_for_loki" -p "$p") 2>&1 | tee -a "$logf"
    else
      echo "[跳过] $p (不存在)" | tee -a "$logf"
    fi
  done
  set -e
  echo "完成。日志：$logf"
  local t1=$(etk_now); local dur=$((t1-t0))
  # 扫描结果统计（美观展示）
  local res_line counts alerts warnings notices nfiles
  res_line=$(grep -E '\[NOTICE\] Results: [0-9]+ alerts?, [0-9]+ warnings?, [0-9]+ notices?' "$logf" | tail -n1 || true)
  if [[ -n "$res_line" ]]; then
    alerts=$(echo "$res_line" | awk '{print $3}' | tr -d ',')
    warnings=$(echo "$res_line" | awk '{print $5}' | tr -d ',')
    notices=$(echo "$res_line" | awk '{print $7}' | tr -d ',')
  else
    alerts=0; warnings=0; notices=0
  fi
  nfiles=$(grep -Ec '^FILE: ' "$logf" 2>/dev/null || true); nfiles=${nfiles:-0}
  
  # 显示发现的威胁详情
  local total_threats=$((alerts + warnings + notices))
  if [[ "$total_threats" -gt 0 ]]; then
    ui_box_start "发现的威胁"
    echo "发现 $total_threats 个威胁项目："
    ui_box_sep

    # 显示告警
    if [[ "$alerts" -gt 0 ]]; then
      echo "🚨 告警 ($alerts 个):"
      grep -E '^MATCH: ' "$logf" | head -10 | while IFS= read -r line; do
        printf "%s %s\n" "$C_RED$UI_V$C_RESET" "$line"
      done
      [[ "$alerts" -gt 10 ]] && printf "%s ... (还有 %d 个告警)\n" "$C_RED$UI_V$C_RESET" "$((alerts-10))"
    fi

    # 显示警告
    if [[ "$warnings" -gt 0 ]]; then
      [[ "$alerts" -gt 0 ]] && echo ""
      echo "⚠️  警告 ($warnings 个):"
      while IFS= read -r line; do
        printf "%s %s\n" "$C_YELLOW$UI_V$C_RESET" "$line"
      done < <(grep -A 10 '^\[WARNING\]' "$logf" | grep -E 'FILE:|REASON_|DESCRIPTION:|MATCH:' | head -10)
      [[ "$warnings" -gt 10 ]] && printf "%s ... (还有 %d 个警告)\n" "$C_YELLOW$UI_V$C_RESET" "$((warnings-10))"
    fi

    # 显示通知
    if [[ "$notices" -gt 0 ]]; then
      [[ "$total_threats" -gt "$warnings" ]] && echo ""
      echo "ℹ️  通知 ($notices 个):"
      while IFS= read -r line; do
        printf "%s %s\n" "$C_BLUE$UI_V$C_RESET" "$line"
      done < <(grep -E '^\[NOTICE\]' "$logf" | grep -v "Results:" | head -10)
      [[ "$notices" -gt 10 ]] && printf "%s ... (还有 %d 个通知)\n" "$C_BLUE$UI_V$C_RESET" "$((notices-10))"
    fi

    # 显示命中文件
    if [[ "$nfiles" -gt 0 ]]; then
      echo ""
      echo "📁 命中文件 ($nfiles 个):"
      grep -E '^FILE: ' "$logf" | sed -E 's/^FILE: *//' | head -10 | while IFS= read -r line; do
        printf "%s %s\n" "$C_CYAN$UI_V$C_RESET" "$line"
      done
      [[ "$nfiles" -gt 10 ]] && printf "%s ... (还有 %d 个文件)\n" "$C_CYAN$UI_V$C_RESET" "$((nfiles-10))"
    fi

    ui_box_end
  else
    ui_box_start "发现的威胁"
    echo "发现 0 个威胁项目"
    ui_box_end
  fi
  local acol="green"; [[ "$alerts" -gt 0 ]] && acol="red"
  local wcol="green"; [[ "$warnings" -gt 0 ]] && wcol="yellow"
  local ncol="green"; [[ "$notices" -gt 0 ]] && ncol="blue"
  ui_box_start "统计" ""
  printf "%s " "$C_BLUE$UI_V$C_RESET"; ui_badges "Alerts=${alerts};${acol}" "Warnings=${warnings};${wcol}" "Notices=${notices};${ncol}" "命中文件=${nfiles}" "耗时=$(etk_fmt_dur "$dur")"
  ui_box_sep
  # Top Signatures
  local top_sig
  top_sig=$(grep -E '^MATCH: ' "$logf" | sed -E 's/^MATCH: *//' | sed -E 's/ *-.*$//' | sed 's/\r$//' | sort | uniq -c | sort -nr | head -n5 || true)
  if [[ -n "${top_sig// /}" ]]; then
    ui_kv "Top 规则" ""
    printf "%s" "$C_BLUE$UI_V$C_RESET"; printf "\n"
    printf "%s\n" "$top_sig" | awk '{c=$1; $1=""; sub(/^ /,""); printf("%s  %s  %s%s\n","", c, $0, "")}'
    printf "%s" "$C_BLUE$UI_V$C_RESET"; printf "\n"
  fi
  ui_box_end
}

ensure_loki_signatures() {
  local lokidir="$1"
  local sigdir="${lokidir}/signature-base"
  # 若目录存在且包含文件，直接返回
  if [[ -d "$sigdir" ]] && find "$sigdir" -type f -mindepth 1 -print -quit 2>/dev/null | grep -q .; then
    return 0
  fi
  mkdir -p "$sigdir/yara" "$sigdir/iocs" "$sigdir/misc"
  # 优先使用离线包 rules/signature-base.tar.gz
  # 若已预先解压到 rules/signature-base/，也会直接合并到目标
  if [[ -d "${ROOT_DIR}/rules/signature-base" ]]; then
    cp -a "${ROOT_DIR}/rules/signature-base/." "$sigdir/" 2>/dev/null || true
  fi
  if [[ -f "${ROOT_DIR}/rules/signature-base.tar.gz" ]]; then
    local tmp="${ROOT_DIR}/tools/.sig_unpack_$(ts)"
    mkdir -p "$tmp"
    tar -xzf "${ROOT_DIR}/rules/signature-base.tar.gz" -C "$tmp" || true
    # 选择正确的根目录（包含 yara 或 misc 的目录）
    local srcroot=""
    if [[ -d "$tmp/signature-base" ]]; then
      srcroot="$tmp/signature-base"
    else
      # 若解包后是 signature-base-<hash>/ 结构
      local firstdir
      firstdir=$(find "$tmp" -mindepth 1 -maxdepth 1 -type d | head -n1 || true)
      if [[ -n "$firstdir" ]]; then
        srcroot="$firstdir"
      else
        srcroot="$tmp"
      fi
      # 再次探测内层是否存在含有 yara 的目录
      if [[ ! -d "$srcroot/yara" ]]; then
        local cand
        cand=$(find "$tmp" -type d -name yara -print -quit 2>/dev/null | sed 's#/yara$##' || true)
        if [[ -n "$cand" ]]; then srcroot="$cand"; fi
      fi
    fi
    # 拷贝内容到期望布局
    if [[ -n "$srcroot" ]]; then
      cp -a "$srcroot/." "$sigdir/" 2>/dev/null || true
    fi
    rm -rf "$tmp"
  fi
  # 追加自定义签名（可选）：rules/custom-signatures.tar.gz
  if [[ -f "${ROOT_DIR}/rules/custom-signatures.tar.gz" ]]; then
    local tmpc="${ROOT_DIR}/tools/.sig_custom_$(ts)"
    mkdir -p "$tmpc"
    tar -xzf "${ROOT_DIR}/rules/custom-signatures.tar.gz" -C "$tmpc" || true
    local csrc
    csrc=$(find "$tmpc" -type d -name yara -print -quit 2>/dev/null | sed 's#/yara$##' || true)
    [[ -z "$csrc" ]] && csrc="$tmpc"
    cp -a "$csrc/." "$sigdir/" 2>/dev/null || true
    rm -rf "$tmpc"
  fi
  # 追加自定义 YARA 与 IOC 目录（可选）
  if [[ -d "${ROOT_DIR}/rules/custom-yara" ]]; then
    mkdir -p "$sigdir/yara"
    cp -a "${ROOT_DIR}/rules/custom-yara/." "$sigdir/yara/" 2>/dev/null || true
  fi
  if [[ -d "${ROOT_DIR}/rules/custom-iocs" ]]; then
    mkdir -p "$sigdir/iocs"
    cp -a "${ROOT_DIR}/rules/custom-iocs/." "$sigdir/iocs/" 2>/dev/null || true
  fi
  # 如出现解包目录嵌套，扁平化一次
  if [[ ! -d "$sigdir/yara" || -z "$(find "$sigdir/yara" -type f -name '*.yar' -print -quit 2>/dev/null)" ]]; then
    local nest
    nest=$(find "$sigdir" -mindepth 1 -maxdepth 1 -type d | head -n1 || true)
    if [[ -n "$nest" && -d "$nest/yara" ]]; then
      cp -a "$nest/." "$sigdir/" 2>/dev/null || true
      rm -rf "$nest"
    fi
  fi
  # 仍为空则写入最小占位规则，避免 LOKI 触发在线更新，同时补齐 misc 文件
  if ! find "$sigdir" -type f -mindepth 1 -print -quit 2>/dev/null | grep -q .; then
    cat >"$sigdir/yara/ETK_DUMMY.yar" <<'YAR'
rule ETK_DUMMY_NO_MATCH {
  condition:
    false
}
YAR
    echo "# ETK minimal IOC placeholder" >"$sigdir/iocs/filename-iocs.txt"
  fi
  # 补齐 Loki 期望的 misc 文件，避免错误日志
  [[ -f "$sigdir/misc/file-type-signatures.txt" ]] || : >"$sigdir/misc/file-type-signatures.txt"
}

ensure_python3_and_loki() {
  echo "[安装/更新 Python3 + LOKI]"
  local pycmd
  pycmd="$(py_find_local || true)"
  if [[ -z "${pycmd:-}" ]]; then
    echo "[!] 未检测到 python3，请在目标系统自行安装 (例如 apt/yum/pyenv)。"
  else
    echo "[OK] 已检测到 python3: $($pycmd --version 2>/dev/null | tr -d '\n')"
    # 若工具箱 bin/ 下无 python3，且本地 tools 下找到，则建立软链方便后续调用
    if [[ ! -x "${BIN_DIR}/python3" && "$pycmd" != "python3" ]]; then
      mkdir -p "${BIN_DIR}" || true
      ln -sf "${pycmd}" "${BIN_DIR}/python3" || true
    fi
  fi
  local lokidir
  lokidir="$(loki_dir_resolve)"
  mkdir -p "${ROOT_DIR}/tools"
  if [[ -d "$lokidir/.git" ]]; then
    echo "[LOKI] 已存在仓库（离线环境，不做 git 更新）"
  elif [[ -f "${ROOT_DIR}/tools/Loki.tar.gz" ]]; then
    echo "[LOKI] 检测到离线包 tools/Loki.tar.gz，正在解压..."
    rm -rf "$lokidir" && mkdir -p "$lokidir"
    # 解包后目录名可能为 Loki-*, 统一移动为 tools/Loki
    tmpdir="${ROOT_DIR}/tools/.loki_unpack_$(ts)"
    mkdir -p "$tmpdir"
    tar -xzf "${ROOT_DIR}/tools/Loki.tar.gz" -C "$tmpdir"
    mv "$tmpdir"/Loki-* "$lokidir" 2>/dev/null || mv "$tmpdir"/* "$lokidir" 2>/dev/null || true
    rm -rf "$tmpdir"
  else
    echo "[!] 未安装 git/curl/wget，无法联网获取 Loki。可将 Loki 源码打包为 tools/Loki.tar.gz 后重试。"
  fi
  if [[ -f "${lokidir}/loki.py" ]]; then
    echo "[OK] LOKI 就绪：${lokidir}/loki.py"
  else
    echo "[!] 未找到 loki.py，请检查 ${lokidir}"
  fi

  # 安装 Loki 依赖（yara-python 等），优先在本地虚拟环境中
  local venv_dir="${ROOT_DIR}/tools/loki_venv"
  local vpy
  if [[ -n "${pycmd:-}" ]]; then
    if [[ ! -x "${venv_dir}/bin/python3" ]]; then
      echo "[PY] 准备本地虚拟环境: ${venv_dir}"
      "$pycmd" -m venv "$venv_dir" 2>/dev/null || true
    fi
    if [[ -x "${venv_dir}/bin/python3" ]]; then
      vpy="${venv_dir}/bin/python3"
      echo "[PY] 本地 venv: $($vpy --version 2>/dev/null | tr -d '\n')"
      "$vpy" -m ensurepip --upgrade 2>/dev/null || true
      "$vpy" -m pip install -U pip 2>/dev/null || true
      if [[ -d "${ROOT_DIR}/tools/wheels" ]]; then
        echo "[PY] 离线安装依赖（tools/wheels）: yara-python colorama psutil"
        "$vpy" -m pip install --no-index --find-links="${ROOT_DIR}/tools/wheels" yara-python colorama psutil || true
      fi
      # 将 venv python 链接到 bin 方便调用
      ln -sf "$vpy" "${BIN_DIR}/python3" 2>/dev/null || true
      # 提示可用 bin/py 包装器
      if [[ -f "${BIN_DIR}/py" ]]; then echo "[PY] 可使用 ${BIN_DIR}/py 调用本地 Python"; fi
    else
      echo "[!] 未能创建 venv，尝试使用 --target 离线安装到 tools/pydeps"
      # 确保 pip 可用
      "$pycmd" -m ensurepip --upgrade 2>/dev/null || true
      if [[ -d "${ROOT_DIR}/tools/wheels" ]]; then
        mkdir -p "${ROOT_DIR}/tools/pydeps"
        "$pycmd" -m pip install --no-index --find-links="${ROOT_DIR}/tools/wheels" \
          -t "${ROOT_DIR}/tools/pydeps" yara-python colorama psutil || true
        echo "[PY] 已将依赖安装到 tools/pydeps（运行时将通过 PYTHONPATH 注入）"
      else
        echo "[!] 未发现 tools/wheels，且 venv 创建失败。请提供离线 wheels。"
      fi
    fi
  fi
}

lmd_setup_portable() {
  local src="${ROOT_DIR}/vendor/lmd/maldetect-1.6.6/files"
  local dst="${ROOT_DIR}/vendor/lmd/portable"
  if [[ ! -x "$src/maldet" ]]; then
    echo "[!] 未找到 LMD 可执行文件：$src/maldet"
    return 1
  fi
  mkdir -p "$dst" || true
  if [[ ! -x "$dst/maldet" ]]; then
    echo "[LMD] 初始化便携副本..."
    cp -a "$src/." "$dst/" || return 1
    chmod +x "$dst/maldet" || true
    # 重写 maldet 与 internals.conf 的 inspath 指向便携目录
    sed -i "s|^inspath=.*$|inspath='$dst'|" "$dst/maldet" 2>/dev/null || true
    sed -i "s|^inspath=.*$|inspath=$dst|" "$dst/internals/internals.conf" 2>/dev/null || true
  fi
  # 准备运行所需目录
  mkdir -p "$dst/logs" "$dst/tmp" "$dst/pub" "$dst/quarantine" "$dst/sess" || true
  # 兼容 BusyBox find：去掉 -regextype 以防空文件列表
  if grep -q '^find_opts=' "$dst/internals/internals.conf" 2>/dev/null; then
    sed -i 's/^find_opts=.*/find_opts=""/' "$dst/internals/internals.conf" 2>/dev/null || true
  fi
  # 最小化忽略路径：仅排除伪文件系统与工具箱自身
  local ipfile="$dst/ignore_paths.portable"
  {
    echo "/proc"
    echo "/sys"
    echo "/dev"
    echo "/run"
    echo "$ROOT_DIR"
  } >"$ipfile"
  if grep -q '^ignore_paths=' "$dst/internals/internals.conf" 2>/dev/null; then
    sed -i "s|^ignore_paths=.*$|ignore_paths=\"$ipfile\"|" "$dst/internals/internals.conf" 2>/dev/null || true
  fi
  # 不全局导出 PATH/LD_LIBRARY_PATH，避免影响系统工具；clamscan 通过包装器处理
}

lmd_scan() {
  echo "[LMD 扫描] (便携模式)"
  lmd_setup_portable || return 1
  local base="${ROOT_DIR}/vendor/lmd/portable"
  local maldet="$base/maldet"
  local logf="${LOG_DIR}/lmd_$(ts).log"
  local ex target_line
  target_line=$(scan_prompt_paths "请输入扫描路径(空格分隔，回车=全盘 /)" "/")
  if declare -F etk_prompt >/dev/null 2>&1; then
    etk_prompt ex     "额外排除正则(例 .*cache.*)" "" ETK_LMD_EXCLUDE
  else
    if [[ -e /dev/tty && -r /dev/tty ]]; then
      printf "额外排除正则(例如 .*cache.*)，直接回车跳过: " > /dev/tty; read -r ex < /dev/tty || true
    else
      printf "额外排除正则(例如 .*cache.*)，直接回车跳过: "; read -r ex || true
    fi
  fi
  # 展开并去重目标，避免扫描工具箱自身
  local targets=()
  mapfile -t targets < <(scan_expand_targets "$target_line")
  # maldet 的 --scan-all 需要紧跟绝对路径（可用逗号分隔多个路径）
  local scan_paths=""
  if [[ ${#targets[@]} -gt 0 ]]; then
    scan_paths="${targets[0]}"
    if [[ ${#targets[@]} -gt 1 ]]; then
      local i
      for i in "${targets[@]:1}"; do
        scan_paths+=",$i"
      done
    fi
  fi
  local args=(--scan-all "$scan_paths" \
    --config-option quarantine_hits=0 \
    --config-option quarantine_clean=0 \
    --config-option clamscan_extraopts="--exclude-dir='^/(proc|sys|dev)(/|$)' --database='${ROOT_DIR}/vendor/clamav/db'" \
    --config-option clamdscan_extraopts="--exclude-dir='^/(proc|sys|dev)(/|$)'" )
  # 优先使用工具箱内 clamscan 包装器
  args+=( --config-option clamscan="${ROOT_DIR}/bin/clamscan" )
  if [[ -n "${ex// /}" ]]; then
    args+=(--exclude-regex "$ex")
  fi
  local t0=$(etk_now)
  set +e
  env -u LD_LIBRARY_PATH -u LD_PRELOAD "$maldet" "${args[@]}" 2>&1 | tee "$logf"
  local rc=${PIPESTATUS[0]:-0}
  set -e
  local t1=$(etk_now); local dur=$((t1-t0))
  etk_scan_begin "LMD 扫描"
  # 解析命中数（支持多种格式：malware hits N, hits: N, hits=N, hits N 等）
  local hits
  # 首先尝试匹配 "malware hits N"
  hits=$({ grep -Eoi 'malware hits [0-9]+' "$logf" 2>/dev/null || true; } | tail -n1 | grep -Eo '[0-9]+' || true)
  # 如果没找到，尝试匹配其他格式的 hits
  if [[ -z "$hits" || "$hits" -eq 0 ]]; then
    hits=$({ grep -Eoi 'hits[[:space:]]*[:=]?[[:space:]]*[0-9]+' "$logf" 2>/dev/null || true; } | tail -n1 | grep -Eo '[0-9]+' || true)
  fi
  # 如果还是没找到，从 "processing scan results for hits: N hits" 格式中提取
  if [[ -z "$hits" || "$hits" -eq 0 ]]; then
    hits=$({ grep -Eoi 'processing scan results for hits:[[:space:]]*[0-9]+' "$logf" 2>/dev/null || true; } | tail -n1 | grep -Eo '[0-9]+' || true)
  fi
  hits=${hits:-0}
  if [[ "$hits" -gt 0 ]]; then etk_scan_hit; fi
  etk_scan_end

  # LMD 退出码含义：
  # 0 = 成功，无病毒
  # 1 = 扫描失败
  # 2 = 成功，发现病毒
  local scan_status="成功"
  if [[ $rc -eq 1 ]]; then
    scan_status="失败"
    echo "[!] LMD 扫描失败(退出码=$rc)，请检查日志：$logf"
  elif [[ $rc -eq 2 ]]; then
    scan_status="成功(发现病毒)"
    echo "[!] LMD 扫描完成，发现病毒(退出码=$rc)"
  elif [[ $rc -ne 0 ]]; then
    scan_status="未知状态"
    echo "[!] LMD 扫描未知状态(退出码=$rc)，请检查日志：$logf"
  fi

  echo "完成。日志已保存：$logf"

  # 提取扫描ID，用于后续操作
  local scan_id=""
  scan_id=$(grep -Eo 'scan id[[:space:]]*[:=][[:space:]]*[0-9]+\.[0-9]+' "$logf" 2>/dev/null | tail -n1 | grep -Eo '[0-9]+\.[0-9]+' || true)
  if [[ -z "$scan_id" ]]; then
    # 尝试匹配日期格式的扫描ID，如 250923-0804.74715
    scan_id=$(grep -Eo '[0-9]{6}-[0-9]{4}\.[0-9]+' "$logf" 2>/dev/null | tail -n1 || true)
  fi

  # 如果发现威胁，提供查看详细报告的选项
  if [[ "$hits" -gt 0 && -n "$scan_id" ]]; then
    echo ""
    echo "发现 $hits 个威胁，是否要查看详细扫描报告？"
    echo "报告将使用 vi 编辑器打开，查看完毕后请按 :q 退出"
    if declare -F etk_prompt >/dev/null 2>&1; then
      local view_report="n"
      etk_prompt view_report "查看详细报告？(y/N)" "n" ""
      if [[ "$view_report" =~ ^[Yy] ]]; then
        echo "正在打开扫描报告..."
        env -u LD_LIBRARY_PATH -u LD_PRELOAD "$maldet" --report "$scan_id"
        echo "报告查看完毕，继续执行..."
      fi
    else
      echo -n "查看详细报告？(y/N): "
      local response
      read -r response || true
      if [[ "$response" =~ ^[Yy] ]]; then
        echo "正在打开扫描报告..."
        env -u LD_LIBRARY_PATH -u LD_PRELOAD "$maldet" --report "$scan_id"
        echo "报告查看完毕，继续执行..."
      fi
    fi
  fi

  # 显示发现的威胁详情
  if [[ "$hits" -gt 0 ]]; then
    ui_box_start "发现的威胁"
    echo "发现 $hits 个命中："
    ui_box_sep

    # 解析扫描报告中的具体病毒文件（如果报告已获取）
    local virus_files=()
    if [[ -n "$scan_id" ]]; then
      # 从扫描报告中提取病毒文件列表（如果报告已保存到日志）
      # LMD报告格式通常是: 文件路径 : 威胁名称
      # 查找报告内容中的文件列表
      mapfile -t virus_files < <(grep -A 200 "SCAN ID: $scan_id" "$logf" 2>/dev/null | \
        grep -E '^/[^[:space:]]+.*:' | \
        sed 's/^[[:space:]]*//' | \
        grep -v "SCAN ID:" | \
        head -20 || true)

      # 如果没找到，尝试更宽泛的搜索
      if [[ ${#virus_files[@]} -eq 0 ]]; then
        mapfile -t virus_files < <(grep -E '^/[^[:space:]]+.*:' "$logf" 2>/dev/null | \
          grep -v "SCAN ID:" | \
          head -20 || true)
      fi
    fi

    # 如果扫描报告中没有找到，尝试从原始日志中解析其他格式
    if [[ ${#virus_files[@]} -eq 0 ]]; then
      # 尝试匹配其他可能的格式
      mapfile -t virus_files < <(grep -E '(FOUND|INFECTED|MALWARE).*:' "$logf" 2>/dev/null | \
        head -20 || true)
    fi

    # 显示病毒文件列表
    if [[ ${#virus_files[@]} -gt 0 ]]; then
      local count=0
      for file_info in "${virus_files[@]}"; do
        if [[ -n "$file_info" ]]; then
          printf "%s %s\n" "$C_RED$UI_V$C_RESET" "$file_info"
          ((count++))
          [[ $count -ge 20 ]] && break
        fi
      done
    else
      # 如果仍然找不到具体文件，显示统计信息和获取报告的命令
      printf "%s 扫描发现 %d 个威胁文件\n" "$C_YELLOW$UI_V$C_RESET" "$hits"
      printf "%s LMD隔离功能已禁用，启用命令：\n" "$C_CYAN$UI_V$C_RESET"
      if [[ -n "$scan_id" ]]; then
        printf "%s   maldet -q %s  (隔离威胁文件)\n" "$C_CYAN$UI_V$C_RESET" "$scan_id"
        printf "%s   maldet --report %s  (查看详细报告)\n" "$C_CYAN$UI_V$C_RESET" "$scan_id"
        printf "%s   maldet --clean %s  (清理威胁文件)\n" "$C_CYAN$UI_V$C_RESET" "$scan_id"
      fi
      printf "%s 完整日志：%s\n" "$C_BLUE$UI_V$C_RESET" "$logf"

      # 显示日志中的隔离相关信息
      local quarantine_info
      quarantine_info=$(grep -i "quarantine\|is disabled" "$logf" 2>/dev/null | head -3 || true)
      if [[ -n "$quarantine_info" ]]; then
        echo ""
        printf "%s 隔离状态信息：\n" "$C_CYAN$UI_V$C_RESET"
        echo "$quarantine_info" | while IFS= read -r line; do
          printf "%s %s\n" "$C_CYAN$UI_V$C_RESET" "$line"
        done
      fi
    fi

    # 显示命中总数统计
    local total_files_found=0
    if [[ ${#virus_files[@]} -gt 0 ]]; then
      total_files_found=${#virus_files[@]}
    fi

    if [[ $total_files_found -gt 20 ]]; then
      printf "%s ... (还有 %d 个威胁文件，详见完整报告)\n" "$C_RED$UI_V$C_RESET" "$((total_files_found-20))"
    fi

    ui_box_end
  fi

  # 统一统计展示（使用解析到的 hits 数）
  ui_box_start "统计"
  local lcol="green"; [[ "$hits" -gt 0 ]] && lcol="red"
  printf "%s " "$C_BLUE$UI_V$C_RESET"; ui_badges "Hits=${hits};${lcol}" "状态=${scan_status}" "耗时=$(etk_fmt_dur "$dur")" "日志=$(basename "$logf")"
  if [[ -n "$scan_id" ]]; then
    printf "%s " "$C_BLUE$UI_V$C_RESET"; ui_badges "扫描ID=${scan_id}"
  fi
  ui_box_end
}
 
frp_default_confs() {
  # 仅在不存在时生成默认配置
  local frpc_ini="${CONF_DIR}/frp/frpc.ini"
  local frps_ini="${CONF_DIR}/frp/frps.ini"
  if [[ ! -f "$frpc_ini" ]]; then
    cat >"$frpc_ini" <<'EOF'
[common]
server_addr = 1.2.3.4
server_port = 7000
auth.method = token
auth.token = change_me_token
transport.protocol = tcp

[ssh]
type = tcp
local_ip = 127.0.0.1
local_port = 22
remote_port = 60022
EOF
  fi
  if [[ ! -f "$frps_ini" ]]; then
    cat >"$frps_ini" <<'EOF'
[common]
bind_addr = 0.0.0.0
bind_port = 7000
auth.method = token
auth.token = change_me_token
dashboard.addr = 0.0.0.0
dashboard.port = 7500
dashboard.user = admin
dashboard.pwd = admin
EOF
  fi
}

frp_start() {
  mkdir -p "${LOG_DIR}/frp"
  frp_default_confs
  local mode=${1:-}
  if [[ "$mode" == frpc ]]; then
    if [[ ! -x "${BIN_DIR}/frpc" ]]; then
      echo "[!] 未找到 ${BIN_DIR}/frpc"
      return 1
    fi
    nohup "${BIN_DIR}/frpc" -c "${CONF_DIR}/frp/frpc.ini" \
      >>"${LOG_DIR}/frp/frpc.out" 2>&1 & echo $! >"${LOG_DIR}/frp/frpc.pid"
    echo "frpc 已启动，PID=$(cat "${LOG_DIR}/frp/frpc.pid")"
  elif [[ "$mode" == frps ]]; then
    if [[ ! -x "${BIN_DIR}/frps" ]]; then
      echo "[!] 未找到 ${BIN_DIR}/frps"
      return 1
    fi
    nohup "${BIN_DIR}/frps" -c "${CONF_DIR}/frp/frps.ini" \
      >>"${LOG_DIR}/frp/frps.out" 2>&1 & echo $! >"${LOG_DIR}/frp/frps.pid"
    echo "frps 已启动，PID=$(cat "${LOG_DIR}/frp/frps.pid")"
  else
    echo "用法: frp_start frpc|frps"
    return 2
  fi
}

web_log_hunt() {
  echo "[Web 日志猎杀]"
  local logf="${LOG_DIR}/weblog_$(ts).log"
  local nginx_access nginx_error apache_access php_fpm
  local t0=$(etk_now)
  etk_scan_begin "Web 日志猎杀"
  if declare -F etk_prompt >/dev/null 2>&1; then
    etk_prompt nginx_access "Nginx access.log 路径(留空跳过)" "" ETK_WEBLOG_NGINX_ACCESS
    etk_prompt nginx_error  "Nginx error.log 路径(留空跳过)"  "" ETK_WEBLOG_NGINX_ERROR
    etk_prompt apache_access "Apache access_log 路径(留空跳过)" "" ETK_WEBLOG_APACHE_ACCESS
    etk_prompt php_fpm      "PHP-FPM log 路径(留空跳过)"     "" ETK_WEBLOG_PHPFPM
  else
    printf "Nginx access.log 路径（默认 /var/log/nginx/access.log，留空跳过）："
  if [[ -e /dev/tty && -r /dev/tty ]]; then read -r nginx_access < /dev/tty || true; else read -r nginx_access || true; fi
    printf "Nginx error.log 路径（默认 /var/log/nginx/error.log，留空跳过）："
  if [[ -e /dev/tty && -r /dev/tty ]]; then read -r nginx_error < /dev/tty || true; else read -r nginx_error || true; fi
    printf "Apache access_log 路径（默认 /var/log/apache2/access.log 或 /var/log/httpd/access_log，留空跳过）："
  if [[ -e /dev/tty && -r /dev/tty ]]; then read -r apache_access < /dev/tty || true; else read -r apache_access || true; fi
    printf "PHP-FPM log 路径（默认 /var/log/php*-fpm.log，留空跳过）："
  if [[ -e /dev/tty && -r /dev/tty ]]; then read -r php_fpm < /dev/tty || true; else read -r php_fpm || true; fi
  fi
  {
    echo "== Web 日志异常模式 =="
    echo "- 高频 POST/大请求体/可疑 UA/长 base64 参数/5xx 峰值"
    # 访问日志：可疑 UA、可疑参数、POST 频率
    if [[ -z "$nginx_access" && -f /var/log/nginx/access.log ]]; then nginx_access=/var/log/nginx/access.log; fi
    if [[ -n "$nginx_access" && -f "$nginx_access" ]]; then
      echo "-- Nginx access: $nginx_access --"
      grep -E "(POST|%3D%3D|base64|wget|curl|cmd=|eval|assert|/..%2f|/\x2e\x2e/)" "$nginx_access" 2>/dev/null | sed 's/^/WEB_HIT: /'
      awk '{cnt[$1]++} END{for(ip in cnt) if(cnt[ip]>100) printf("WEB_STAT: 高频访问IP %s 次数 %d\n", ip, cnt[ip])}' "$nginx_access" 2>/dev/null
    fi
    if [[ -z "$apache_access" ]]; then
      [[ -f /var/log/apache2/access.log ]] && apache_access=/var/log/apache2/access.log
      [[ -z "$apache_access" && -f /var/log/httpd/access_log ]] && apache_access=/var/log/httpd/access_log
    fi
    if [[ -n "$apache_access" && -f "$apache_access" ]]; then
      echo "-- Apache access: $apache_access --"
      grep -E "(POST|%3D%3D|base64|wget|curl|cmd=|eval|assert|/..%2f|/\x2e\x2e/)" "$apache_access" 2>/dev/null | sed 's/^/WEB_HIT: /'
      awk '{cnt[$1]++} END{for(ip in cnt) if(cnt[ip]>100) printf("WEB_STAT: 高频访问IP %s 次数 %d\n", ip, cnt[ip])}' "$apache_access" 2>/dev/null
    fi
    # 错误日志：5xx 峰值
    if [[ -z "$nginx_error" && -f /var/log/nginx/error.log ]]; then nginx_error=/var/log/nginx/error.log; fi
    if [[ -n "$nginx_error" && -f "$nginx_error" ]]; then
      echo "-- Nginx error: $nginx_error --"
      grep -E "( 5[0-9]{2} | upstream prematurely closed|PHP Fatal|segmentation fault)" "$nginx_error" 2>/dev/null | sed 's/^/WEB_HIT: /'
    fi
    if [[ -z "$php_fpm" ]]; then php_fpm=$(ls /var/log/php*-fpm.log 2>/dev/null | head -n1 || true); fi
    if [[ -n "$php_fpm" && -f "$php_fpm" ]]; then
      echo "-- PHP-FPM: $php_fpm --"
      grep -E "(WARNING|ERROR|stack|slowlog|exec|proc_open|system)" "$php_fpm" 2>/dev/null | sed 's/^/WEB_HIT: /'
    fi
  } | tee "$logf"
  local t1=$(etk_now); local dur=$((t1-t0))
  # 统计命中
  local hits
  hits=$({ grep -E '^(WEB_HIT|WEB_STAT):' "$logf" 2>/dev/null || true; } | wc -l | tr -d ' ')
  hits=${hits:-0}
  if [[ $hits -gt 0 ]]; then etk_scan_hit; fi
  etk_scan_end
  echo "完成。日志：$logf"
  # 统一统计展示
  ui_box_start "统计"
  local hcol="green"; [[ $hits -gt 0 ]] && hcol="yellow"
  printf "%s " "$C_BLUE$UI_V$C_RESET"; ui_badges "Hits=${hits};${hcol}" "耗时=$(etk_fmt_dur "$dur")" "日志=$(basename "$logf")"
  ui_box_end
}

# 使用 GoAccess 生成 Web 日志 HTML 报告
goaccess_report() {
  ui_theme_init; ui_box_start "GoAccess 报表"
  local goa_bin="${BIN_DIR}/goaccess"
  if [[ ! -x "$goa_bin" ]]; then
    echo "[!] 未找到 ${goa_bin}。将回退到简易‘Web 日志猎杀’。"
    ui_box_end
    web_log_hunt
    return 0
  fi
  mkdir -p "${LOG_DIR}" || true
  local out_html="${LOG_DIR}/goaccess_$(ts).html"
  local out_log="${LOG_DIR}/goaccess_$(ts).log"
  local t0=$(etk_now)

  # 收集日志路径（可空格分隔）；留空则尝试自动探测
  local logs_line fmt dfmt tfmt
  if declare -F etk_prompt >/dev/null 2>&1; then
    etk_prompt logs_line "访问日志路径(可空格分隔，回车自动探测)" "" ETK_GOA_LOGS
    etk_prompt fmt       "日志格式(COMBINED/COMMON/VCOMBINED/LTSV/JSON)" "COMBINED" ETK_GOA_FMT
    etk_prompt dfmt      "日期格式(默认 %d/%b/%Y)" "%d/%b/%Y" ETK_GOA_DFMT
    etk_prompt tfmt      "时间格式(默认 %H:%M:%S)" "%H:%M:%S" ETK_GOA_TFMT
  else
  if [[ -e /dev/tty && -r /dev/tty ]]; then printf "访问日志路径(可空格分隔，回车自动探测): " > /dev/tty; read -r logs_line < /dev/tty || true; else printf "访问日志路径(可空格分隔，回车自动探测): "; read -r logs_line || true; fi
    fmt="COMBINED"; dfmt="%d/%b/%Y"; tfmt="%H:%M:%S"
  fi
  fmt=${fmt:-COMBINED}; dfmt=${dfmt:-%d/%b/%Y}; tfmt=${tfmt:-%H:%M:%S}

  # 生成日志文件数组（支持轮转与 .gz）
  local files=()
  if [[ -n "${logs_line// /}" ]]; then
    local p
    for p in $logs_line; do [[ -f "$p" ]] && files+=("$p"); done
  else
    # 自动探测常见路径（包含轮转与压缩）
    for p in \
      /var/log/nginx/access.log \
      /var/log/nginx/access.log.* \
      /var/log/nginx/*access*.log* \
      /var/log/apache2/access.log \
      /var/log/apache2/access.log.* \
      /var/log/httpd/access_log \
      /var/log/httpd/access_log.*; do
      for f in $p; do [[ -f "$f" ]] && files+=("$f"); done
    done
  fi
  if [[ ${#files[@]} -eq 0 ]]; then
    ui_box_end
    echo "[!] 未找到可用访问日志，自动回退到简易‘Web 日志猎杀’。"
    web_log_hunt
    return 0
  fi

  ui_kv "输入文件" "${#files[@]} 个"
  ui_kv "格式" "$fmt"
  ui_kv "输出" "$(basename "$out_html")"
  ui_box_end

  # 运行 GoAccess 生成 HTML 报告
  # 若包含 .gz 或多文件，使用流式合并（gzip -cd 以支持压缩与非压缩）
  local args=(--no-global-config --ignore-crawlers --log-format="$fmt" --date-format="$dfmt" --time-format="$tfmt" -o "$out_html")
  local has_gz=0
  local i
  for i in "${files[@]}"; do [[ "$i" == *.gz ]] && { has_gz=1; break; }; done
  set +e
  if [[ ${#files[@]} -gt 1 || $has_gz -eq 1 ]]; then
    # 构建解压合并命令
    {
      for i in "${files[@]}"; do
        if [[ "$i" == *.gz ]]; then
          gzip -cd -- "$i" 2>/dev/null || true
        else
          cat -- "$i" 2>/dev/null || true
        fi
      done
    } | env -u LD_LIBRARY_PATH -u LD_PRELOAD "$goa_bin" "${args[@]}" --log-file=- 2>&1 | tee "$out_log"
  else
    # 单个非压缩文件，直接 -f 提供
    env -u LD_LIBRARY_PATH -u LD_PRELOAD "$goa_bin" "${args[@]}" -f "${files[0]}" 2>&1 | tee "$out_log"
  fi
  local rc=${PIPESTATUS[0]:-0}
  set -e
  if [[ $rc -ne 0 ]]; then
    echo "[!] GoAccess 生成报告失败(退出码=$rc)，日志：$out_log"
    return $rc
  fi
  echo "[OK] 报告已生成：$out_html"
  local t1=$(etk_now); local dur=$((t1-t0))
  
  # 尝试从日志中提取一些统计信息
  local total_requests unique_visitors unique_files total_bandwidth
  total_requests=$(grep -E "Total Requests:" "$out_log" 2>/dev/null | awk '{print $3}' || echo "N/A")
  unique_visitors=$(grep -E "Unique Visitors:" "$out_log" 2>/dev/null | awk '{print $3}' || echo "N/A")
  unique_files=$(grep -E "Unique Files:" "$out_log" 2>/dev/null | awk '{print $3}' || echo "N/A")
  total_bandwidth=$(grep -E "Total Bandwidth:" "$out_log" 2>/dev/null | sed 's/.*Total Bandwidth: //' || echo "N/A")
  
  # 显示分析摘要
  ui_box_start "分析摘要"
  ui_kv "总请求数" "$total_requests"
  ui_kv "独立访客" "$unique_visitors"
  ui_kv "独立文件" "$unique_files"
  ui_kv "总带宽" "$total_bandwidth"
  
  # 检查是否有可疑活动
  local suspicious_ips suspicious_paths
  suspicious_ips=$(grep -c -E "(127\.0\.0\.1|localhost)" "$out_log" 2>/dev/null || echo 0)
  suspicious_paths=$(grep -c -E "(\.\./|/etc/|/proc/)" "$out_log" 2>/dev/null || echo 0)
  
  ui_box_sep
  echo "安全检查:"; ui_box_sep
  ui_kv "本地访问" "$suspicious_ips"
  ui_kv "可疑路径" "$suspicious_paths"
  
  ui_box_end
  
  ui_box_start "统计"
  printf "%s " "$C_BLUE$UI_V$C_RESET"; ui_badges "输入=${#files[@]}" "格式=$fmt" "耗时=$(etk_fmt_dur "$dur")" "输出=$(basename "$out_html")" "日志=$(basename "$out_log")"
  ui_box_end
}

## yara_scan 已移除（改用 LOKI）

## yara_scan 已移除（改用 LOKI）

frp_stop() {
  local mode=${1:-}
  local pidfile="${LOG_DIR}/frp/${mode}.pid"
  if [[ -f "$pidfile" ]]; then
    local p
    p=$(cat "$pidfile")
    if kill "$p" 2>/dev/null; then
      echo "${mode} 已停止"
      rm -f "$pidfile"
    else
      echo "[!] 终止 ${mode} 失败，尝试强制 kill -9"
      kill -9 "$p" 2>/dev/null || true
      rm -f "$pidfile"
    fi
  else
    echo "[!] 未发现 ${mode} PID 文件"
  fi
}

frp_status() {
  for m in frpc frps; do
    if [[ -f "${LOG_DIR}/frp/${m}.pid" ]]; then
      p=$(cat "${LOG_DIR}/frp/${m}.pid")
      if kill -0 "$p" 2>/dev/null; then
        echo "$m 运行中 (PID=$p)"
      else
        echo "$m 未运行 (残留 PID 文件)"
      fi
    else
      echo "$m 未运行"
    fi
  done
}
frp_gen_forward_proxy() {
  frp_default_confs
  local frpc_ini="${CONF_DIR}/frp/frpc.ini"
  if ! grep -q "\[http_proxy\]" "$frpc_ini" 2>/dev/null; then
    cat >>"$frpc_ini" <<'EOF'

# 正向代理示例：将本地 1080/http 代理暴露到服务端 (socks/http 可选)
[http_proxy]
local_ip = 127.0.0.1
local_port = 1080
remote_port = 61080
EOF
    echo "[FRP] 已追加正向代理示例到 frpc.ini"
  fi
}

frp_gen_reverse_proxy() {
  local frpc_ini="${CONF_DIR}/frp/frpc.ini"
  local frps_ini="${CONF_DIR}/frp/frps.ini"
  # 更新 frps 反代端口
  if ! grep -q "vhost_http_port" "$frps_ini" 2>/dev/null; then
    cat >>"$frps_ini" <<'EOF'
vhost_http_port = 8080
vhost_https_port = 8443
subdomain_host = example.com
EOF
    echo "[FRP] 已在 frps.ini 启用 vhost_http/https 端口与 subdomain_host"
  fi
  # 追加 frpc 示例
  if ! grep -q "\[web_http\]" "$frpc_ini" 2>/dev/null; then
    cat >>"$frpc_ini" <<'EOF'

# 反向代理示例：通过 frps 的 vhost_http_port 暴露本地 Web (HTTP)
[web_http]
type = http
local_ip = 127.0.0.1
local_port = 8081
custom_domains = web.example.com

# 反向代理示例：通过 frps 的 vhost_https_port 暴露本地 Web (HTTPS)
[web_https]
type = https
local_ip = 127.0.0.1
local_port = 8444
custom_domains = web.example.com
EOF
    echo "[FRP] 已在 frpc.ini 追加反向代理示例 (http/https)"
  else
    echo "[FRP] frpc.ini 中已存在反向代理示例"
  fi
}

frp_quick_setup_forward_proxy() {
  frp_default_confs
  local frpc_ini="${CONF_DIR}/frp/frpc.ini"
  echo "[快速配置] frpc 正向代理"
  printf "FRPS 地址 (server_addr) [默认 127.0.0.1]: "
  if [[ -e /dev/tty && -r /dev/tty ]]; then read -r server_addr < /dev/tty || true; else read -r server_addr || true; fi
  server_addr=${server_addr:-127.0.0.1}
  printf "FRPS 端口 (server_port) [默认 7000]: "
  if [[ -e /dev/tty && -r /dev/tty ]]; then read -r server_port < /dev/tty || true; else read -r server_port || true; fi
  server_port=${server_port:-7000}
  printf "Auth Token [默认 change_me_token]: "
  if [[ -e /dev/tty && -r /dev/tty ]]; then read -r token < /dev/tty || true; else read -r token || true; fi
  token=${token:-change_me_token}
  printf "本地代理端口 (local_port) [默认 1080]: "
  if [[ -e /dev/tty && -r /dev/tty ]]; then read -r lp < /dev/tty || true; else read -r lp || true; fi
  lp=${lp:-1080}
  printf "远端映射端口 (remote_port) [默认 61080]: "
  if [[ -e /dev/tty && -r /dev/tty ]]; then read -r rp < /dev/tty || true; else read -r rp || true; fi
  rp=${rp:-61080}

  awk -v s="$server_addr" -v p="$server_port" -v t="$token" '
    BEGIN{updated=0}
    /^\[common\]/{print; incommon=1; next}
    incommon==1 && /^server_addr[[:space:]]*=/{print "server_addr = " s; updated=1; next}
    incommon==1 && /^server_port[[:space:]]*=/{print "server_port = " p; next}
    incommon==1 && /^auth\.token[[:space:]]*=/{print "auth.token = " t; next}
    {print}
  ' "$frpc_ini" >"$frpc_ini.tmp" && mv "$frpc_ini.tmp" "$frpc_ini"

  if grep -q "^\[http_proxy\]$" "$frpc_ini"; then
    awk -v lp="$lp" -v rp="$rp" '
      BEGIN{insec=0}
      /^\[http_proxy\]$/{print; insec=1; next}
      insec==1 && /^local_port[[:space:]]*=/{print "local_port = " lp; next}
      insec==1 && /^remote_port[[:space:]]*=/{print "remote_port = " rp; insec=0; next}
      {print}
    ' "$frpc_ini" >"$frpc_ini.tmp" && mv "$frpc_ini.tmp" "$frpc_ini"
  else
    cat >>"$frpc_ini" <<EOF

[http_proxy]
type = tcp
local_ip = 127.0.0.1
local_port = $lp
remote_port = $rp
EOF
  fi
  echo "[OK] 已写入 frpc 正向代理配置。可运行: frp_start frpc"
}

frp_quick_setup_reverse_proxy_client() {
  frp_default_confs
  local frpc_ini="${CONF_DIR}/frp/frpc.ini"
  echo "[快速配置] frpc 反向代理 (HTTP/HTTPS)"
  printf "FRPS 地址 (server_addr) [默认 127.0.0.1]: "
  if [[ -e /dev/tty && -r /dev/tty ]]; then read -r server_addr < /dev/tty || true; else read -r server_addr || true; fi
  server_addr=${server_addr:-127.0.0.1}
  printf "FRPS 端口 (server_port) [默认 7000]: "
  if [[ -e /dev/tty && -r /dev/tty ]]; then read -r server_port < /dev/tty || true; else read -r server_port || true; fi
  server_port=${server_port:-7000}
  printf "Auth Token [默认 change_me_token]: "
  if [[ -e /dev/tty && -r /dev/tty ]]; then read -r token < /dev/tty || true; else read -r token || true; fi
  token=${token:-change_me_token}
  printf "本地 HTTP 服务端口 [默认 8081]: "
  if [[ -e /dev/tty && -r /dev/tty ]]; then read -r lhttp < /dev/tty || true; else read -r lhttp || true; fi
  lhttp=${lhttp:-8081}
  printf "本地 HTTPS 服务端口 [默认 8444]: "
  if [[ -e /dev/tty && -r /dev/tty ]]; then read -r lhttps < /dev/tty || true; else read -r lhttps || true; fi
  lhttps=${lhttps:-8444}
  printf "自定义域名 (custom_domains)，如 web.example.com [必填]: "
  if [[ -e /dev/tty && -r /dev/tty ]]; then read -r domain < /dev/tty || true; else read -r domain || true; fi
  if [[ -z "$domain" ]]; then
    echo "[!] 未提供域名，取消。"
    return 1
  fi

  awk -v s="$server_addr" -v p="$server_port" -v t="$token" '
    BEGIN{updated=0}
    /^\[common\]/{print; incommon=1; next}
    incommon==1 && /^server_addr[[:space:]]*=/{print "server_addr = " s; updated=1; next}
    incommon==1 && /^server_port[[:space:]]*=/{print "server_port = " p; next}
    incommon==1 && /^auth\.token[[:space:]]*=/{print "auth.token = " t; next}
    {print}
  ' "$frpc_ini" >"$frpc_ini.tmp" && mv "$frpc_ini.tmp" "$frpc_ini"

  # 写入 HTTP/HTTPS 两段
  # HTTP 段
  if grep -q "^\[web_http\]$" "$frpc_ini"; then
    awk -v lp="$lhttp" -v d="$domain" '
      BEGIN{insec=0}
      /^\[web_http\]$/{print; insec=1; next}
      insec==1 && /^local_port[[:space:]]*=/{print "local_port = " lp; next}
      insec==1 && /^custom_domains[[:space:]]*=/{print "custom_domains = " d; insec=0; next}
      {print}
    ' "$frpc_ini" >"$frpc_ini.tmp" && mv "$frpc_ini.tmp" "$frpc_ini"
  else
    cat >>"$frpc_ini" <<EOF

[web_http]
type = http
local_ip = 127.0.0.1
local_port = $lhttp
custom_domains = $domain
EOF
  fi
  # HTTPS 段
  if grep -q "^\[web_https\]$" "$frpc_ini"; then
    awk -v lp="$lhttps" -v d="$domain" '
      BEGIN{insec=0}
      /^\[web_https\]$/{print; insec=1; next}
      insec==1 && /^local_port[[:space:]]*=/{print "local_port = " lp; next}
      insec==1 && /^custom_domains[[:space:]]*=/{print "custom_domains = " d; insec=0; next}
      {print}
    ' "$frpc_ini" >"$frpc_ini.tmp" && mv "$frpc_ini.tmp" "$frpc_ini"
  else
    cat >>"$frpc_ini" <<EOF

[web_https]
type = https
local_ip = 127.0.0.1
local_port = $lhttps
custom_domains = $domain
EOF
  fi
  echo "[OK] 已写入 frpc 反向代理 (HTTP/HTTPS) 配置。可运行: frp_start frpc"
}

frp_quick_setup_reverse_proxy_server() {
  frp_default_confs
  local frps_ini="${CONF_DIR}/frp/frps.ini"
  echo "[快速配置] frps 反向代理 (HTTP/HTTPS)"
  printf "监听端口 bind_port [默认 7000]: "
  if [[ -e /dev/tty && -r /dev/tty ]]; then read -r bp < /dev/tty || true; else read -r bp || true; fi
  bp=${bp:-7000}
  printf "Auth Token [默认 change_me_token]: "
  if [[ -e /dev/tty && -r /dev/tty ]]; then read -r token < /dev/tty || true; else read -r token || true; fi
  token=${token:-change_me_token}
  printf "HTTP 反代端口 vhost_http_port [默认 8080]: "
  if [[ -e /dev/tty && -r /dev/tty ]]; then read -r vh < /dev/tty || true; else read -r vh || true; fi
  vh=${vh:-8080}
  printf "HTTPS 反代端口 vhost_https_port [默认 8443]: "
  if [[ -e /dev/tty && -r /dev/tty ]]; then read -r vhs < /dev/tty || true; else read -r vhs || true; fi
  vhs=${vhs:-8443}
  printf "根域名 subdomain_host (如 example.com) [默认 example.com]: "
  if [[ -e /dev/tty && -r /dev/tty ]]; then read -r sdh < /dev/tty || true; else read -r sdh || true; fi
  sdh=${sdh:-example.com}

  awk -v bp="$bp" -v t="$token" -v vh="$vh" -v vhs="$vhs" -v sdh="$sdh" '
    BEGIN{incommon=0}
    /^\[common\]/{print; incommon=1; next}
    incommon==1 && /^bind_port[[:space:]]*=/{print "bind_port = " bp; next}
    incommon==1 && /^auth\.token[[:space:]]*=/{print "auth.token = " t; next}
    incommon==1 && /^vhost_http_port[[:space:]]*=/{print "vhost_http_port = " vh; next}
    incommon==1 && /^vhost_https_port[[:space:]]*=/{print "vhost_https_port = " vhs; next}
    incommon==1 && /^subdomain_host[[:space:]]*=/{print "subdomain_host = " sdh; next}
    {print}
  ' "$frps_ini" >"$frps_ini.tmp" && mv "$frps_ini.tmp" "$frps_ini"
  echo "[OK] 已写入 frps 反向代理配置。可运行: frp_start frps"
}

collect_logs() {
  echo "[打包日志和结果]"
  local t0=$(etk_now)
  local out="${ROOT_DIR}/etk_logs_$(ts).tar.gz"
  tar -czf "$out" -C "$ROOT_DIR" logs || true
  echo "已生成: $out"
  local t1=$(etk_now); local dur=$((t1-t0))
  ui_box_start "统计"
  printf "%s " "$C_BLUE$UI_V$C_RESET"; ui_badges "耗时=$(etk_fmt_dur "$dur")" "输出=$(basename "$out")"
  ui_box_end
}


menu() {
  print_header
  echo "作者: FightnvrGP  |  项目地址: https://github.com/MchalTesla/emergency-toolkit"
  ui_theme_init; ui_box_start "主菜单"
  cat <<MENU
 1) LOKI 扫描
 2) ClamAV 扫描
 3) LMD 扫描(便携模式)
 4) rkhunter 检查
 5) Lynis 审计(快速)
 6) Web 日志报表(GoAccess)
 7) 系统信息采集
 8) 网络与进程排查
 9) 文件系统排查
 10) 账号与认证排查
 11) 计划任务排查
 12) 服务与自启动排查
 13) 快速取证(采集+打包)
 14) 生成汇总报告(基于现有日志)
 15) FRP 管理
 16) 打包日志
 17) 工具箱介绍
 q) 退出
MENU
  ui_box_end
  printf "请选择 [1-18 或 q]: "
}

menu_frp() {
  echo "[FRP 管理]"
  cat <<MENU
1) 启动 frpc
2) 启动 frps
3) 停止 frpc
4) 停止 frps
5) 查看状态
6) 生成正向代理示例配置
7) 生成反向代理示例配置
8) 快速配置 frpc 正向代理
9) 快速配置 frpc 反向代理(HTTP/HTTPS)
10) 快速配置 frps 反向代理
11) 返回 (或按 q)
MENU
  printf "请选择 [1-11 或 q]: "
}

toolbox_intro() {
  ui_theme_init; ui_box_start "工具箱介绍"
  cat <<INTRO
Emergency Toolkit (Linux x86_64)

作者: FightnvrGP
项目链接: https://github.com/MchalTesla/emergency-toolkit

本工具箱面向 Linux x86_64 服务器环境，依赖尽量降至零，优先使用本地 bin/ 与 busybox 提供的工具。

功能概览：
1) LOKI 扫描 - 使用 LOKI 工具扫描 IOC（Indicators of Compromise），检测恶意软件和威胁。
2) ClamAV 扫描 - 使用 ClamAV 病毒扫描引擎扫描恶意软件。
3) LMD 扫描(便携模式) - 使用 Linux Malware Detect 扫描恶意软件。
4) rkhunter 检查 - 使用 rkhunter 检查 Rootkit。
   └─ 详细说明：rkhunter (Rootkit Hunter) 是一款专业的 Rootkit 检测工具，能够检查系统是否被 Rootkit 感染。
      检测内容包括：系统文件完整性检查、隐藏进程检测、内核模块检查、网络接口检查等。
      日志输出：完整的 rkhunter 检查结果，包含所有检测项和发现的异常。
      使用场景：怀疑系统被 Rootkit 入侵时进行全面检查。
5) Lynis 审计(快速) - 使用 Lynis 进行系统安全审计。
   └─ 详细说明：Lynis 是一款全面的 Linux 系统安全审计工具，能够评估系统的安全状态。
      审计内容包括：系统配置检查、文件权限检查、网络安全检查、用户认证检查、内核安全检查等。
      检测项目：数百个安全检查点，涵盖系统各个方面。
      日志输出：详细的审计报告，包含警告、建议和安全评分。
      环境要求：需要完整的 GNU 工具链，不支持 BusyBox 环境。
      使用场景：系统安全评估、合规性检查、安全加固指导。
6) Web 日志报表(GoAccess) - 使用 GoAccess 生成 Web 日志报表。
7) 系统信息采集 - 收集系统基本信息（内核、CPU、内存、磁盘、网络等）。
8) 网络与进程排查 - 检查网络连接、进程和 SUID 文件。
9) 文件系统排查 - 扫描文件系统变化和高容量文件。
10) 账号与认证排查 - 检查用户账号、认证配置和失败记录。
11) 计划任务排查 - 检查计划任务和定时作业。
12) 服务与自启动排查 - 检查系统服务和自启动程序。
13) 快速取证(采集+打包) - 采集系统信息并打包日志。
14) 生成汇总报告(基于现有日志) - 生成基于现有日志的汇总报告。
15) FRP 管理 - 管理 FRP（Fast Reverse Proxy）服务。
16) 打包日志 - 打包所有日志文件。
17) 工具箱介绍 - 显示本介绍。

使用方法：
- 运行 ./run.sh 启动工具箱。
- 选择相应功能编号执行。
- 日志输出在 logs/ 目录。
- 按 q 退出。

详细使用指南：

功能4 (rkhunter检查) 使用指南：
• 适用场景：怀疑系统被Rootkit入侵、定期安全检查
• 执行时间：通常需要1-3分钟，取决于系统大小
• 日志位置：logs/rkhunter_YYYYMMDD_HHMMSS.log
• 结果解读：
  - "Warning:" 表示发现可疑项目，需要人工判断
  - "[ Found ]" 表示发现异常文件或进程
  - 检查结果为"OK"表示该项正常
• 注意事项：rkhunter可能会产生误报，建议结合其他工具结果判断

功能5 (Lynis审计) 使用指南：
• 适用场景：系统安全评估、安全加固指导、合规性检查
• 执行时间：通常需要2-5分钟，取决于系统配置复杂度
• 日志位置：logs/lynis_YYYYMMDD_HHMMSS.log
• 结果解读：
  - "[ WARNING ]" 表示需要关注的潜在安全问题
  - "[ SUGGESTION ]" 表示改进建议
  - "[ INFO ]" 表示信息性输出
  - 审计报告末尾会给出安全评分和建议
• 环境要求：不支持BusyBox环境，需要完整的GNU工具链
• 注意事项：Lynis是审计工具，不是实时监控；建议定期执行

INTRO
  ui_box_end
}

main() {
  while true; do
    menu
  if [[ -e /dev/tty && -r /dev/tty ]]; then read -r choice < /dev/tty || true; else read -r choice || true; fi
    case "${choice:-}" in
      1) loki_scan; pause ;;
      2) clamav_scan; pause ;;
      3) lmd_scan; pause ;;
      4) rkhunter_run; pause ;;
      5) lynis_run; pause ;;
      6) goaccess_report; pause ;;
  7) lf="${LOG_DIR}/sysinfo_$(ts).log"; ETK_CURRENT_LOG="$lf" sys_info | tee "$lf"; pause ;;
  8) lf="${LOG_DIR}/netproc_$(ts).log"; ETK_CURRENT_LOG="$lf" net_process_audit | tee "$lf"; pause ;;
  9) lf="${LOG_DIR}/files_$(ts).log"; ETK_CURRENT_LOG="$lf" files_audit | tee "$lf"; pause ;;
  10) lf="${LOG_DIR}/auth_$(ts).log"; ETK_CURRENT_LOG="$lf" auth_audit | tee "$lf"; pause ;;
  11) lf="${LOG_DIR}/tasks_$(ts).log"; ETK_CURRENT_LOG="$lf" tasks_audit | tee "$lf"; pause ;;
  12) lf="${LOG_DIR}/services_$(ts).log"; ETK_CURRENT_LOG="$lf" services_audit | tee "$lf"; pause ;;
      13) quick_triage; pause ;;
  14) generate_summary_report; pause ;;
      15)
        while true; do
          menu_frp
          if [[ -e /dev/tty && -r /dev/tty ]]; then read -r c < /dev/tty || true; else read -r c || true; fi
          case "${c:-}" in
            1) frp_start frpc; pause ;;
            2) frp_start frps; pause ;;
            3) frp_stop frpc; pause ;;
            4) frp_stop frps; pause ;;
            5) frp_status; pause ;;
            6) frp_gen_forward_proxy; pause ;;
            7) frp_gen_reverse_proxy; pause ;;
            8) frp_quick_setup_forward_proxy; pause ;;
            9) frp_quick_setup_reverse_proxy_client; pause ;;
            10) frp_quick_setup_reverse_proxy_server; pause ;;
            11|q|Q) break ;;
            *) echo "无效选择" ;;
          esac
        done
        ;;
      16) collect_logs; pause ;;
      17) toolbox_intro; pause ;;
      q|Q) echo "再见"; exit 0 ;;
    esac
  done
}

main "$@"


