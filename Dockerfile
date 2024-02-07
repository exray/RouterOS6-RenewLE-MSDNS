FROM mcr.microsoft.com/powershell:centos-8

RUN cd /etc/yum.repos.d/
RUN sed -i 's/mirrorlist/#mirrorlist/g' /etc/yum.repos.d/CentOS-*
RUN sed -i 's|#baseurl=http://mirror.centos.org|baseurl=http://vault.centos.org|g' /etc/yum.repos.d/CentOS-*

# Update the list of packages and install some packages
RUN yum install -y python3 \
    python3-certbot \
    certbot \
    compat-openssl10 \
    libicu \
    git \
    gssntlmssp \
    docker-ce \
    docker-compose \

# Install PSWSMan module
RUN pwsh -c "Install-Module -Name PSWSMan -Scope AllUsers -Force; Install-WSMan"

# Clone letsencrypt-routeros repository
RUN git clone https://github.com/danb35/letsencrypt-routeros.git /opt/letsencrypt-routeros
RUN git clone https://github.com/exray/RouterOS6-RenewLE-MSDNS.git /opt/RouterOS6-RenewLE-MSDNS

COPY Scheduler.ps1 /opt/RouterOS6-RenewLE-MSDNS

CMD ["pwsh", "/opt/RouterOS6-RenewLE-MSDNS/Scheduler.ps1"]