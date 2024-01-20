function Set-DnsRecord {
    param (
        [Parameter(Mandatory=$true)][string]$DnsServerAddress,
        [Parameter(Mandatory=$true)][string]$FQDN,
        [Parameter(Mandatory=$true)][pscredential]$Credential,
        [Parameter(Mandatory=$true)][string]$TxtRecordValue
    )
    
    # Разбираем полученный параметр домена на части, отделяя их точками
    $DomainSplitted = $FQDN.split('.')
    
    # Получаем домен первого уровня
    $ZoneName = $DomainSplitted[-2..-1] -join '.'

    # Получаем остальные уровни поддоменов
    $SubDomain = $DomainSplitted[0..($DomainSplitted.Length - 3)] -join '.'

    Invoke-Command -ComputerName $DnsServerAddress -Credential $Credential -Authentication Negotiate -ScriptBlock {
        try {
            $Record = Get-DnsServerResourceRecord -ZoneName $using:ZoneName -Name "_acme-challenge.$using:SubDomain" -ErrorAction Stop
            if ($Record) {
                $Record | Remove-DnsServerResourceRecord -ZoneName $using:ZoneName -Force -ErrorAction Stop
                Write-Output "Старая TXT-запись _acme-challenge.$using:SubDomain.$using:ZoneName была успешно удалена."
            }
            
            Write-Output "Добавляю новую TXT-запись _acme-challenge.$using:SubDomain.$using:ZoneName со значением $using:TxtRecordValue"
            Add-DnsServerResourceRecord -ZoneName $using:ZoneName -Name "_acme-challenge.$using:SubDomain" -Txt -DescriptiveText $using:TxtRecordValue -TimeToLive 00:01:00
        } catch {
            $OldData = Get-DnsServerResourceRecord -ZoneName $using:ZoneName -Name "_acme-challenge.$using:SubDomain" -RRType txt
            if ($OldData.RecordData.DescriptiveText -eq $using:TxtRecordValue) {
                Write-Output "Такая запись уже есть, пропускаем этот шаг"
                break
            } else {
                $NewData = $OldData.Clone()
                $NewData.RecordData.DescriptiveText = $using:TxtRecordValue
                Set-DnsServerResourceRecord -ZoneName $using:ZoneName -OldInputObject $OldData -NewInputObject $NewData
            }
        }
        Clear-DnsServerCache -Force
    }
}