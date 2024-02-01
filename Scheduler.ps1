$Domains = ./Get-CertificatesExpiry.ps1 list-domains-only

while ($true) {

    foreach ($Domain in $Domains) {
        $DaysRemaining = ./Get-CertificatesExpiry.ps1 $Domain
        if ($DaysRemaining -lt 40) {
            Write-Host "Certificate $Domain will expire in $DaysRemaining days! I will try to renew it."
            ./Update-LECertificate.ps1 -FQDN $Domain -SshPort 22 -DnsServer auror.local
        }
    }
    
    # Start-Sleep -Seconds 5
}