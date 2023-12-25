FROM ubuntu:20.04

# https://docs.nginx.com/nginx-management-suite/nim/how-to/app-protect/setup-waf-config-management/
ARG WAF_COMPILER_VERSION=v4.583.0

# Initial packages setup
RUN apt-get update && \
	DEBIAN_FRONTEND=noninteractive apt-get install -y \
      apt-transport-https ca-certificates build-essential git vim curl jq wget gawk lsb-release rsyslog netcat sudo gnupg2

# Download and add the NGINX signing keys
RUN wget https://cs.nginx.com/static/keys/nginx_signing.key && apt-key add nginx_signing.key \
    && wget https://cs.nginx.com/static/keys/app-protect-security-updates.key && apt-key add app-protect-security-updates.key

# Add NGINX repositories
RUN printf "deb https://pkgs.nginx.com/plus/ubuntu `lsb_release -cs` nginx-plus\n" | tee /etc/apt/sources.list.d/nginx-plus.list \
    && printf "deb https://pkgs.nginx.com/nms/ubuntu `lsb_release -cs` nginx-plus\n" | tee /etc/apt/sources.list.d/nms.list \
    && printf "deb https://pkgs.nginx.com/adm/ubuntu `lsb_release -cs` nginx-plus\n" | tee -a /etc/apt/sources.list.d/nms.list \
    && printf "deb https://pkgs.nginx.com/app-protect/ubuntu `lsb_release -cs` nginx-plus\n" | tee /etc/apt/sources.list.d/nginx-app-protect.list \
    && printf "deb https://pkgs.nginx.com/app-protect-security-updates/ubuntu `lsb_release -cs` nginx-plus\n" | tee /etc/apt/sources.list.d/app-protect-security-updates.list

# Download the apt configuration to `/etc/apt/apt.conf.d`
RUN wget -q -O /etc/apt/apt.conf.d/90pkgs-nginx https://cs.nginx.com/static/files/90pkgs-nginx

COPY ./start.sh /deployment/start.sh
RUN --mount=type=secret,id=nginx-crt,dst=/etc/ssl/nginx/nginx-repo.crt,mode=0644 \
    --mount=type=secret,id=nginx-key,dst=/etc/ssl/nginx/nginx-repo.key,mode=0644 \
	apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y -q \
      nginx-plus nms-instance-manager nms-api-connectivity-manager nms-sm nms-app-delivery-manager nms-nap-compiler-${WAF_COMPILER_VERSION} \
	&& curl -s http://hg.nginx.org/nginx.org/raw-file/tip/xml/en/security_advisories.xml > /usr/share/nms/cve.xml \
	&& wget https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64 -O /usr/bin/yq \
	&& chmod +x /usr/bin/yq /deployment/start.sh /etc/nms/scripts/*.sh

WORKDIR /deployment
STOPSIGNAL SIGTERM
EXPOSE 80 443
CMD /deployment/start.sh
