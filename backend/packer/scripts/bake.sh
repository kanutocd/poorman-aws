#!/usr/bin/env bash
set -euo pipefail

sudo dnf upgrade -y
sudo dnf install -y \
  awscli-2 \
  docker \
  jq \
  xfsprogs \
  zstd

sudo install -d -m 0755 /usr/local/lib/docker/cli-plugins
compose_arch="aarch64"
sudo curl -fsSL \
  "https://github.com/docker/compose/releases/download/${COMPOSE_VERSION}/docker-compose-linux-${compose_arch}" \
  -o /usr/local/lib/docker/cli-plugins/docker-compose
sudo chmod 0755 /usr/local/lib/docker/cli-plugins/docker-compose

if ! id "$APPLICATION_NAME" >/dev/null 2>&1; then
  sudo useradd --create-home --shell /bin/bash "$APPLICATION_NAME"
fi
sudo usermod -aG docker "$APPLICATION_NAME"
sudo systemctl enable docker

if ! command -v amazon-ssm-agent >/dev/null 2>&1; then
  echo "amazon-ssm-agent must be present in the source AMI" >&2
  exit 1
fi
sudo systemctl enable amazon-ssm-agent

sudo install -d -m 0750 -o root -g root "/srv/$APPLICATION_NAME/releases" "/etc/$APPLICATION_NAME"
sudo dnf clean all
sudo rm -rf /var/cache/dnf /tmp/*

sudo docker --version
sudo docker compose version
aws --version
jq --version
zstd --version

if ! sudo cloud-init clean --logs; then
  sudo rm -rf /var/lib/cloud/instance /var/lib/cloud/instances/*
fi
sudo truncate -s 0 /etc/machine-id
sudo rm -f /var/lib/dbus/machine-id
sudo rm -rf /root/.ssh /home/ec2-user/.ssh

if [ -e /root/.ssh ] || [ -e /home/ec2-user/.ssh ]; then
  echo "AMI must not contain root or ec2-user SSH state" >&2
  exit 1
fi

sudo systemctl mask sshd.service
