param(
    [string]$argument
)

function Get-CertificateExpirationStatus {
    param(
        [string]$certPath
    )

    $opensslCommand = "openssl x509 -enddate -noout -in $certPath"
    $endDateOutput = Invoke-Expression -Command $opensslCommand
    $endDate = $endDateOutput.Split("=")[1].Trim()
    $endDate = $endDate -replace "GMT$", "+00:00"
    
    # Заменяем двойные пробелы на одинарные
    $endDate = $endDate -replace "  ", " "
    $format = "MMM d HH:mm:ss yyyy zzz"
    $culture = [System.Globalization.CultureInfo]::InvariantCulture
    $endDate = [DateTime]::ParseExact($endDate, $format, $culture)
    $endDateRaw = $endDate.ToString("MM/dd/yyyy HH:mm:ss")
    $endDate = $endDate.ToString("dd.MM.yyyy")
    $daysUntilExpiration = ((Get-Date $endDateRaw) - (Get-Date)).Days

    $global:expirationStatus = "Осталось $daysUntilExpiration дней. Закончится $($endDate)"

    return $daysUntilExpiration
}

function Get-Domains-For-Zabbix {
    $result = @{
        data = @()
    }

    foreach ($directory in Get-ChildItem "/etc/letsencrypt/live" -Name) {
        $certPath = Join-Path "/etc/letsencrypt/live" $directory "cert.pem"

        if (Test-Path $certPath) {

            $result.data += @{
                "{#DOMAIN}" = "$directory"
            }
        }
    }

    return $result
}

$certDirectories = Get-ChildItem "/etc/letsencrypt/live" -Name

if ($argument -eq "list-domains-for-zabbix") {
    $result = Get-Domains-For-Zabbix
    Write-Output ($result | ConvertTo-Json -Depth 2 -Compress)
}
else {
    $result = @{
        data = @()
    }

    foreach ($directory in $certDirectories) {
        $certPath = Join-Path "/etc/letsencrypt/live" $directory "cert.pem"

        if (Test-Path $certPath) {
            $expirationDate = Get-CertificateExpirationStatus -certPath $certPath

            if (-not $argument) {
                Write-Output "$directory - $expirationStatus"
            }
            elseif ($argument -eq "list-domains-only") {
                Write-Output $directory
            }
            elseif ($argument -eq $directory) {
                Write-Output $expirationDate
            }
        }
    }
}