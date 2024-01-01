FROM cameronx/aws-deployer:latest

RUN set -eux \
    && apt-get update && apt-get install -y --no-install-recommends \
      apt-transport-https \
      ca-certificates \
      curl \
      gnupg \
      jq \
      less \
      tree \
      lsb-release \
      make \
      nginx \
      vim \
      zip \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /tmp/build
RUN curl "https://s3.amazonaws.com/session-manager-downloads/plugin/latest/ubuntu_64bit/session-manager-plugin.deb" -o "session-manager-plugin.deb" \
    && dpkg -i session-manager-plugin.deb

RUN pip install cfn-lint==0.83.6
