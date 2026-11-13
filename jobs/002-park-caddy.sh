#!/usr/bin/env bash
# Ports 80/443 belong to existing Docker services on this server: keep Caddy off, touch nothing else.
touch /var/lib/ov/caddy-disabled
systemctl disable --now caddy || true
systemctl reset-failed ov-diag 2>/dev/null || true
