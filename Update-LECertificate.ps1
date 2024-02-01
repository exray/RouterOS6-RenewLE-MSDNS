param(
    [Parameter(Position = 0, Mandatory = $true, ParameterSetName = 'Positional')]
    [string]$FQDN,

    [Parameter(Position = 1, Mandatory = $true, ParameterSetName = 'Positional')]
    [string]$SshPort,
    
    [Parameter(Position = 2, Mandatory = $true, ParameterSetName = 'Positional')]
    [string]$DnsServer
)

$DebugPreference = 'Continue'

# Подключаем все дополнительные функции, которые лежат в каталоге modules
$FunctionsPath = $PSScriptRoot + "/modules/"
$FunctionsList = Get-ChildItem -Path $FunctionsPath -Name

foreach ($Function in $FunctionsList) {
    . ($FunctionsPath + $Function)
}

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
Write-Host "[0/5] Инициализирую устройство" -ForegroundColor Yellow

# TODO! Если устройство ещё не настроено для работы, раскомментируй следующую строку
# Set-CertbotInitialSetup -SshUser cits2 -SshHost $FQDN -SshPort $SshPort
# Write-Progress -Activity "Инициализировал устройство" -PercentComplete 20

# Читаем ТХТ-запись, которую нужно указать на DNS-сервере
Write-Host "[1/5] Запрашиваю необходимую TXT-запись. " -ForegroundColor Yellow -NoNewline
$TxtRecordValue=$(Get-CertbotTxtRecord $FQDN)
if (!$TxtRecordValue) {
    Write-Host "Не смог запросить необходимую TXT-запись." -ForegroundColor Red
    Break
} else {
    Write-Host "Необходимая запись: $TxtRecordValue" -ForegroundColor Green
}

# Генерируем конфиг
Write-Host "[2/5] Генерирую конфиг для подключения к устройству. " -ForegroundColor Yellow -NoNewline
New-CertbotConfig -RouterOsHost $FQDN -RouterOsSshPort $SshPort
if (!$?) {
    Write-Host "Возникла проблема при генерации конфига." -ForegroundColor Red
} else {
    Write-Host "Конфиг сгенерирован." -ForegroundColor Green
}

Write-Host "[3/5] Проверяю TXT-запись. " -ForegroundColor Yellow -NoNewline
try {
    Set-DnsRecord -DnsServerAddress $DnsServer -FQDN $FQDN -Credential $Cred -TxtRecordValue $TxtRecordValue -ErrorAction Stop
} catch [System.Management.Automation.Remoting.PSRemotingTransportException] {
    Write-Host "Не удалось подключиться к $DnsServer" -ForegroundColor Red
    Break
} catch [Exception] {
    Write-Host "Произошла ошибка типа $($_.Exception.GetType().FullName): $_" -ForegroundColor Red
    Break
}

$SleepTimer = 10
Write-Host "Беру паузу в $($SleepTimer) минут для применения изменений в DNS" -ForegroundColor Blue
Start-CountdownTimer -Minutes $SleepTimer

Write-Host "[4/5] Генерирую новый сертификат и заменяю его на устройстве $FQDN" -ForegroundColor Yellow
certbot certonly --non-interactive --agree-tos --preferred-challenges=dns --manual -d $FQDN --manual-public-ip-logging-ok --manual-auth-hook "echo 'Skipping manual-auth-hook'" --post-hook "/opt/letsencrypt-routeros/letsencrypt-routeros.sh -c /tmp/routeros.settings"

# Если не сработала прошлая команда, есть чудесный костыль ниже
# /opt/letsencrypt-routeros/letsencrypt-routeros.sh -c /tmp/routeros.settings 
Write-Host "[5/5] Удаляю временный конфиг" -ForegroundColor Yellow
Remove-Item /tmp/routeros.settings

# TODO Разберись, как узнать, какие даты у сертификатов: openssl x509 -enddate -noout -in /etc/letsencrypt/live/vpn1.mirproduktov.cits.ru/cert.pem чтобы форсированно запустить обновление нужных сертификатов
# TODO Разберись, как хранить данные для подключения к хостам: адрес (уже передаётся через консоль) и порт. Возможно передавать через аргументы командной строки