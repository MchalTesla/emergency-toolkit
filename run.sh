#!/usr/bin/env bash
set -euo pipefail

# 运行时脚本：
# 1) 将 busybox 软链接安装到 bin/
# 2) 将 bin/ 置于 PATH 前，优先使用本地 busybox 和二进制
# 3) 做平台与架构检查（要求 Linux x86_64）
# 4) 跳转到统一入口脚本 etk.sh

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
BIN_DIR="${ROOT_DIR}/bin"

mkdir -p "${BIN_DIR}"

if [[ ! -x "${BIN_DIR}/busybox" ]]; then
  echo "[!] 未找到 ${BIN_DIR}/busybox，可从 busybox 官方下载静态版并放入 bin/。"
  exit 1
fi

# 安装 busybox 链接
"${BIN_DIR}/busybox" --install -s "${BIN_DIR}/" || true

# 置顶 PATH
export PATH="${BIN_DIR}:${PATH}"

# 架构与平台检查
uname_s=$(uname -s || echo unknown)
uname_m=$(uname -m || echo unknown)
if [[ "${uname_s}" != "Linux" || "${uname_m}" != "x86_64" ]]; then
  echo "[!] 本工具箱的二进制面向 Linux x86_64。当前环境: ${uname_s} ${uname_m}"
  echo "    您的当前系统是 macOS arm64，无法直接运行 Linux 可执行文件。"
  echo "    请将整个 EmergencyToolkit 目录拷贝到 Linux x86_64 机器上运行："
  echo "    例如：scp -r EmergencyToolkit user@linux-host:/opt/ && ssh user@linux-host 'cd /opt/EmergencyToolkit && ./run.sh'"
  exit 2
fi

# 进入统一入口
exec "${ROOT_DIR}/etk.sh" "$@"
