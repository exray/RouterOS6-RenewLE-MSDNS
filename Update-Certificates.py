import os
import subprocess

def check_certificate_expiry(domain):
    print(f"Checking expiry for domain: {domain}")
    result = subprocess.run(
        ["python", "/root/RouterOS6-RenewLE-MSDNS/Get-CertsExpire.py", domain],
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE
    )
    output = result.stdout.decode('utf-8').strip()
    if output.isdigit():
        print(f"Days until expiration for {domain}: {output}")
        return int(output)
    else:
        print(f"Error: Unexpected output for domain {domain}: '{output}'")
        return None

def update_certificate(domain, port, dns_server, email):
    command = ["pwsh", "/root/RouterOS6-RenewLE-MSDNS/Update-LECertificate.ps1", domain, port, dns_server, email]
    print(f"Updating certificate for domain: {domain} with port: {port}, DNS server: {dns_server}, email: {email}")
    subprocess.run(command)
    print(f"Certificate update initiated for {domain}")

def main():
    print("Starting certificate expiry check...")
    cert_directories = os.listdir("/etc/letsencrypt/live")
    
    port = "22"
    dns_server = "cloudservices01.shared.cits.ru"
    email = "support@cits.ru"

    for directory in cert_directories:
        days_until_expiration = check_certificate_expiry(directory)
        if days_until_expiration is not None and days_until_expiration < 20:
            update_certificate(directory, port, dns_server, email)
    
    print("Certificate expiry check complete.")

if __name__ == "__main__":
    main()
