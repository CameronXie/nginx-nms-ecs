FROM debian:bullseye-slim

# Initial packages setup
RUN	apt-get update \
	&& DEBIAN_FRONTEND=noninteractive apt-get install -y apt-transport-https lsb-release ca-certificates wget gnupg2 curl debian-archive-keyring iproute2 \
	&& mkdir -p /deployment /etc/ssl/nginx \
	&& addgroup --system --gid 20983 nginx \
	&& adduser --system --disabled-login --ingroup nginx --no-create-home --home /nonexistent --gecos "nginx user" --shell /bin/false --uid 20983 nginx \
    && groupadd -g 1001 nginx-agent \
    && usermod root -G nginx-agent \
    && usermod nginx -G nginx-agent

# Download and add the NGINX signing keys
RUN wget -qO - https://cs.nginx.com/static/keys/nginx_signing.key | gpg --dearmor > /usr/share/keyrings/nginx-archive-keyring.gpg \
    && wget -qO - https://cs.nginx.com/static/keys/app-protect-security-updates.key | gpg --dearmor > /usr/share/keyrings/app-protect-security-updates.gpg

# Add NGINX repositories
RUN printf "deb [signed-by=/usr/share/keyrings/nginx-archive-keyring.gpg] https://pkgs.nginx.com/plus/debian `lsb_release -cs` nginx-plus\n" | tee /etc/apt/sources.list.d/nginx-plus.list \
    && printf "deb [signed-by=/usr/share/keyrings/nginx-archive-keyring.gpg] https://pkgs.nginx.com/nginx-agent/debian `lsb_release -cs` nginx-plus\n" | tee /etc/apt/sources.list.d/nginx-agent.list \
    && printf "deb [signed-by=/usr/share/keyrings/nginx-archive-keyring.gpg] https://pkgs.nginx.com/app-protect/debian `lsb_release -cs` nginx-plus\n" | tee /etc/apt/sources.list.d/nginx-app-protect.list \
    && printf "deb [signed-by=/usr/share/keyrings/app-protect-security-updates.gpg] https://pkgs.nginx.com/app-protect-security-updates/debian `lsb_release -cs` nginx-plus\n" | tee -a /etc/apt/sources.list.d/nginx-app-protect.list

# Download the apt configuration to `/etc/apt/apt.conf.d`
RUN wget -qO /etc/apt/apt.conf.d/90pkgs-nginx https://cs.nginx.com/static/files/90pkgs-nginx

# Install NGINX packages
RUN --mount=type=secret,id=nginx-crt,dst=/etc/ssl/nginx/nginx-repo.crt,mode=0644 \
	--mount=type=secret,id=nginx-key,dst=/etc/ssl/nginx/nginx-repo.key,mode=0644 \
	apt-get -y update \
	&& DEBIAN_FRONTEND="noninteractive" apt-get install -y \
      nginx-plus nginx-agent nginx-plus-module-njs nginx-plus-module-prometheus app-protect app-protect-attack-signatures

# Forward request logs to Docker log collector
RUN ln -sf /dev/stdout /var/log/nginx/access.log \
    && ln -sf /dev/stderr /var/log/nginx/error.log

# Startup script
COPY ./start.sh /deployment/
COPY nginx-agent.conf /etc/nginx-agent/nginx-agent.conf
RUN	chmod +x /deployment/start.sh && touch /.dockerenv

EXPOSE 80 443
STOPSIGNAL SIGTERM
CMD /deployment/start.sh
