# Подключаем модуль первичной инициализации
. ~/DEV-Initial-MT-setup.ps1

# Подключаем модуль определения нужной ТХТ-записи
. ~/DEV-gettxtrecord.ps1

# Подключаем модуль генерации конфига
. ~/DEV-GenerateConfig.ps1

$cred = Import-Clixml /root/myCred__.xml
$DNSServer = "cloudservices01.shared.cits.ru"
$FQDN = $args[0]
$SshPort = $args[1]

# Инициализируем наше устройство, чтобы им можно было управлять
Write-Host -ForegroundColor Yellow "[0/5] Инициализирую устройство"

# Если устройство ещё не настроено для работы, раскомментируй следующую строку
# Set-CertbotInitialSetup -SshUser cits2 -SshHost $FQDN -SshPort $SshPort
# Write-Progress -Activity "Инициализировал устройство" -PercentComplete 20

# Разбиваем полученный через консоль аргумент на части, отделяя их точками
$ArgsSplitted = $FQDN.split('.')

# Получаем домен первого уровня
$ZoneName = $ArgsSplitted[-2..-1] -join '.'

# Получаем остальные поддомены
$SubDomain = $ArgsSplitted[0..($ArgsSplitted.Length - 3)] -join '.'

# Читаем ТХТ-запись, которую нужно указать на DNS-сервере
Write-Host -ForegroundColor Yellow "[1/5] Запрашиваю необходимую ТХТ-запись"
$TxtRecord=$(Get-CertbotTxtRecord $FQDN)
Write-Host -ForegroundColor Yellow "Необходимая запись: $TxtRecord"

# Генерируем конфиг
Write-Host -ForegroundColor Yellow "[2/5] Генерирую конфиг"
New-CertbotConfig -RouterOsHost $FQDN -RouterOsSshPort $SshPort 

# Обновляем ТХТ-запись на DNS-сервере
Write-Host -ForegroundColor Yellow "[3/5] Проверяю ТХТ-запись _acme-challenge.$SubDomain.$ZoneName на сервере $DNSServer"
Invoke-Command -ComputerName $DNSServer -Credential $Cred -Authentication Negotiate -ScriptBlock {
    try {
        $Record = Get-DnsServerResourceRecord -ZoneName $using:ZoneName -Name "_acme-challenge.$using:SubDomain" -ErrorAction Stop
        if ($Record) {
            $Record | Remove-DnsServerResourceRecord -ZoneName $using:ZoneName -Force -ErrorAction Stop
            Write-Output "Старая ТХТ-запись _acme-challenge.$using:SubDomain.$using:ZoneName была успешно удалена."
        }
        Add-DnsServerResourceRecord -ZoneName $using:ZoneName -Name "_acme-challenge.$using:SubDomain" -Txt -DescriptiveText $using:TxtRecord -TimeToLive 00:01:00
    } catch {
        $OldData = Get-DnsServerResourceRecord -ZoneName $using:ZoneName -Name "_acme-challenge.$using:SubDomain" -RRType txt
        if ($OldData.RecordData.DescriptiveText -eq $using:TxtRecord) {
            Write-Output "Такая запись уже есть, пропускаем этот шаг"
            break
        } else {
            $NewData = $OldData.Clone()
            $NewData.RecordData.DescriptiveText = $using:TxtRecord
            Set-DnsServerResourceRecord -ZoneName $using:ZoneName -OldInputObject $OldData -NewInputObject $NewData
        }
    }
    Clear-DnsServerCache -Force
    function Format-Minutes($Minutes) {
        if ($Minutes -eq 1) {
            return "$Minutes минута прошла"
        } elseif ($Minutes -ge 2 -and $Minutes -le 4) {
            return "$Minutes минуты прошло"
        } else {
            return "$Minutes минут прошло"
        }
    }
    
    $Estimate = 10 # Указываем в минутах время паузы для применения изменений в DNS
    $NowTime = Get-Date -Format 'HH:mm:ss'
    $NowDateTime = [DateTime]::ParseExact($NowTime, 'HH:mm:ss', $null)
    Write-Output "Беру паузу в $($Estimate) минут для применения изменений в DNS. Ожидаю завершение в $($NowDateTime.AddMinutes($Estimate))"
    Start-Sleep -Seconds ($Estimate * 6)
    for ($Counter = 1; $Counter -le 10; $Counter++) {
        $FormattedMinutes = Format-Minutes($Counter)
        Write-Output "$FormattedMinutes, осталось $($Estimate - 1)."
        Start-Sleep -Seconds ($Estimate * 6)
        $Estimate -= 1
    }
}

Write-Host -ForegroundColor Yellow "[4/5] Генерирую новый сертификат и заменяю его на устройстве $FQDN"
certbot certonly --non-interactive --agree-tos --preferred-challenges=dns --manual -d $FQDN --manual-public-ip-logging-ok --manual-auth-hook "echo 'Skipping manual-auth-hook'" --post-hook "/opt/letsencrypt-routeros/letsencrypt-routeros.sh -c /tmp/routeros.settings"

# Если не сработала прошлая команда, есть чудесный костыль ниже
# /opt/letsencrypt-routeros/letsencrypt-routeros.sh -c /tmp/routeros.settings 
Write-Host -ForegroundColor Yellow "[5/5] Удаляю временный конфиг"
Remove-Item /tmp/routeros.settings

# Разберись, как узнать, какие даты у сертификатов: openssl x509 -enddate -noout -in /etc/letsencrypt/live/vpn1.mirproduktov.cits.ru/cert.pem
# чтобы запустить форсированно обновление нужных сертификатов
# Разберись, как хранить данные для подключения к хостам: адрес (уже передаётся через консоль) и порт. Возможно передавать через аргументы командной строки