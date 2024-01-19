function New-CertbotConfig {
    param (
        [string]$RouterOsUser = "certbot",
        [Parameter(Mandatory=$true)][string]$RouterOsHost,
        [int]$RouterOsSshPort = 22,
        [string]$RouterOSPrivateKey = "/opt/letsencrypt-routeros/id_rsa",
        [string]$ConfigPath = "/tmp/routeros.settings"
    )
    
    $ConfigContent = @"
ROUTEROS_USER=$RouterOsUser
ROUTEROS_HOST=$RouterOsHost
ROUTEROS_SSH_PORT=$RouterOsSshPort
ROUTEROS_PRIVATE_KEY=$RouterOSPrivateKey
DOMAIN=$RouterOsHost
"@
    
    $ConfigContent | Out-File -FilePath $ConfigPath -Encoding UTF8
}