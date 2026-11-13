#!/usr/bin/env bash
# Idempotent: bring the server in line with this repository.
set -uo pipefail
R=/opt/123-ov-server; S=/var/lib/ov/status
mkdir -p $S/jobs /var/lib/ov/config
log(){ echo "$(date -Is) $*" | tee -a $S/apply.log; }
changed(){ ! cmp -s "$1" "$2"; }

# MOTIS binary
want=$(cat $R/config/motis-version)
have=$(cat /opt/motis/VERSION 2>/dev/null || true)
if [ "$want" != "$have" ]; then
  log "installing MOTIS $want"
  tmp=$(mktemp -d)
  if curl -fsSL -o $tmp/m.tar.bz2 "https://github.com/motis-project/motis/releases/download/$want/motis-linux-amd64.tar.bz2"; then
    rm -rf /opt/motis.new && mkdir -p /opt/motis.new && tar xjf $tmp/m.tar.bz2 -C /opt/motis.new && echo "$want" > /opt/motis.new/VERSION
    rm -rf /opt/motis.old; [ -d /opt/motis ] && mv /opt/motis /opt/motis.old; mv /opt/motis.new /opt/motis
    systemctl is-active -q motis && systemctl restart motis
  else log "MOTIS download failed"; fi
  rm -rf $tmp
fi

# MOTIS config: a change means a new import
if changed $R/config/motis.yml /var/lib/ov/config/motis.yml; then
  cp $R/config/motis.yml /var/lib/ov/config/motis.yml; chown motis:motis /var/lib/ov/config/motis.yml
  touch /var/lib/ov/need-import; log "motis config changed -> re-import scheduled"
  systemctl start --no-block ov-update.service 2>/dev/null || true
fi

# Caddy (HTTPS + CORS in front of MOTIS)
if changed $R/config/Caddyfile /etc/caddy/Caddyfile; then
  cp $R/config/Caddyfile /etc/caddy/Caddyfile
  if caddy validate --config /etc/caddy/Caddyfile >/dev/null 2>&1; then systemctl reload caddy || systemctl restart caddy; log "caddy reloaded"
  else log "caddy config INVALID: $(caddy validate --config /etc/caddy/Caddyfile 2>&1 | tail -3)"; fi
fi

# keep Caddy running (self-heal)
if [ -f /etc/caddy/Caddyfile ] && [ ! -f /var/lib/ov/caddy-disabled ] && ! systemctl is-active -q caddy && ! ss -ltn | grep -qE ":(80|443)\s"; then systemctl restart caddy 2>/dev/null && log "caddy restarted"; fi

# systemd units
u=0
for f in $R/systemd/*; do
  if changed "$f" "/etc/systemd/system/$(basename $f)"; then cp "$f" /etc/systemd/system/; u=1; fi
done
if [ $u = 1 ]; then systemctl daemon-reload; log "systemd units updated"; fi
systemctl enable -q --now ov-sync.timer ov-update.timer
systemctl enable -q motis
[ -f /var/lib/ov/data/config.yml ] && ! systemctl is-active -q motis && systemctl start motis

# firewall (SSH stays open)
if ! ufw status | grep -q "Status: active"; then
  ufw allow OpenSSH >/dev/null; ufw allow 22/tcp >/dev/null; ufw allow 80/tcp >/dev/null; ufw allow 443/tcp >/dev/null
  ufw --force enable >/dev/null && log "firewall enabled (22, 80, 443)"
fi

# one-time jobs: jobs/NNN-name.sh run once, output published in status/jobs/
for j in $R/jobs/*.sh; do
  [ -e "$j" ] || continue
  n=$(basename $j .sh)
  [ -f $S/jobs/$n.done ] && continue
  log "running job $n"
  bash "$j" > $S/jobs/$n.log 2>&1; echo $? > $S/jobs/$n.done
done

bash $R/scripts/status.sh
