#!/bin/sh
set -e

# stop fvtt service if running
if command -v systemctl >/dev/null; then
    # Check if the service exists before trying to stop it
    if systemctl list-units --full -all | grep -Fq "fvtt.service"; then
        systemctl stop fvtt.service || true
    fi
fi
# Mark the apt package as un held to allow updates
apt-mark unhold foundry || true

exit 0
