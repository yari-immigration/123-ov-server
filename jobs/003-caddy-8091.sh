#!/usr/bin/env bash
set -x
rm -f /var/lib/ov/caddy-disabled
systemctl reset-failed ov-diag 2>/dev/null; systemctl stop ov-diag 2>/dev/null
ufw allow 8091/tcp
sed -i -E 's/^([[:space:]]*port:[[:space:]]*)8080[[:space:]]*$/\18090/' /var/lib/ov/data/config.yml 2>/dev/null
caddy validate --config /etc/caddy/Caddyfile --adapter caddyfile
systemctl enable caddy; systemctl restart caddy; sleep 3
systemctl is-active caddy
curl -s -o /dev/null -w 'status page: %{http_code}\n' http://127.0.0.1:8091/status/status.json
true
