#!/usr/bin/env bash
# Publishes a small health report at https://api.123-ov.nl/status/status.json
S=/var/lib/ov/status; mkdir -p $S
health=$(curl -s -m 5 -o /dev/null -w '%{http_code}' http://127.0.0.1:8080/api/v1/health || echo 000)
jq -n \
  --arg time "$(date -Is)" \
  --arg commit "$(git -C /opt/123-ov-server rev-parse --short HEAD 2>/dev/null)" \
  --arg motis "$(systemctl is-active motis)" --arg motis_version "$(cat /opt/motis/VERSION 2>/dev/null)" \
  --arg health "$health" --arg caddy "$(systemctl is-active caddy)" \
  --arg update_running "$(systemctl is-active ov-update.service)" \
  --arg data "$(stat -c %y /var/lib/ov/data/config.yml 2>/dev/null)" \
  --arg gtfs "$(stat -c %y /var/lib/ov/input/gtfs-nl.zip 2>/dev/null)" \
  --arg osm "$(stat -c %y /var/lib/ov/input/netherlands-latest.osm.pbf 2>/dev/null)" \
  --arg mem "$(free -m | awk '/Mem:/{print $3"/"$2" MB"}')" --arg swap "$(free -m | awk '/Swap:/{print $3"/"$2" MB"}')" \
  --arg disk "$(df -h /var/lib/ov | awk 'NR==2{print $3"/"$2}')" \
  --arg update_log "$(tail -n 15 $S/update.log 2>/dev/null)" \
  --arg apply_log "$(tail -n 10 $S/apply.log 2>/dev/null)" \
  --arg import_log "$(tail -n 25 $S/import.log 2>/dev/null)" \
  --arg motis_log "$(journalctl -u motis -n 15 --no-pager -o cat 2>/dev/null)" \
  '{time:$time,commit:$commit,motis:$motis,motis_version:$motis_version,health_http:$health,caddy:$caddy,update_running:$update_running,data_built:$data,gtfs_file:$gtfs,osm_file:$osm,memory:$mem,swap:$swap,disk:$disk,update_log:$update_log,apply_log:$apply_log,import_log:$import_log,motis_log:$motis_log}' > $S/status.json.tmp && mv $S/status.json.tmp $S/status.json
chmod -R a+rX $S
