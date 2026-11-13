#!/usr/bin/env bash
# One-time setup of the 123 OV journey-planner server (Debian 12/13, run as root):
#   curl -fsSL https://raw.githubusercontent.com/yari-immigration/123-ov-server/main/bootstrap.sh | bash
set -euo pipefail
[ "$(id -u)" = 0 ] || { echo "Run as root"; exit 1; }
export DEBIAN_FRONTEND=noninteractive
echo "== 123 OV: installing packages"
apt-get update -y
apt-get install -y curl ca-certificates git bzip2 jq ufw caddy util-linux
echo "== 123 OV: swap (8 GB) for the data import"
if ! swapon --show | grep -q .; then
  fallocate -l 8G /swapfile && chmod 600 /swapfile && mkswap /swapfile && swapon /swapfile
  grep -q '^/swapfile' /etc/fstab || echo '/swapfile none swap sw 0 0' >> /etc/fstab
fi
id motis >/dev/null 2>&1 || useradd --system --home /var/lib/ov --shell /usr/sbin/nologin motis
mkdir -p /var/lib/ov/{input,status/jobs,config} && chown -R motis:motis /var/lib/ov
if [ -d /opt/123-ov-server/.git ]; then git -C /opt/123-ov-server pull --ff-only; else git clone https://github.com/yari-immigration/123-ov-server /opt/123-ov-server; fi
bash /opt/123-ov-server/scripts/apply.sh
echo "== 123 OV: first data download and import started in the background (takes 20-60 min)."
systemctl start --no-block ov-update.service
echo "== 123 OV: done. Status: https://api.123-ov.nl/status/status.json"
