# 123 OV – journey planner server

Configuration and scripts for the 123 OV journey-planner backend (api.123-ov.nl): the open-source
routing engine [MOTIS](https://github.com/motis-project/motis) with Dutch public-transport data
(OVapi GTFS + GTFS-RT) and OpenStreetMap, behind Caddy (HTTPS).

The server pulls this repository every 2 minutes and applies it (`scripts/sync.sh` → `scripts/apply.sh`).
Timetable data is refreshed every night (`scripts/update-data.sh`). Health: https://api.123-ov.nl/status/status.json

One-time setup on a fresh Debian server (as root):

    curl -fsSL https://raw.githubusercontent.com/yari-immigration/123-ov-server/main/bootstrap.sh | bash

This repository contains no secrets.
