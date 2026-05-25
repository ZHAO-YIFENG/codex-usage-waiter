param(
    [int]$StartupWaitSeconds = 60,
    [int]$StatusWaitSeconds = 20
)

$ErrorActionPreference = "Stop"

$env:CODEX_USAGE_STARTUP_WAIT = [string]$StartupWaitSeconds
$env:CODEX_USAGE_STATUS_WAIT = [string]$StatusWaitSeconds

function Get-NativeCodexPath {
    if ($env:CODEX_CLI_PATH -and (Test-Path -LiteralPath $env:CODEX_CLI_PATH)) {
        return $env:CODEX_CLI_PATH
    }

    $localBin = Join-Path $env:LOCALAPPDATA "OpenAI\Codex\bin"
    if (-not (Test-Path -LiteralPath $localBin)) {
        return $null
    }

    $candidate = Get-ChildItem -LiteralPath $localBin -Recurse -Filter "codex.exe" -ErrorAction SilentlyContinue |
        Sort-Object LastWriteTime -Descending |
        Select-Object -First 1

    if ($candidate) {
        return $candidate.FullName
    }

    return $null
}

$appServerPython = @'
from datetime import datetime, timezone
import json
import os
import shutil
import signal
import subprocess
import sys
import threading
import queue
import time

host = os.environ.get("CODEX_USAGE_HOST", "native")
status_wait = int(os.environ.get("CODEX_USAGE_STATUS_WAIT", "20"))

codex = os.environ.get("CODEX_CLI_PATH")
if not codex:
    if host == "wsl":
        home_codex = os.path.expanduser("~/.local/bin/codex")
        codex = home_codex if os.path.exists(home_codex) else shutil.which("codex")
    else:
        codex = shutil.which("codex")

if not codex:
    print(f"Codex CLI was not found for {host}.", file=sys.stderr)
    sys.exit(1)

events = queue.Queue()


def send(proc, request):
    proc.stdin.write(json.dumps(request, separators=(",", ":")) + "\n")
    proc.stdin.flush()


def enqueue_lines(name, stream):
    try:
        for line in stream:
            events.put((name, line.rstrip("\n")))
    finally:
        events.put((name, None))


def read_response(proc, request_id, timeout_seconds):
    deadline = time.time() + timeout_seconds
    stderr = []

    while time.time() < deadline:
        try:
            stream_name, line = events.get(timeout=0.2)
        except queue.Empty:
            if proc.poll() is not None:
                break
            continue

        if line is None:
            continue

        if stream_name == "stderr":
            stderr.append(line)
            continue

        try:
            message = json.loads(line)
        except json.JSONDecodeError:
            continue

        if message.get("id") == request_id:
            if "error" in message:
                raise RuntimeError(json.dumps(message["error"], ensure_ascii=False))
            return message.get("result")

    detail = "\n".join(stderr[-5:])
    raise TimeoutError(detail or f"timed out waiting for response id {request_id}")


def format_reset(epoch_seconds):
    if epoch_seconds is None:
        return None

    reset = datetime.fromtimestamp(int(epoch_seconds), timezone.utc).astimezone()
    now = datetime.now().astimezone()
    clock = reset.strftime("%H:%M:%S")

    if reset.date() == now.date():
        return clock

    return f"{clock} on {reset.day} {reset.strftime('%b')}"


def window_name(window):
    minutes = window.get("windowDurationMins")
    if minutes == 300:
        return "5h limit"
    if minutes == 10080:
        return "Weekly limit"
    if minutes == 1440:
        return "Daily limit"
    if minutes:
        return f"{minutes}m limit"
    return "Codex limit"


def format_window(window):
    reset = format_reset(window.get("resetsAt"))
    if reset is None:
        return None

    return f"{window_name(window)}: {window.get('usedPercent', 0)}% used (resets {reset})"


proc = subprocess.Popen(
    [codex, "app-server", "--listen", "stdio://"],
    stdin=subprocess.PIPE,
    stdout=subprocess.PIPE,
    stderr=subprocess.PIPE,
    text=True,
    bufsize=1,
)

threading.Thread(target=enqueue_lines, args=("stdout", proc.stdout), daemon=True).start()
threading.Thread(target=enqueue_lines, args=("stderr", proc.stderr), daemon=True).start()

