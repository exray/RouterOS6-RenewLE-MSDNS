# Подключаем все дополнительные функции, которые лежат в каталоге modules
$FunctionsPath = $PSScriptRoot + "/modules/"
$FunctionsList = Get-ChildItem -Path $FunctionsPath -Name

foreach ($Function in $FunctionsList) {
    . ($FunctionsPath + $Function)
}


$FQDN = $args[0]
$SshPort = $args[1]
$DnsServer = "machine-a-dc.auror.local"

try {
    $Cred = Import-Clixml ../myCred__.xml    
}
catch {
    Write-Host "Не вижу сохранённых данных для подключения к $DnsServer. Укажи данные для подключения:"
    $Cred = Get-Credential
    $Cred | Export-Clixml ../myCred__.xml
    $Cred = Import-Clixml ../myCred__.xml    
}

# Инициализируем наше устройство, чтобы им можно было управлять
Write-Host -ForegroundColor Yellow "[0/5] Инициализирую устройство"

# TODO! Если устройство ещё не настроено для работы, раскомментируй следующую строку
# Set-CertbotInitialSetup -SshUser cits2 -SshHost $FQDN -SshPort $SshPort
# Write-Progress -Activity "Инициализировал устройство" -PercentComplete 20

# Читаем ТХТ-запись, которую нужно указать на DNS-сервере
Write-Host -ForegroundColor Yellow "[1/5] Запрашиваю необходимую TXT-запись"
$TxtRecordValue=$(Get-CertbotTxtRecord $FQDN)
Write-Host "Получил значение $TxtRecordValue, LASTEXITCODE: $LASTEXITCODE"
if (!$?) {
    Write-Host "Не смог получить необходимую TXT-запись" -ForegroundColor Red
    Break
}
Write-Host -ForegroundColor Yellow "Необходимая запись: $TxtRecordValue"

# Генерируем конфиг
Write-Host -ForegroundColor Yellow "[2/5] Генерирую конфиг"
New-CertbotConfig -RouterOsHost $FQDN -RouterOsSshPort $SshPort

Write-Host -ForegroundColor Yellow "[3/5] Проверяю TXT-запись"
try {
    Set-DnsRecord -DnsServerAddress $DnsServer -FQDN $FQDN -Credential $Cred -TxtRecordValue $TxtRecordValue -ErrorAction Stop
} catch [System.Management.Automation.Remoting.PSRemotingTransportException] {
    Write-Host "Не удалось подключиться к $DnsServer"
    Break
} catch [Exception] {
    Write-Host "Произошла другая ошибка типа $($_.Exception.GetType().FullName): $_"
    Break
}

$SleepTimer = 10
Start-CountdownTimer -Minutes $SleepTimer
Write-Output "Беру паузу в $($SleepTimer) минут для применения изменений в DNS."

Write-Host -ForegroundColor Yellow "[4/5] Генерирую новый сертификат и заменяю его на $FQDN"
certbot certonly --non-interactive --agree-tos --preferred-challenges=dns --manual -d $FQDN --manual-public-ip-logging-ok --manual-auth-hook "echo 'Skipping manual-auth-hook'" --post-hook "/opt/letsencrypt-routeros/letsencrypt-routeros.sh -c /tmp/routeros.settings"

# Если не сработала прошлая команда, есть чудесный костыль ниже
# /opt/letsencrypt-routeros/letsencrypt-routeros.sh -c /tmp/routeros.settings 
Write-Host -ForegroundColor Yellow "[5/5] Удаляю временный конфиг"
Remove-Item /tmp/routeros.settings

# TODO Разберись, как узнать, какие даты у сертификатов: openssl x509 -enddate -noout -in /etc/letsencrypt/live/vpn1.mirproduktov.cits.ru/cert.pem чтобы форсированно запустить обновление нужных сертификатов
# TODO Разберись, как хранить данные для подключения к хостам: адрес (уже передаётся через консоль) и порт. Возможно передавать через аргументы командной строки