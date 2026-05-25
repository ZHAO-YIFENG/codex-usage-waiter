<div align="center">

# ⏳ Codex Usage Waiter

一个检查 Codex 用量并等待额度刷新的 Codex 插件。

[English](README.md) | [中文](README.zh-CN.md)

![License](https://img.shields.io/badge/license-MIT-blue)
![Platform](https://img.shields.io/badge/platform-Windows%20%7C%20WSL-lightgrey)
![Codex](https://img.shields.io/badge/Codex-Plugin-green)

</div>

---

## 📑 目录

- [功能](#-功能)
- [安装](#-安装)
- [使用方法](#-使用方法)
- [脚本](#-脚本)
- [参数](#-参数)
- [工作原理](#-工作原理)
- [环境要求](#-环境要求)
- [许可证](#-许可证)

---

## ✨ 功能

- 通过本地 app-server API 读取当前 Codex 用量
- 显示 5 小时/每周限制的使用百分比和重置时间
- 在终端中等待直到额度刷新
- 支持 Windows Codex Desktop 和 WSL Codex CLI
- 试运行模式，仅查看用量不等待

---

## 📦 安装

### 通过插件市场

```bash
codex plugin marketplace add ZHAO-YIFENG/codex-usage-waiter
```

然后在 Codex 的插件目录中安装。

### 手动安装

1. 克隆仓库：
   ```bash
   git clone https://github.com/ZHAO-YIFENG/codex-usage-waiter.git
   ```

2. 复制到 Codex 插件目录：
   ```powershell
   Copy-Item -Recurse codex-usage-waiter $env:USERPROFILE\.codex\plugins\codex-usage-waiter
   ```

3. 重启 Codex。

---

## 🚀 使用方法

**查看用量（试运行）：**

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\wait_for_next_codex_refresh.ps1 -DryRun
```

**等待额度刷新：**

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\wait_for_next_codex_refresh.ps1 -MaxWaitSeconds -1
```

**获取原始用量输出：**

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\get_codex_usage.ps1
```

---

## 📜 脚本

| 脚本 | 说明 |
|------|------|
| `get_codex_usage.ps1` | 通过 app-server API 读取当前用量 |
| `wait_for_next_codex_refresh.ps1` | 解析用量、计算下次刷新时间、可选等待 |
| `wait_until_credit_refresh.ps1` | 简单阻塞等待指定时长 |

---

## ⚙️ 参数

### `wait_for_next_codex_refresh.ps1`

| 参数 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| `-DryRun` | Switch | False | 仅输出用量和刷新时间，不等待 |
| `-StartupWaitSeconds` | Int | 60 | 等待 Codex 启动的秒数 |
| `-StatusWaitSeconds` | Int | 20 | 等待 /status 输出的秒数 |
| `-ExtraSeconds` | Int | 5 | 刷新后额外缓冲秒数 |
| `-MaxWaitSeconds` | Int | 90 | 最大等待秒数，-1 表示无限制 |
| `-UsageLine` | String[] | @() | 预提供的用量行 |

### `get_codex_usage.ps1`

| 参数 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| `-StartupWaitSeconds` | Int | 60 | 等待 Codex 启动的秒数 |
| `-StatusWaitSeconds` | Int | 20 | 等待 /status 输出的秒数 |

---

## 🔧 工作原理

1. 先尝试 Windows Codex Desktop，再尝试 WSL Codex CLI
2. 如果 app-server 失败，回退到抓取 WSL TUI 的 `/status` 输出
3. 提取 5 小时和每周限制行及其重置时间
4. 在终端阻塞直到计算出的刷新时间

---

## 📋 环境要求

- Windows + PowerShell 5.1+ 或 PowerShell Core
- WSL + Python 3（用于回退抓取）
- 已安装 Codex Desktop 或 Codex CLI

---

## 📄 许可证

MIT 许可证 - 详见 [LICENSE](LICENSE)。

---

## 👤 作者

**赵一峰 (ZHAO YIFENG)** · [GitHub](https://github.com/ZHAO-YIFENG)