try:
    timeout = max(5, status_wait)

    send(
        proc,
        {
            "jsonrpc": "2.0",
            "id": 1,
            "method": "initialize",
            "params": {
                "clientInfo": {
                    "name": "codex-usage-waiter",
                    "version": "0.1.0",
                },
                "capabilities": {
                    "experimentalApi": True,
                },
            },
        },
    )
    read_response(proc, 1, timeout)

    send(
        proc,
        {
            "jsonrpc": "2.0",
            "id": 2,
            "method": "account/rateLimits/read",
            "params": None,
        },
    )
    result = read_response(proc, 2, timeout)

    snapshots = result.get("rateLimitsByLimitId") or {}
    snapshot = snapshots.get("codex") or result.get("rateLimits") or {}
    lines = []

    for key in ("primary", "secondary"):
        window = snapshot.get(key)
        if not window:
            continue
        line = format_window(window)
        if line:
            lines.append(line)

    if not lines:
        raise RuntimeError("account/rateLimits/read returned no reset windows")

    for line in lines:
        print(line)
finally:
    try:
        proc.terminate()
    except Exception:
        pass
    try:
        proc.wait(timeout=2)
    except Exception:
        try:
            os.kill(proc.pid, signal.SIGKILL)
        except Exception:
            pass
'@

$oldCodexCliPath = $env:CODEX_CLI_PATH
$oldCodexUsageHost = $env:CODEX_USAGE_HOST

$nativeCodex = Get-NativeCodexPath
if ($nativeCodex) {
    $env:CODEX_CLI_PATH = $nativeCodex
    $env:CODEX_USAGE_HOST = "native"
    $appServerOutput = $appServerPython | python - 2>&1
    if ($LASTEXITCODE -eq 0) {
        $env:CODEX_CLI_PATH = $oldCodexCliPath
        $env:CODEX_USAGE_HOST = $oldCodexUsageHost
        $appServerOutput
        exit 0
    }
}

$env:CODEX_CLI_PATH = $oldCodexCliPath
$env:CODEX_USAGE_HOST = "wsl"
$appServerOutput = $appServerPython | wsl python3 - 2>&1
$wslAppServerExitCode = $LASTEXITCODE
$env:CODEX_CLI_PATH = $oldCodexCliPath
$env:CODEX_USAGE_HOST = $oldCodexUsageHost

if ($wslAppServerExitCode -eq 0) {
    $appServerOutput
    exit 0
}

$python = @'
import fcntl
import os
import pty
import re
import select
import shutil
import signal
import struct
import subprocess
import sys
import termios
import time

ROWS = 45
COLS = 140

startup_wait = int(os.environ.get("CODEX_USAGE_STARTUP_WAIT", "60"))
status_wait = int(os.environ.get("CODEX_USAGE_STATUS_WAIT", "20"))

home_codex = os.path.expanduser("~/.local/bin/codex")
codex = os.environ.get("CODEX_CLI_PATH")
if not codex:
    codex = home_codex if os.path.exists(home_codex) else shutil.which("codex")

if not codex:
    print("Codex CLI was not found in WSL.", file=sys.stderr)
    sys.exit(1)

master, slave = pty.openpty()
fcntl.ioctl(slave, termios.TIOCSWINSZ, struct.pack("HHHH", ROWS, COLS, 0, 0))

env = dict(os.environ)
env["TERM"] = "xterm-256color"
env.setdefault("COLORTERM", "truecolor")

proc = subprocess.Popen(
    [codex, "--ask-for-approval", "never", "--sandbox", "read-only"],
    stdin=slave,
    stdout=slave,
    stderr=slave,
    close_fds=True,
    preexec_fn=os.setsid,
    env=env,
)
os.close(slave)

screen = [[" "] * COLS for _ in range(ROWS)]
row = 0
col = 0
saved = (0, 0)
state = "normal"
esc = ""
osc = False


def put_char(ch):
    global row, col
    if ch == "\n":
        row = min(ROWS - 1, row + 1)
        return
    if ch == "\r":
        col = 0
        return
    if ch == "\b":
        col = max(0, col - 1)
        return
    if ch < " ":
        return

    screen[row][col] = ch
    col += 1
    if col >= COLS:
        col = 0
        row = min(ROWS - 1, row + 1)


