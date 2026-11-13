#!/usr/bin/env bash
# Download the latest Dutch timetable (OVapi GTFS) and OpenStreetMap data, import into a
# fresh folder and switch over only when the import succeeded (no downtime on failure).
set -uo pipefail
exec 9>/var/lib/ov/update.lock; flock -n 9 || { echo "update already running"; exit 0; }
B=/var/lib/ov; IN=$B/input; S=$B/status; mkdir -p $IN $S
log(){ echo "$(date -Is) $*" | tee -a $S/update.log; }
new=0
gt=$IN/gtfs-nl.zip
if curl -fsSL --retry 3 -z "$gt" -o "$gt.tmp" https://gtfs.ovapi.nl/nl/gtfs-nl.zip && [ -s "$gt.tmp" ]; then mv "$gt.tmp" "$gt"; new=1; log "new GTFS downloaded ($(du -h $gt | cut -f1))"; else rm -f "$gt.tmp"; fi
osm=$IN/netherlands-latest.osm.pbf
if [ ! -s "$osm" ] || [ -n "$(find $osm -mtime +6)" ]; then
  if curl -fsSL --retry 3 -o "$osm.tmp" https://download.geofabrik.de/europe/netherlands-latest.osm.pbf && [ -s "$osm.tmp" ]; then mv "$osm.tmp" "$osm"; new=1; log "new OSM downloaded ($(du -h $osm | cut -f1))"; else rm -f "$osm.tmp"; log "OSM download failed"; fi
fi
chown -R motis:motis $IN
if [ $new = 0 ] && [ -f $B/data/config.yml ] && [ ! -f $B/need-import ]; then log "no new data"; bash /opt/123-ov-server/scripts/status.sh; exit 0; fi
[ -s "$gt" ] && [ -s "$osm" ] || { log "input missing, abort"; exit 1; }
log "import started"
rm -rf $B/data-new; mkdir -p $B/work; chown motis:motis $B/work
cp $B/config/motis.yml $B/work/config.yml; chown motis:motis $B/work/config.yml
start=$(date +%s)
if (cd $B/work && runuser -u motis -- /opt/motis/motis import -c config.yml -d $B/data-new) >> $S/import.log 2>&1; then
  log "import OK in $(( ($(date +%s)-start)/60 )) min, switching"
  systemctl stop motis
  rm -rf $B/data-old; [ -d $B/data ] && mv $B/data $B/data-old; mv $B/data-new $B/data
  systemctl start motis; sleep 5
  if systemctl is-active -q motis; then rm -rf $B/data-old; rm -f $B/need-import; log "MOTIS running on new data"
  elif [ -d $B/data-old ]; then log "MOTIS failed on new data, rolling back"; systemctl stop motis; rm -rf $B/data; mv $B/data-old $B/data; systemctl start motis
  else log "MOTIS not active yet on first data (kept, see journal)"; fi
else
  log "import FAILED (see import.log)"; rm -rf $B/data-new
fi
tail -n 400 $S/import.log > $S/import.tmp && mv $S/import.tmp $S/import.log
bash /opt/123-ov-server/scripts/status.sh
