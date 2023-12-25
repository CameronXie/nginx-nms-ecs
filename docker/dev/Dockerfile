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
      vim \
      zip \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

RUN pip install cfn-lint==0.83.6
