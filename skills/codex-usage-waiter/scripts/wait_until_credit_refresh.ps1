param(
    [double]$WaitHours = 0,
    [double]$WaitMinutes = 0,
    [double]$WaitSeconds = 0,
    [int]$Hour = 2,
    [int]$Minute = 30
)

$seconds = [Math]::Ceiling(
    ($WaitHours * 3600) +
    ($WaitMinutes * 60) +
    $WaitSeconds
)

if ($seconds -le 0) {
    $now = Get-Date
    $target = Get-Date -Hour $Hour -Minute $Minute -Second 0

    if ($now -gt $target) {
        $target = $target.AddDays(1)
    }

    $seconds = [Math]::Ceiling(($target - $now).TotalSeconds)
}

if ($seconds -gt 0) {
    Start-Sleep -Seconds $seconds
}

exit 0
