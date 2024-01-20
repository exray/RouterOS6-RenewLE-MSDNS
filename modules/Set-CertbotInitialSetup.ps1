function Set-CertbotInitialSetup {
    param (
        [Parameter(ValueFromPipeline = $true, Mandatory=$true)][string]$SshUser,
        [Parameter(ValueFromPipeline = $true, Mandatory=$true)][string]$SshHost,
        [Parameter(ValueFromPipeline = $true, Mandatory=$true)][string]$SshPort = "22",
        [Parameter(ValueFromPipeline = $true)][string]$MtCertbotUser = "certbot",
        [Parameter(ValueFromPipeline = $true)][string]$SshKeyPath = "/opt/letsencrypt-routeros/id_rsa.pub",
        [Parameter(ValueFromPipeline = $true)][string]$TempConfigFile = "/tmp/certbot_initial_config.rsc"
    )
    
    $MtCertbotPass = passgen -l 10 -n 1

    $Credential = Get-Credential -UserName $SshUser -Message "Укажи SSH-пароль для доступа к устройству $SshHost"
    $SshPassword = $Credential.GetNetworkCredential().Password  

    Write-Host -ForegroundColor Yellow "Копирую публичный ключ"
    $SshKeyFile = $SshKeyPath -split "/"
    $SshKeyFile = $SshKeyFile[-1]
    $ScpCommand = "sshpass -p $SshPassword scp -P $SshPort -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -r $SshKeyPath ${SshUser}@${SshHost}:${SshKeyFile}"
    Write-Debug $ScpCommand
    Invoke-Expression $ScpCommand
    
    Write-Host -ForegroundColor Yellow "Генерирую файл начальных настроек"
    New-Item $TempConfigFile -Force

    $ConfigContent = @"
:if ([/user find name=$MtCertbotUser] = "") do={:log info "User $MtCertbotUser not found... Add it"}
:delay 2
:if ([/user find name=$MtCertbotUser] = "") do={/user add name=$MtCertbotUser group=full disabled=no password=$MtCertbotPass}
:delay 2
/user ssh-keys import user=$MtCertbotUser public-key-file=$SshKeyFile
:delay 2
/file remove $SshKeyFile
"@
    
    $ConfigContent | Out-File -FilePath $TempConfigFile -Encoding UTF8

    Write-Host -ForegroundColor Yellow "Выполняю инициализацию на устройстве $SshHost"

    $InitCommand = "bash -c 'cat $TempConfigFile | sshpass -p $SshPassword ssh ${SshUser}@${SshHost} -p $SshPort -T -o StrictHostKeyChecking=no'"
    Invoke-Expression $InitCommand

    Write-Host -ForegroundColor Yellow "Удаляю временный файл настроек"
    Remove-Item $TempConfigFile -Force
}