function Get-CertbotTxtRecord {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)][string]$FQDN
    )

    # Создаём временные файлы
    $CertbotOutputFile = '/tmp/certbot_output.txt'
    $CertbotTxtRecordFile = '/tmp/certbot_txtrecord.txt'

    Start-Job -ScriptBlock {
        # У certbot можно использовать параметр --dry-run для тестов
        certbot certonly -v --preferred-challenges=dns --manual --manual-public-ip-logging-ok -d $using:FQDN --dry-run > $using:CertbotOutputFile 2>&1
    } | Out-Null
    

    Start-Sleep -Seconds 10
    Get-Process | Where-Object { $_.ProcessName -eq 'certbot' } | ForEach-Object { Stop-Process -Id $_.Id -Force }

    # Парсим данные, которые нужно указать в ТХТ-записи _acme-challenge
    $txtRecord = Select-String -Path $CertbotOutputFile -Pattern 'with the following value:' -Context 0,2 | ForEach-Object {
        $_.Context.PostContext[1] -split ':' -join ':'
    }

    # Сохраняем данные в файл
    if ($txtRecord) {
        $txtRecord.Trim() | Set-Content -Path $CertbotTxtRecordFile
    }

    try {
        $result = Get-Content $CertbotTxtRecordFile -ErrorAction Stop
    } catch [System.Management.Automation.ItemNotFoundException]{
        Write-Debug "Файл $CertbotTxtRecordFile не найден"
    }
    
    # Чистим временные файлы
    Remove-Item $CertbotOutputFile -ErrorAction SilentlyContinue
    Remove-Item $CertbotTxtRecordFile -ErrorAction SilentlyContinue

    return $result
}