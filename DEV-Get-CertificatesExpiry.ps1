$certDirectories = Get-ChildItem -Path "/etc/letsencrypt/live" -Directory

foreach ($directory in $certDirectories) {
    $certPath = Join-Path -Path $directory.FullName -ChildPath "cert.pem"
    if (Test-Path $certPath) {
        $endDateAll = openssl x509 -enddate -noout -in $certPath 2>&1 | Select-String "notAfter="
        $endDateAll | ForEach-Object {
            $endDate = ($_ -split "=")[1]
            $format = "MMM d HH:mm:ss yyyy zzz"
            $culture = [System.Globalization.CultureInfo]::InvariantCulture
            # Заменяем "GMT" на "+00:00" для правильного разбора
            $endDate = $endDate -replace "GMT$", "+00:00"
            # Заменяем двойные пробелы на одинарные
            $endDate = $endDate -replace "  ", " "
            $endDate = [DateTime]::ParseExact($endDate, $format, $culture)
            $endDate = $endDate.ToString("MM/dd/yyyy HH:mm:ss")
            $daysUntilExpiration = ((Get-Date $endDate) - (Get-Date)).Days
            # $endDate = $endDate.ToString("dd/MM/yyyy HH:mm:ss")

            if ($daysUntilExpiration -lt 14) {
                $expirationStatus = "Срок действия сертификата закончится через $daysUntilExpiration дней"
            } else {
                $expirationStatus = "Срок действия сертификата закончится $endDate"
            }

            Write-Host "$($directory.Name) - $expirationStatus"
        }
    }
}