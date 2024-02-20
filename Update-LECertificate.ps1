param(
    [Parameter(Position = 0, Mandatory = $true, ParameterSetName = 'Positional')]
    [string]$FQDN,

    [Parameter(Position = 1, Mandatory = $true, ParameterSetName = 'Positional')]
    [string]$SshPort,
    
    [Parameter(Position = 2, Mandatory = $true, ParameterSetName = 'Positional')]
    [string]$DnsServer,

    [Parameter(Position = 3, Mandatory = $true, ParameterSetName = 'Positional')]
    [string]$EmailAddress
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
}

# Очищаем список ошибок
$Error.Clear()

# Инициализируем наше устройство, чтобы им можно было управлять
Write-Host "[0/5] Инициализирую устройство. " -ForegroundColor Yellow

# TODO! Если устройство ещё не настроено для работы, раскомментируй следующую строку
# Set-CertbotInitialSetup -SshUser cits2 -SshHost $FQDN -SshPort $SshPort
# Write-Progress -Activity "Инициализировал устройство" -PercentComplete 20

# Читаем ТХТ-запись, которую нужно указать на DNS-сервере
Write-Host "[1/5] Запрашиваю необходимую TXT-запись. " -ForegroundColor Yellow -NoNewline
$TxtRecordValue=$(Get-CertbotTxtRecord $FQDN)
if (Get-ErrorPresence) {
    Write-Host "Не смог запросить необходимую TXT-запись." -ForegroundColor Red
    return
} else {
    Write-Host "Необходимая запись: $TxtRecordValue." -ForegroundColor Green
}

# Генерируем конфиг
Write-Host "[2/5] Генерирую конфиг для подключения к устройству. " -ForegroundColor Yellow -NoNewline
New-CertbotConfig -RouterOsHost $FQDN -RouterOsSshPort $SshPort
if (Get-ErrorPresence) {
    Write-Host "Возникла проблема при генерации конфига." -ForegroundColor Red
    return
} else {
    Write-Host "Конфиг сгенерирован." -ForegroundColor Green
}

Write-Host "[3/5] Проверяю TXT-запись. " -ForegroundColor Yellow -NoNewline
# $Error.Clear()
Set-DnsRecord -DnsServerAddress $DnsServer -FQDN $FQDN -Credential $Cred -TxtRecordValue $TxtRecordValue -ErrorAction Stop
if (Get-ErrorPresence) {
    Write-Host "Не удалось установить TXT-запись $TxtRecordValue." -ForegroundColor Red
    return
} else {
    Write-Host "TXT-запись $TxtRecordValue установлена." -ForegroundColor Green
}

$SleepTimer = 10
Write-Host "Беру паузу в $($SleepTimer) минут для применения изменений в DNS" -ForegroundColor Blue
Start-CountdownTimer -Minutes $SleepTimer

# TODO 1. Нужно сделать проверку на отсутствие приватного ключа

Write-Host "[4/5] Генерирую новый сертификат и заменяю его на устройстве $FQDN. " -ForegroundColor Yellow
certbot certonly --non-interactive --agree-tos --email $EmailAddress --preferred-challenges=dns --manual -d $FQDN --manual-public-ip-logging-ok --manual-auth-hook "echo 'Skipping manual-auth-hook'" --post-hook "/opt/letsencrypt-routeros/letsencrypt-routeros.sh -c /tmp/routeros.settings"
if (Get-ErrorPresence) {
    Write-Host "Не удалось установить сертификат на устройство $FQDN." -ForegroundColor Red
    return
} else {
    Write-Host "Сертификат установлен." -ForegroundColor Green
}

# Если не сработала прошлая команда, есть чудесный костыль ниже
# /opt/letsencrypt-routeros/letsencrypt-routeros.sh -c /tmp/routeros.settings 
Write-Host "[5/5] Удаляю временный конфиг" -ForegroundColor Yellow
Remove-Item /tmp/routeros.settings

# TODO Разберись, как хранить данные для подключения к хостам: адрес (уже передаётся через консоль) и порт. Возможно передавать через аргументы командной строки