#!/usr/bin/env bash
# Get Caddy running; publish diagnostics either way.
set -x
S=/var/lib/ov/status
# 1) caddy user + its data dirs (package postinst may have failed: "Could not execute systemctl")
getent group caddy >/dev/null || groupadd --system caddy
id caddy >/dev/null 2>&1 || useradd --system --gid caddy --create-home --home-dir /var/lib/caddy --shell /usr/sbin/nologin caddy
mkdir -p /var/lib/caddy /etc/caddy /var/log/caddy
chown -R caddy:caddy /var/lib/caddy /var/log/caddy
chmod 755 /etc/caddy; chmod 644 /etc/caddy/Caddyfile
# 2) free ports 80/443 from any other web server
ss -ltnp | grep -E ':(80|443)\s' || true
for s in apache2 nginx lighttpd httpd; do systemctl disable --now $s 2>/dev/null || true; done
# 3) start
caddy validate --config /etc/caddy/Caddyfile --adapter caddyfile
systemctl daemon-reload
systemctl enable caddy
systemctl restart caddy
sleep 8
systemctl is-active caddy
journalctl -u caddy -n 60 --no-pager -o cat
ss -ltnp | grep -E ':(80|443)\s' || true
cp -f $S/jobs/001-fix-caddy.log $S/caddy-diag.txt 2>/dev/null || true
# 4) if Caddy is still down, serve the status folder on port 80 so the logs can be read remotely
if ! systemctl is-active -q caddy && command -v python3 >/dev/null; then
  systemd-run --unit=ov-diag --property=RuntimeMaxSec=7200 python3 -m http.server 80 --directory $S
fi
true
