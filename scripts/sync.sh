#!/usr/bin/env bash
R=/opt/123-ov-server
before=$(git -C $R rev-parse HEAD)
git -C $R fetch -q origin main && git -C $R reset -q --hard origin/main
after=$(git -C $R rev-parse HEAD)
if [ "$before" != "$after" ] || [ ! -f /var/lib/ov/status/status.json ]; then bash $R/scripts/apply.sh; else bash $R/scripts/status.sh; fi
