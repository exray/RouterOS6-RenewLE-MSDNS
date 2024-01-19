import os
import subprocess
from datetime import datetime
from dateutil.parser import parse
from dateutil.tz import tzutc
import argparse
import json

def main():
    parser = argparse.ArgumentParser(description="Проверяет срок действия ранее выданных через certbot сертификатов")
    parser.add_argument(
        "argument",
        nargs="?",
        help="Без указания аргументов на выводе будет полная информация по всем сертификатам.\n"
             "В качестве аргумента можно использовать FQDN-имя домена. Выводом будет оставшееся количество дней.\n"
             "Так же в качестве аргумента можно использовать list-domains-only для вывода только списка доменов."
    )
    args = parser.parse_args()
    
    cert_directories = os.listdir("/etc/letsencrypt/live")

    if args.argument == "list-domains-for-zabbix":
        result = {"data": []}
    
    for directory in cert_directories:
        cert_path = os.path.join("/etc/letsencrypt/live", directory, "cert.pem")
        
        if os.path.exists(cert_path):
            openssl_command = f"openssl x509 -enddate -noout -in {cert_path}"
            end_date_output = subprocess.getoutput(openssl_command)
            end_date_str = end_date_output.split("=")[1].strip()
            end_date = parse(end_date_str)
            days_until_expiration = (end_date - datetime.now(tzutc())).days
            
            expiration_status = f"Осталось {days_until_expiration} дней. Закончится {end_date.strftime('%d.%m.%Y')}"
            
            if args.argument is None:
                print(f"{directory} - {expiration_status}")
            elif args.argument == "list-domains-only":
                print(f"{directory}")
            elif args.argument == "list-domains-for-zabbix":
                result["data"].append({"{#DOMAIN}": directory})
            elif args.argument in directory:
                print(days_until_expiration)
    
    if args.argument == "list-domains-for-zabbix":
        print(json.dumps(result, ensure_ascii=False, indent=2))

if __name__ == "__main__":
    main()
