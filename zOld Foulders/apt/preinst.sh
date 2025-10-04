#!/bin/sh
set -e

# stop fvtt service if running
if command -v systemctl >/dev/null; then
    systemctl stop fvtt.service || true
fi
# Mark the apt package as un held to allow updates
apt-mark unhold foundry

exit 0
