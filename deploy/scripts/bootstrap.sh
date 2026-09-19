#!/bin/bash
set -euxo pipefail

export DEBIAN_FRONTEND=noninteractive

apt-get update
apt-get install -y ca-certificates curl gnupg unattended-upgrades rsync openssl unzip cron

install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
chmod a+r /etc/apt/keyrings/docker.asc

echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "${VERSION_CODENAME}") stable" > /etc/apt/sources.list.d/docker.list

apt-get update
apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin

systemctl enable --now docker

if id ubuntu >/dev/null 2>&1; then
  usermod -aG docker ubuntu
fi

echo unattended-upgrades unattended-upgrades/enable_auto_updates boolean true | debconf-set-selections
dpkg-reconfigure -f noninteractive unattended-upgrades

mkdir -p /opt/financial-control
if id ubuntu >/dev/null 2>&1; then
  chown ubuntu:ubuntu /opt/financial-control
fi

# Ubuntu 24.04 has no awscli apt package. Install AWS CLI v2 from Amazon.
arch="$(dpkg --print-architecture)"
case "${arch}" in
  amd64) awscli_arch="x86_64" ;;
  arm64) awscli_arch="aarch64" ;;
  *) echo "unsupported architecture: ${arch}" >&2; exit 1 ;;
esac

curl -fsSL "https://awscli.amazonaws.com/awscli-exe-linux-${awscli_arch}.zip" -o /tmp/awscliv2.zip
rm -rf /tmp/aws
unzip -q /tmp/awscliv2.zip -d /tmp
/tmp/aws/install --update
rm -rf /tmp/awscliv2.zip /tmp/aws

systemctl enable --now cron

# Cron entries are re-applied on deploy. Install now only if the scripts are already on disk.
if [[ -f /opt/financial-control/deploy/scripts/install-host-cron.sh ]]; then
  bash /opt/financial-control/deploy/scripts/install-host-cron.sh
fi
