# Codex Usage Waiter

A Codex plugin that checks your Codex usage and waits until the next credit refresh.

[中文版](README.zh-CN.md)

## Features

- Read current Codex usage via the local app-server API
- Display usage percentage and reset time for 5h/Weekly limits
- Wait in terminal until the next credit refresh
- Support both Windows Codex Desktop and WSL Codex CLI
- Dry-run mode to check usage without waiting

## Installation

**Via Marketplace:**

```bash
codex plugin marketplace add ZHAO-YIFENG/codex-usage-waiter
```

Then install from the plugin directory in Codex.

**Manual Installation:**

1. Clone this repository:
   ```bash
   git clone https://github.com/ZHAO-YIFENG/codex-usage-waiter.git
   ```

2. Copy to your Codex plugins directory:
   ```powershell
   Copy-Item -Recurse codex-usage-waiter $env:USERPROFILE\.codex\plugins\codex-usage-waiter
   ```

3. Restart Codex.

## Usage

**Check Usage (Dry Run):**

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\wait_for_next_codex_refresh.ps1 -DryRun
```

**Wait Until Next Refresh:**

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\wait_for_next_codex_refresh.ps1 -MaxWaitSeconds -1
```

**Get Raw Usage Output:**

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\get_codex_usage.ps1
```

## Scripts

| Script | Description |
|--------|-------------|
| `get_codex_usage.ps1` | Read current Codex usage via app-server API |
| `wait_for_next_codex_refresh.ps1` | Parse usage, calculate next refresh, optionally wait |
| `wait_until_credit_refresh.ps1` | Simple blocking wait for a specified duration |

## Parameters

**wait_for_next_codex_refresh.ps1**

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `-DryRun` | Switch | False | Only print usage and refresh time, don't wait |
| `-StartupWaitSeconds` | Int | 60 | Seconds to wait for Codex to start |
| `-StatusWaitSeconds` | Int | 20 | Seconds to wait for /status output |
| `-ExtraSeconds` | Int | 5 | Extra buffer seconds after refresh |
| `-MaxWaitSeconds` | Int | 90 | Max allowed wait; -1 for unlimited |
| `-UsageLine` | String[] | @() | Pre-supplied usage lines |

**get_codex_usage.ps1**

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `-StartupWaitSeconds` | Int | 60 | Seconds to wait for Codex to start |
| `-StatusWaitSeconds` | Int | 20 | Seconds to wait for /status output |

## How It Works

1. Tries Windows Codex Desktop first, then WSL Codex CLI via app-server API
2. If app-server fails, falls back to scraping WSL TUI `/status` output
3. Extracts 5h and Weekly limit lines with reset times
4. Blocks in terminal until the calculated refresh time

## Requirements

- Windows with PowerShell 5.1+ or PowerShell Core
- WSL with Python 3 (for fallback scraping)
- Codex Desktop or Codex CLI installed

## License

MIT License - see [LICENSE](LICENSE).

## Author

ZHAO YIFENG