def handle_csi(seq):
    global row, col, screen, saved

    final = seq[-1]
    params = re.sub(r"^[?<>=!]*", "", seq[:-1])
    nums = []
    for item in params.split(";") if params else []:
        try:
            nums.append(int(item) if item else 0)
        except ValueError:
            nums.append(0)

    def num(index, default):
        return nums[index] if index < len(nums) and nums[index] else default

    if final in "Hf":
        row = max(0, min(ROWS - 1, num(0, 1) - 1))
        col = max(0, min(COLS - 1, num(1, 1) - 1))
    elif final == "A":
        row = max(0, row - num(0, 1))
    elif final == "B":
        row = min(ROWS - 1, row + num(0, 1))
    elif final == "C":
        col = min(COLS - 1, col + num(0, 1))
    elif final == "D":
        col = max(0, col - num(0, 1))
    elif final == "G":
        col = max(0, min(COLS - 1, num(0, 1) - 1))
    elif final == "J":
        mode = num(0, 0)
        if mode in (2, 3):
            screen = [[" "] * COLS for _ in range(ROWS)]
            row = 0
            col = 0
        elif mode == 0:
            for cc in range(col, COLS):
                screen[row][cc] = " "
            for rr in range(row + 1, ROWS):
                screen[rr] = [" "] * COLS
    elif final == "K":
        mode = num(0, 0)
        if mode == 0:
            for cc in range(col, COLS):
                screen[row][cc] = " "
        elif mode == 1:
            for cc in range(0, col + 1):
                screen[row][cc] = " "
        elif mode == 2:
            screen[row] = [" "] * COLS
    elif final == "s":
        saved = (row, col)
    elif final == "u":
        row, col = saved


def feed(data):
    global state, esc, osc, row, col, saved

    text = data.decode("utf-8", "replace")
    i = 0
    while i < len(text):
        ch = text[i]
        if osc:
            if ch == "\x07":
                osc = False
            elif ch == "\x1b" and i + 1 < len(text) and text[i + 1] == "\\":
                osc = False
                i += 1
        elif state == "normal":
            if ch == "\x1b":
                state = "esc"
                esc = ""
            else:
                put_char(ch)
        elif state == "esc":
            if ch == "[":
                state = "csi"
                esc = ""
            elif ch == "]":
                osc = True
                state = "normal"
            elif ch == "7":
                saved = (row, col)
                state = "normal"
            elif ch == "8":
                row, col = saved
                state = "normal"
            elif ch in "()#%":
                state = "skip1"
            else:
                state = "normal"
        elif state == "skip1":
            state = "normal"
        elif state == "csi":
            esc += ch
            if "@" <= ch <= "~":
                handle_csi(esc)
                state = "normal"
        i += 1


def read_for(seconds):
    end = time.time() + seconds
    while time.time() < end:
        ready, _, _ = select.select([master], [], [], 0.1)
        if master not in ready:
            continue
        try:
            data = os.read(master, 8192)
        except OSError:
            break
        if not data:
            break
        feed(data)


try:
    read_for(startup_wait)
    os.write(master, b"/status")
    time.sleep(0.2)
    os.write(master, b"\x1b[13;1u")
    read_for(status_wait)

    lines = ["".join(row_chars).strip() for row_chars in screen]
    usage_lines = [
        line
        for line in lines
        if re.search(r"\b(5h|daily|weekly|monthly|annual)\s+limit:", line, re.IGNORECASE)
    ]

    if not usage_lines:
        print("Could not find Codex usage lines in /status output.", file=sys.stderr)
        sys.exit(2)

    for line in usage_lines:
        line = re.sub(r"[ \t]+", " ", line)
        line = re.sub(r"^[^A-Za-z0-9]*", "", line)
        line = re.sub(r"[^A-Za-z0-9)]*$", "", line).strip()
        match = re.match(r"^(.+? limit:)\s*(?:\[[^\]]+\]\s*)?(.*)$", line, re.IGNORECASE)
        print(f"{match.group(1)} {match.group(2)}" if match else line)
finally:
    try:
        os.killpg(os.getpgid(proc.pid), signal.SIGTERM)
    except Exception:
        pass
    try:
        proc.wait(timeout=2)
    except Exception:
        pass
'@

$python | wsl python3 -
exit $LASTEXITCODE
