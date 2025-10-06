#!/bin/sh
set -e

# If you need to set up a service
if command -v systemctl >/dev/null; then
    systemctl daemon-reload
    systemctl enable fvtt.service || true
    systemctl restart fvtt.service || true
fi

# Mark the apt package as held to prevent automatic updates
# Wait a moment for the package to be fully registered
sleep 2
if dpkg -l | grep -q "foundry"; then
    apt-mark hold foundry || true
fi

exit 0
