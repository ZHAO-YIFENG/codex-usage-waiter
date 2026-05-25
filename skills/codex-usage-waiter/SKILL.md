---
name: codex-usage-waiter
description: Run the local Codex usage waiter PowerShell script directly instead of calling an MCP tool. Use when the user asks to check Codex usage, calculate the next credit refresh, wait until Codex credits refresh, or explicitly mentions Codex Usage Waiter.
---

# Codex Usage Waiter

This plugin intentionally exposes no MCP tool. Long waits exceed Codex's MCP tool-call timeout, so use the PowerShell script directly.

## Script

Resolve script paths relative to this `SKILL.md` file. The scripts are bundled in:

```text
scripts
```

Run a real blocking wait:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File <skill-dir>\scripts\wait_for_next_codex_refresh.ps1 -MaxWaitSeconds -1
```

Use `-DryRun` to only print current usage, next refresh time, and wait seconds:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File <skill-dir>\scripts\wait_for_next_codex_refresh.ps1 -DryRun
```

## Behavior

- The script checks Codex usage through the local app-server API.
- It tries Windows Codex Desktop first, then the WSL Codex CLI.
- If app-server reads fail, it falls back to WSL TUI `/status` scraping.
- `-MaxWaitSeconds -1` means a real unbounded terminal wait until the next refresh.

## Bundled Script Root

```text
<skill-dir>\scripts
```

The scripts are intentionally bundled inside the skill so the plugin can be shared and reused without relying on the original author's local `.codex\scripts` directory.
