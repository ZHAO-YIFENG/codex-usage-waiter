# Codex Usage Waiter

A Codex plugin that checks your Codex usage and waits until the next credit refresh.

一个检查 Codex 用量并等待额度刷新的 Codex 插件。

---

## Features / 功能

- Read current Codex usage via the local app-server API
- Display usage percentage and reset time for 5h/Weekly limits
- Wait in terminal until the next credit refresh
- Support both Windows Codex Desktop and WSL Codex CLI
- Dry-run mode to check usage without waiting

---

- 通过本地 app-server API 读取当前 Codex 用量
- 显示 5 小时/每周限制的使用百分比和重置时间
- 在终端中等待直到额度刷新
- 支持 Windows Codex Desktop 和 WSL Codex CLI
- 试运行模式，仅查看用量不等待

## Installation / 安装

### Via Marketplace / 通过插件市场

```bash
codex plugin marketplace add ZHAO-YIFENG/codex-usage-waiter
```

Then install from the plugin directory in Codex.

然后在 Codex 的插件目录中安装。

### Manual Installation / 手动安装

1. Clone this repository / 克隆仓库：
   ```bash
   git clone https://github.com/ZHAO-YIFENG/codex-usage-waiter.git
   ```

2. Copy to your Codex plugins directory / 复制到 Codex 插件目录：
   ```powershell
   # Windows
   Copy-Item -Recurse codex-usage-waiter $env:USERPROFILE\.codex\plugins\codex-usage-waiter
   ```

3. Restart Codex / 重启 Codex。

## Usage / 使用方法

### Check Usage (Dry Run) / 查看用量（试运行）

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\wait_for_next_codex_refresh.ps1 -DryRun
```

### Wait Until Next Refresh / 等待额度刷新

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\wait_for_next_codex_refresh.ps1 -MaxWaitSeconds -1
```

### Get Raw Usage Output / 获取原始用量输出

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\get_codex_usage.ps1
```

## Scripts / 脚本

| Script | Description / 描述 |
|--------|---------------------|
| `get_codex_usage.ps1` | Read current Codex usage via app-server API / 通过 app-server API 读取当前用量 |
| `wait_for_next_codex_refresh.ps1` | Parse usage, calculate next refresh, optionally wait / 解析用量、计算下次刷新时间、可选等待 |
| `wait_until_credit_refresh.ps1` | Simple blocking wait for a specified duration / 简单阻塞等待指定时长 |

## Parameters / 参数

### wait_for_next_codex_refresh.ps1

| Parameter | Type | Default | Description / 描述 |
|-----------|------|---------|---------------------|
| `-DryRun` | Switch | False | Only print usage and refresh time, don't wait / 仅输出用量和刷新时间，不等待 |
| `-StartupWaitSeconds` | Int | 60 | Seconds to wait for Codex to start / 等待 Codex 启动的秒数 |
| `-StatusWaitSeconds` | Int | 20 | Seconds to wait for /status output / 等待 /status 输出的秒数 |
| `-ExtraSeconds` | Int | 5 | Extra buffer seconds after refresh / 刷新后额外缓冲秒数 |
| `-MaxWaitSeconds` | Int | 90 | Max allowed wait; -1 for unlimited / 最大等待秒数，-1 表示无限制 |
| `-UsageLine` | String[] | @() | Pre-supplied usage lines / 预提供的用量行 |

### get_codex_usage.ps1

| Parameter | Type | Default | Description / 描述 |
|-----------|------|---------|---------------------|
| `-StartupWaitSeconds` | Int | 60 | Seconds to wait for Codex to start / 等待 Codex 启动的秒数 |
| `-StatusWaitSeconds` | Int | 20 | Seconds to wait for /status output / 等待 /status 输出的秒数 |

## How It Works / 工作原理

1. **App-Server API**: Tries Windows Codex Desktop first, then WSL Codex CLI
   先尝试 Windows Codex Desktop，再尝试 WSL Codex CLI
2. **Fallback**: If app-server fails, scrapes WSL TUI `/status` output
   如果 app-server 失败，回退到抓取 WSL TUI 的 `/status` 输出
3. **Parsing**: Extracts 5h and Weekly limit lines with reset times
   提取 5 小时和每周限制行及其重置时间
4. **Waiting**: Blocks in terminal until the calculated refresh time
   在终端阻塞直到计算出的刷新时间

## Requirements / 环境要求

- Windows with PowerShell 5.1+ or PowerShell Core / Windows + PowerShell 5.1+ 或 PowerShell Core
- WSL with Python 3 (for fallback scraping) / WSL + Python 3（用于回退抓取）
- Codex Desktop or Codex CLI installed / 已安装 Codex Desktop 或 Codex CLI

## License / 许可证

MIT License - see [LICENSE](LICENSE) for details.
MIT 许可证 - 详见 [LICENSE](LICENSE)。

## Author / 作者

ZHAO YIFENG
