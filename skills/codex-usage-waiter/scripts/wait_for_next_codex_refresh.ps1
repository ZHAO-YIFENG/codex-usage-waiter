param(
    [switch]$DryRun,
    [int]$StartupWaitSeconds = 60,
    [int]$StatusWaitSeconds = 20,
    [int]$ExtraSeconds = 5,
    [int]$MaxWaitSeconds = 90,
    [string[]]$UsageLine = @()
)

$ErrorActionPreference = "Stop"

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$usageScript = Join-Path $scriptDir "get_codex_usage.ps1"
$waitScript = Join-Path $scriptDir "wait_until_credit_refresh.ps1"

function Get-ResetTarget {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Line,

        [Parameter(Mandatory = $true)]
        [datetime]$Now
    )

    if ($Line -notmatch "^(?<name>.+? limit:).*?\(resets (?<reset>[^)]+)\)") {
        throw "Could not parse reset time from usage line: $Line"
    }

    $name = $Matches["name"].TrimEnd(":")
    $resetText = $Matches["reset"].Trim()

    if ($resetText -match "^(?<hour>\d{1,2}):(?<minute>\d{2})(?::(?<second>\d{2}))?$") {
        $second = if ($Matches["second"]) { [int]$Matches["second"] } else { 0 }
        $target = Get-Date `
            -Year $Now.Year `
            -Month $Now.Month `
            -Day $Now.Day `
            -Hour ([int]$Matches["hour"]) `
            -Minute ([int]$Matches["minute"]) `
            -Second $second

        if ($target -le $Now) {
            $target = $target.AddDays(1)
        }
    }
    elseif ($resetText -match "^(?<time>\d{1,2}:\d{2}(?::\d{2})?)\s+on\s+(?<day>\d{1,2})\s+(?<month>[A-Za-z]+)$") {
        $monthMap = @{
            Jan = 1; January = 1
            Feb = 2; February = 2
            Mar = 3; March = 3
            Apr = 4; April = 4
            May = 5
            Jun = 6; June = 6
            Jul = 7; July = 7
            Aug = 8; August = 8
            Sep = 9; Sept = 9; September = 9
            Oct = 10; October = 10
            Nov = 11; November = 11
            Dec = 12; December = 12
        }

        $monthName = $Matches["month"]
        if (-not $monthMap.ContainsKey($monthName)) {
            throw "Unsupported reset month: $monthName"
        }

        $timeParts = $Matches["time"].Split(":")
        $second = if ($timeParts.Count -gt 2) { [int]$timeParts[2] } else { 0 }
        $target = Get-Date `
            -Year $Now.Year `
            -Month $monthMap[$monthName] `
            -Day ([int]$Matches["day"]) `
            -Hour ([int]$timeParts[0]) `
            -Minute ([int]$timeParts[1]) `
            -Second $second

        while ($target -le $Now) {
            $target = $target.AddYears(1)
        }
    }
    else {
        throw "Unsupported reset time format: $resetText"
    }

    [pscustomobject]@{
        Name = $name
        Line = $Line
        ResetText = $resetText
        Target = $target
    }
}

if ($UsageLine.Count -gt 0) {
    $usageOutput = $UsageLine
}
else {
    if (-not (Test-Path -LiteralPath $usageScript)) {
        throw "Usage script not found: $usageScript"
    }

    $usageOutput = & powershell -NoProfile -ExecutionPolicy Bypass `
        -File $usageScript `
        -StartupWaitSeconds $StartupWaitSeconds `
        -StatusWaitSeconds $StatusWaitSeconds

    if ($LASTEXITCODE -ne 0) {
        throw "Failed to read Codex usage. Exit code: $LASTEXITCODE"
    }
}

$limitLines = $usageOutput |
    Where-Object { $_ -match "^(5h|Weekly) limit:" }

if (-not $limitLines -or $limitLines.Count -eq 0) {
    throw "No 5h or Weekly limit lines found in usage output."
}

$now = Get-Date
$targets = @($limitLines | ForEach-Object { Get-ResetTarget -Line $_ -Now $now })
$next = $targets | Sort-Object Target | Select-Object -First 1
$seconds = [Math]::Ceiling(($next.Target - $now).TotalSeconds + $ExtraSeconds)

if ($seconds -lt 0) {
    $seconds = 0
}

Write-Host "Codex usage:"
$limitLines | ForEach-Object { Write-Host "  $_" }
Write-Host ""
Write-Host "Next refresh: $($next.Name) at $($next.Target.ToString("yyyy-MM-dd HH:mm:ss"))"
Write-Host "Wait seconds: $seconds"

if ($DryRun) {
    exit 0
}

if ($MaxWaitSeconds -ge 0 -and $seconds -gt $MaxWaitSeconds) {
    Write-Host ""
    Write-Host "Not waiting because the required wait exceeds MaxWaitSeconds ($MaxWaitSeconds)."
    Write-Host "Run again near the refresh time, or call with a larger MaxWaitSeconds outside Codex's MCP tool timeout."
    exit 0
}

if (-not (Test-Path -LiteralPath $waitScript)) {
    throw "Wait script not found: $waitScript"
}

& powershell -NoProfile -ExecutionPolicy Bypass -File $waitScript -WaitSeconds $seconds
exit $LASTEXITCODE
