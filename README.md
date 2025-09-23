# Emergency Toolkit

[![License](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Platform](https://img.shields.io/badge/Platform-Linux%20x86_64-green.svg)](https://github.com/MchalTesla/emergency-toolkit)

> **Emergency Toolkit** 是一个专为 Linux x86_64 服务器环境设计的轻量级安全工具箱，旨在提供全面的系统审计、恶意软件检测和取证功能。工具箱采用零依赖设计，优先使用本地二进制文件和 BusyBox 工具，确保在各种环境中都能稳定运行。

**作者**: FightnvrGP  
**项目主页**: [https://github.com/MchalTesla/emergency-toolkit](https://github.com/MchalTesla/emergency-toolkit)

---

## 目录

- [中文版本](#中文版本)
  - [项目简介](#项目简介)
  - [功能特性](#功能特性)
  - [安装指南](#安装指南)
  - [使用方法](#使用方法)
  - [详细功能说明](#详细功能说明)
  - [配置选项](#配置选项)
  - [故障排除](#故障排除)
  - [目录结构](#目录结构)
  - [注意事项](#注意事项)
- [English Version](#english-version)
  - [Project Introduction](#project-introduction)
  - [Features](#features)
  - [Installation Guide](#installation-guide)
  - [Usage](#usage)
  - [Detailed Feature Description](#detailed-feature-description)
  - [Configuration Options](#configuration-options)
  - [Troubleshooting](#troubleshooting)
  - [Directory Structure](#directory-structure)
  - [Notes](#notes)
- [许可证](#许可证)
- [贡献](#贡献)

---

## 中文版本

### 项目简介

Emergency Toolkit 是一个面向 Linux x86_64 服务器环境的应急响应工具箱，专为安全审计、恶意软件检测和数字取证而设计。该工具箱采用模块化设计，集成了多种开源安全工具，并通过本地化部署和零依赖策略，确保在受限或隔离环境中仍能高效运行。

**核心理念**：
- **零依赖**：优先使用静态编译的二进制文件和 BusyBox，避免系统库依赖
- **便携性**：整个工具箱可直接复制到目标主机，无需安装
- **安全性**：所有操作默认采用“干跑”模式，生成脚本供人工审核
- **全面性**：覆盖系统审计、威胁检测、日志分析和取证打包

**适用场景**：
- 服务器安全审计
- 恶意软件应急响应
- 入侵取证调查
- CTF 比赛和渗透测试

### 功能特性

- ✅ **系统信息采集**：内核、CPU、内存、磁盘、网络、路由、DNS 等全面信息收集
- ✅ **网络与进程排查**：监听端口、连接状态、进程树、SUID 文件分析
- ✅ **文件系统审计**：时间窗口内文件变化、高容量文件检测
- ✅ **账号与认证审计**：用户账号、sudoers、SSH 配置、失败认证记录
- ✅ **计划任务检查**：crontab 和系统定时任务审计
- ✅ **服务与自启动分析**：systemd 服务、rc.local、rc*.d 自启动程序
- ✅ **恶意软件扫描**：
  - ClamAV 病毒扫描（本地病毒库）
  - LOKI IOC 扫描
  - Linux Malware Detect (LMD)
  - rkhunter Rootkit 检查
  - Lynis 系统安全审计
- ✅ **Shell 迹象检测**：反弹/正向/反向 Shell 和 WebShell 混淆检测
- ✅ **YARA 规则扫描**：支持自定义 YARA 规则，时间窗口和文件大小过滤
- ✅ **Web 日志分析**：Nginx/Apache/PHP-FPM 日志异常行为检测
- ✅ **FRP 内网穿透**：frpc/frps 管理，支持正向和反向代理配置
- ✅ **取证与报告**：日志打包、汇总报告生成、处置脚本创建（干跑模式）
- ✅ **UI 定制**：支持 UTF-8/ASCII 框线切换，颜色和 Emoji 控制

### 安装指南

#### 系统要求
- **平台**：Linux x86_64
- **权限**：root 或 sudo 权限（推荐）
- **依赖**：无外部依赖，所有工具内置

#### 安装步骤

1. **下载工具箱**：
   ```bash
   git clone https://github.com/MchalTesla/emergency-toolkit.git
   cd emergency-toolkit
   ```

2. **部署到目标主机**：
   ```bash
   # 从本地复制到远程主机
   scp -r emergency-toolkit user@target-host:/opt/
   ssh user@target-host
   cd /opt/emergency-toolkit

   # 设置执行权限
   chmod +x run.sh etk.sh clamav/run_scan.sh
   ```

3. **初始化运行**：
   ```bash
   ./run.sh
   ```
   该脚本将：
   - 安装 BusyBox 软链接到 `bin/`
   - 设置 PATH 优先使用本地工具
   - 验证平台兼容性
   - 启动主菜单界面

#### 可选：增强配置

- **ClamAV 病毒库更新**：下载最新病毒库到 `clamav/db/`
- **YARA 规则扩展**：添加自定义规则到 `rules/yara/`
- **FRP 配置**：编辑 `conf/frp/` 下的配置文件

### 使用方法

#### 基本使用

1. 运行 `./run.sh` 启动工具箱
2. 在主菜单中选择功能编号（1-17）
3. 按提示输入参数或确认执行
4. 查看 `logs/` 目录下的输出日志

#### 命令行参数

工具箱支持环境变量控制行为：

```bash
# 强制 ASCII 框线（兼容极简终端）
ETK_FORCE_ASCII=1 ./run.sh

# 强制 UTF-8 框线
ETK_FORCE_UTF8=1 ./run.sh

# 禁用颜色输出
ETK_NO_COLOR=1 ./run.sh

# 禁用 Emoji
ETK_NO_EMOJI=1 ./run.sh
```

#### 批量扫描示例

```bash
# 扫描整个系统（排除工具箱目录）
./etk.sh <<EOF
2
/
EOF

# 生成汇总报告
./etk.sh <<EOF
14
EOF
```

### 详细功能说明

#### 1. LOKI 扫描
- **描述**：使用 LOKI 工具扫描已知 IOC（Indicators of Compromise）
- **使用**：选择扫描路径，支持时间窗口过滤
- **输出**：`logs/loki_*.log`，包含 ALERT/SUSPICIOUS/MALICIOUS 命中

#### 2. ClamAV 扫描
- **描述**：基于本地病毒库的病毒扫描引擎
- **配置**：病毒库位于 `clamav/db/`，支持 main.cvd/daily.cvd/bytecode.cvd
- **使用**：`./clamav/run_scan.sh [选项] [路径]`
- **输出**：`logs/clamscan_*.log`

#### 3. LMD 扫描
- **描述**：Linux Malware Detect，便携模式
- **使用**：扫描文件系统，支持签名和启发式检测
- **输出**：`logs/lmd_*.log`

#### 4. rkhunter 检查
- **描述**：Rootkit 检测工具
- **使用**：自动扫描系统文件和进程
- **输出**：`logs/rkhunter_*.log`

#### 5. Lynis 审计
- **描述**：系统安全配置审计
- **使用**：快速模式扫描常见安全问题
- **输出**：`logs/lynis_*.log`

#### 6. Web 日志报表 (GoAccess)
- **描述**：实时 Web 日志分析和可视化
- **使用**：指定日志文件路径，生成 HTML 报表
- **输出**：`logs/goaccess_*.html`

#### 7. 系统信息采集
- **收集内容**：内核版本、CPU 信息、内存使用、磁盘分区、网络接口、路由表、DNS 配置
- **输出**：`logs/sysinfo_*.log`

#### 8. 网络与进程排查
- **检查内容**：监听端口、活跃连接、进程树、SUID/SGID 文件
- **输出**：`logs/netproc_*.log`

#### 9. 文件系统排查
- **检查内容**：24 小时内修改的文件、大文件（>100MB）、隐藏文件
- **输出**：`logs/files_*.log`

#### 10. 账号与认证排查
- **检查内容**：/etc/passwd、/etc/shadow、sudoers、SSH 配置、认证失败日志
- **输出**：`logs/auth_*.log`

#### 11. 计划任务排查
- **检查内容**：用户 crontab、系统 cron 目录、at 任务
- **输出**：`logs/tasks_*.log`

#### 12. 服务与自启动排查
- **检查内容**：systemd 服务状态、rc.local、init.d 脚本
- **输出**：`logs/services_*.log`

#### 13. 快速取证
- **功能**：采集所有系统信息并打包日志
- **输出**：`etk_forensic_*.tar.gz`

#### 14. 生成汇总报告
- **功能**：基于现有日志生成综合报告
- **输出**：`logs/summary_*.log`

#### 15. FRP 管理
- **功能**：frpc/frps 启动/停止/状态查看、配置生成
- **配置**：`conf/frp/frpc.ini`、`conf/frp/frps.ini`

#### 16. 打包日志
- **功能**：将所有日志打包成压缩文件
- **输出**：`etk_logs_*.tar.gz`

#### 17. 工具箱介绍
- **功能**：显示工具箱详细介绍和使用帮助

### 配置选项

#### 环境变量

| 变量 | 描述 | 默认值 |
|------|------|--------|
| `ETK_FORCE_ASCII` | 强制使用 ASCII 框线 | 0 |
| `ETK_FORCE_UTF8` | 强制使用 UTF-8 框线 | 0 |
| `ETK_NO_COLOR` | 禁用颜色输出 | 0 |
| `ETK_NO_EMOJI` | 禁用 Emoji | 0 |
| `ETK_FORCE_COLOR` | 强制启用颜色 | 0 |
| `ETK_FORCE_EMOJI` | 强制启用 Emoji | 0 |

#### 配置文件

- **FRP 配置**：`conf/frp/`
- **YARA 规则**：`rules/yara/`
- **自定义 IOC**：`rules/custom-iocs/`

### 故障排除

#### ClamAV 相关问题

**问题**：`GLIBC_2.35' not found`
**解决**：
```bash
# 在兼容主机上收集 glibc
./scripts/collect_glibc_from_system.sh
```

**问题**：病毒库缺失
**解决**：下载 main.cvd 和 daily.cvd 到 `clamav/db/`

#### 权限问题

- 确保以 root 权限运行，或使用 sudo
- 检查文件执行权限：`chmod +x *.sh`

#### 终端兼容性

- 在不支持 UTF-8 的终端中使用 `ETK_FORCE_ASCII=1`
- 禁用颜色：`ETK_NO_COLOR=1`

### 目录结构

```
emergency-toolkit/
├── bin/                    # BusyBox 和内置二进制文件
├── lib/                    # 运行时库文件
│   ├── goaccess/          # GoAccess 依赖库
│   └── clamav/            # ClamAV 依赖库
├── vendor/                # 第三方工具
│   ├── clamav/            # ClamAV 工具
│   ├── lynis/             # Lynis 工具
│   ├── rkhunter/          # rkhunter 工具
│   └── lmd/               # Linux Malware Detect
├── rules/                 # 规则和签名
│   ├── yara/              # YARA 规则
│   └── custom-iocs/       # 自定义 IOC
├── tools/                 # 构建和辅助脚本
├── conf/                  # 配置文件
│   └── frp/               # FRP 配置
├── logs/                  # 日志输出目录
├── scripts/               # 辅助脚本
├── run.sh                 # 启动脚本
├── etk.sh                 # 主程序
└── README.md              # 本文档
```

### 注意事项

- **安全第一**：所有处置操作默认生成脚本，建议人工审核后再执行
- **性能考虑**：大规模扫描可能耗时较长，建议分批进行
- **备份重要**：在生产环境中使用前务必备份关键数据
- **法律合规**：仅在授权范围内使用，避免侵犯隐私
- **更新维护**：定期更新病毒库和规则以保持检测能力

---

## English Version

### Project Introduction

Emergency Toolkit is a lightweight security toolkit designed specifically for Linux x86_64 server environments, providing comprehensive system auditing, malware detection, and digital forensics capabilities. The toolkit adopts a modular design, integrating multiple open-source security tools, and ensures efficient operation in restricted or isolated environments through localized deployment and zero-dependency strategy.

**Core Philosophy**:
- **Zero Dependencies**: Prioritize statically compiled binaries and BusyBox to avoid system library dependencies
- **Portability**: The entire toolkit can be directly copied to target hosts without installation
- **Security**: All operations default to "dry-run" mode, generating scripts for manual review
- **Comprehensiveness**: Covers system auditing, threat detection, log analysis, and forensic packaging

**Use Cases**:
- Server security auditing
- Malware incident response
- Intrusion forensics investigation
- CTF competitions and penetration testing

### Features

- ✅ **System Information Collection**: Comprehensive collection of kernel, CPU, memory, disk, network, routing, DNS information
- ✅ **Network & Process Investigation**: Listening ports, connection status, process tree, SUID file analysis
- ✅ **Filesystem Auditing**: File changes within time windows, large file detection
- ✅ **Account & Authentication Auditing**: User accounts, sudoers, SSH configuration, failed authentication logs
- ✅ **Scheduled Task Checking**: crontab and system cron job auditing
- ✅ **Service & Autostart Analysis**: systemd services, rc.local, rc*.d autostart programs
- ✅ **Malware Scanning**:
  - ClamAV virus scanning (local virus database)
  - LOKI IOC scanning
  - Linux Malware Detect (LMD)
  - rkhunter Rootkit checking
  - Lynis system security auditing
- ✅ **Shell Indicators Detection**: Bounce/forward/reverse shell and common WebShell obfuscation detection
- ✅ **YARA Rule Scanning**: Support for custom YARA rules, time window and file size filtering
- ✅ **Web Log Analysis**: Nginx/Apache/PHP-FPM log anomaly detection
- ✅ **FRP Tunneling**: frpc/frps management, support for forward and reverse proxy configuration
- ✅ **Forensics & Reporting**: Log packaging, summary report generation, disposal script creation (dry-run mode)
- ✅ **UI Customization**: Support for UTF-8/ASCII border switching, color and emoji control

### Installation Guide

#### System Requirements
- **Platform**: Linux x86_64
- **Permissions**: root or sudo privileges (recommended)
- **Dependencies**: No external dependencies, all tools are built-in

#### Installation Steps

1. **Download the Toolkit**:
   ```bash
   git clone https://github.com/MchalTesla/emergency-toolkit.git
   cd emergency-toolkit
   ```

2. **Deploy to Target Host**:
   ```bash
   # Copy from local to remote host
   scp -r emergency-toolkit user@target-host:/opt/
   ssh user@target-host
   cd /opt/emergency-toolkit

   # Set execution permissions
   chmod +x run.sh etk.sh clamav/run_scan.sh
   ```

3. **Initialize and Run**:
   ```bash
   ./run.sh
   ```
   This script will:
   - Install BusyBox symlinks to `bin/`
   - Set PATH to prioritize local tools
   - Verify platform compatibility
   - Launch the main menu interface

#### Optional: Enhanced Configuration

- **ClamAV Database Update**: Download latest virus databases to `clamav/db/`
- **YARA Rules Extension**: Add custom rules to `rules/yara/`
- **FRP Configuration**: Edit configuration files under `conf/frp/`

### Usage

#### Basic Usage

1. Run `./run.sh` to start the toolkit
2. Select a function number (1-17) from the main menu
3. Enter parameters or confirm execution as prompted
4. Check output logs in the `logs/` directory

#### Command Line Parameters

The toolkit supports environment variables to control behavior:

```bash
# Force ASCII borders (compatible with minimal terminals)
ETK_FORCE_ASCII=1 ./run.sh

# Force UTF-8 borders
ETK_FORCE_UTF8=1 ./run.sh

# Disable color output
ETK_NO_COLOR=1 ./run.sh

# Disable emoji
ETK_NO_EMOJI=1 ./run.sh
```

#### Batch Scanning Example

```bash
# Scan entire system (excluding toolkit directory)
./etk.sh <<EOF
2
/
EOF

# Generate summary report
./etk.sh <<EOF
14
EOF
```

### Detailed Feature Description

#### 1. LOKI Scanning
- **Description**: Scan for known IOCs using LOKI tool
- **Usage**: Select scan path, supports time window filtering
- **Output**: `logs/loki_*.log`, containing ALERT/SUSPICIOUS/MALICIOUS hits

#### 2. ClamAV Scanning
- **Description**: Virus scanning engine based on local virus database
- **Configuration**: Virus databases located in `clamav/db/`, supports main.cvd/daily.cvd/bytecode.cvd
- **Usage**: `./clamav/run_scan.sh [options] [path]`
- **Output**: `logs/clamscan_*.log`

#### 3. LMD Scanning
- **Description**: Linux Malware Detect, portable mode
- **Usage**: Scan filesystem, supports signature and heuristic detection
- **Output**: `logs/lmd_*.log`

#### 4. rkhunter Checking
- **Description**: Rootkit detection tool
- **Usage**: Automatically scans system files and processes
- **Output**: `logs/rkhunter_*.log`

#### 5. Lynis Auditing
- **Description**: System security configuration auditing
- **Usage**: Fast mode scanning for common security issues
- **Output**: `logs/lynis_*.log`

#### 6. Web Log Reports (GoAccess)
- **Description**: Real-time web log analysis and visualization
- **Usage**: Specify log file path, generate HTML reports
- **Output**: `logs/goaccess_*.html`

#### 7. System Information Collection
- **Collected Content**: Kernel version, CPU info, memory usage, disk partitions, network interfaces, routing table, DNS configuration
- **Output**: `logs/sysinfo_*.log`

#### 8. Network & Process Investigation
- **Checked Content**: Listening ports, active connections, process tree, SUID/SGID files
- **Output**: `logs/netproc_*.log`

#### 9. Filesystem Investigation
- **Checked Content**: Files modified in last 24 hours, large files (>100MB), hidden files
- **Output**: `logs/files_*.log`

#### 10. Account & Authentication Investigation
- **Checked Content**: /etc/passwd, /etc/shadow, sudoers, SSH configuration, authentication failure logs
- **Output**: `logs/auth_*.log`

#### 11. Scheduled Tasks Investigation
- **Checked Content**: User crontab, system cron directories, at jobs
- **Output**: `logs/tasks_*.log`

#### 12. Services & Autostart Investigation
- **Checked Content**: systemd service status, rc.local, init.d scripts
- **Output**: `logs/services_*.log`

#### 13. Quick Forensics
- **Function**: Collect all system information and package logs
- **Output**: `etk_forensic_*.tar.gz`

#### 14. Generate Summary Report
- **Function**: Generate comprehensive report based on existing logs
- **Output**: `logs/summary_*.log`

#### 15. FRP Management
- **Function**: frpc/frps start/stop/status viewing, configuration generation
- **Configuration**: `conf/frp/frpc.ini`, `conf/frp/frps.ini`

#### 16. Package Logs
- **Function**: Package all logs into a compressed file
- **Output**: `etk_logs_*.tar.gz`

#### 17. Toolkit Introduction
- **Function**: Display detailed toolkit introduction and usage help

### Configuration Options

#### Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `ETK_FORCE_ASCII` | Force ASCII borders | 0 |
| `ETK_FORCE_UTF8` | Force UTF-8 borders | 0 |
| `ETK_NO_COLOR` | Disable color output | 0 |
| `ETK_NO_EMOJI` | Disable emoji | 0 |
| `ETK_FORCE_COLOR` | Force color enable | 0 |
| `ETK_FORCE_EMOJI` | Force emoji enable | 0 |

#### Configuration Files

- **FRP Configuration**: `conf/frp/`
- **YARA Rules**: `rules/yara/`
- **Custom IOCs**: `rules/custom-iocs/`

### Troubleshooting

#### ClamAV Related Issues

**Issue**: `GLIBC_2.35' not found`
**Solution**:
```bash
# Collect glibc on compatible host
./scripts/collect_glibc_from_system.sh
```

**Issue**: Missing virus database
**Solution**: Download main.cvd and daily.cvd to `clamav/db/`

#### Permission Issues

- Ensure running with root privileges or using sudo
- Check file execution permissions: `chmod +x *.sh`

#### Terminal Compatibility

- Use `ETK_FORCE_ASCII=1` in terminals that don't support UTF-8
- Disable colors: `ETK_NO_COLOR=1`

### Directory Structure

```
emergency-toolkit/
├── bin/                    # BusyBox and built-in binaries
├── lib/                    # Runtime libraries
│   ├── goaccess/          # GoAccess dependencies
│   └── clamav/            # ClamAV dependencies
├── vendor/                # Third-party tools
│   ├── clamav/            # ClamAV tool
│   ├── lynis/             # Lynis tool
│   ├── rkhunter/          # rkhunter tool
│   └── lmd/               # Linux Malware Detect
├── rules/                 # Rules and signatures
│   ├── yara/              # YARA rules
│   └── custom-iocs/       # Custom IOCs
├── tools/                 # Build and auxiliary scripts
├── conf/                  # Configuration files
│   └── frp/               # FRP configuration
├── logs/                  # Log output directory
├── scripts/               # Auxiliary scripts
├── run.sh                 # Startup script
├── etk.sh                 # Main program
└── README.md              # This document
```

### Notes

- **Security First**: All disposal operations generate scripts by default, manual review before execution is recommended
- **Performance Considerations**: Large-scale scanning may take time, batch processing is suggested
- **Backup Important**: Always backup critical data before use in production environments
- **Legal Compliance**: Use only within authorized scope, avoid privacy violations
- **Maintenance**: Regularly update virus databases and rules to maintain detection capabilities

---

## 许可证

本项目采用 MIT 许可证 - 查看 [LICENSE](LICENSE) 文件了解详情。

## 贡献

欢迎提交 Issue 和 Pull Request！

1. Fork 本仓库
2. 创建特性分支 (`git checkout -b feature/AmazingFeature`)
3. 提交更改 (`git commit -m 'Add some AmazingFeature'`)
4. 推送到分支 (`git push origin feature/AmazingFeature`)
5. 创建 Pull Request

---

**作者**: FightnvrGP  
**项目主页**: [https://github.com/MchalTesla/emergency-toolkit](https://github.com/MchalTesla/emergency-toolkit)  
**版本**: 1.0.0  
**最后更新**: 2025年9月23日

## 功能选项详细介绍

### 系统信息采集
- 描述：收集系统的基本信息，包括内核版本、CPU、内存、磁盘使用情况、网络配置、路由表和 DNS 设置。
- 使用场景：快速了解目标系统的硬件和网络环境。

### 网络与进程排查
- 描述：检查系统中监听的端口、网络连接、进程树以及 SUID 文件。
- 使用场景：发现异常的网络活动或进程行为。

### 文件系统排查
- 描述：扫描文件系统中最近 24 小时内的变化文件，以及占用大量磁盘空间的文件。
- 使用场景：定位潜在的恶意文件或异常增长的日志文件。

### 账号与认证排查
- 描述：检查系统中的用户账号、sudoers 配置、SSH 配置以及失败的认证记录。
- 使用场景：发现异常用户或未授权的访问尝试。

### 计划任务排查
- 描述：检查用户和系统的计划任务，包括 crontab 和 /etc/cron.* 目录。
- 使用场景：发现潜在的恶意计划任务。

### 服务与自启动排查
- 描述：检查 systemd 中运行的服务、自启动脚本（如 rc.local 和 rc*.d）。
- 使用场景：发现异常的服务或自启动程序。

### ClamAV 扫描
- 描述：使用 ClamAV 扫描系统中的恶意软件，支持本地病毒库。
- 使用场景：快速检测已知的恶意软件样本。

### Shell 迹象扫描
- 描述：扫描系统中可能存在的反弹 Shell、正向 Shell、反向 Shell 和常见 WebShell。
- 使用场景：发现潜在的后门程序或 WebShell。

### Lynis 快速审计
- 描述：使用 Lynis 工具对系统进行安全审计，生成审计报告。
- 使用场景：评估系统的安全性并发现潜在的配置问题。

### FRP 管理
- 描述：管理 frpc 和 frps 的启动、停止和状态查看，支持生成示例配置。
- 使用场景：快速配置和管理内网穿透服务。

### 日志打包与快速取证
- 描述：将采集的结果和常见日志打包，便于后续分析。
- 使用场景：快速收集证据以供取证分析。

### YARA 扫描
- 描述：使用 YARA 规则扫描文件系统，支持时间窗口和文件大小过滤。
- 使用场景：发现未知的恶意软件样本或 IOC。

### Web 日志猎杀
- 描述：分析 Nginx、Apache 和 PHP-FPM 的日志，发现异常行为。
- 使用场景：定位潜在的 Web 攻击或异常访问。

### 处置脚本生成
- 描述：基于扫描结果生成隔离文件、终止进程的脚本，默认以“干跑”模式运行。
- 使用场景：快速生成处置方案，降低误操作风险。
