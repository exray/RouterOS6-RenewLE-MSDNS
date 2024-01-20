function Start-CountdownTimer {
    param (
        [int]$Minutes = 1
    )

    $TotalSeconds = $Minutes * 60

    for ($i = $TotalSeconds; $i -ge 0; $i--) {
        $RemainingMinutes = [math]::floor($i / 60)
        $RemainingSeconds = $i % 60

        # Some corrections
        $DisplayMinutes = $RemainingMinutes
        $DisplaySeconds = $RemainingSeconds

        if ($RemainingMinutes -ge 10) {
            $DisplayMinutes = $RemainingMinutes % 10
        }

        # If seconds less than 10, 0 must be added as prefix
        $DisplaySecondsString = if ($DisplaySeconds -lt 10) { "0$DisplaySeconds" } else { $DisplaySeconds }

        $Output = "Осталось времени: $($DisplayMinutes):$DisplaySecondsString"

        Write-Host $Output -NoNewline

        Start-Sleep -Seconds 1

        # Clear previous Output to rewrite the progress
        $Clear = "`b" * $Output.Length
        Write-Host $Clear -NoNewline
    }
    Write-Host ""
}

Start-CountdownTimer -Minutes 5
