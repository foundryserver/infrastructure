#!/bin/sh
set -e

# If you need to set up a service
if command -v systemctl >/dev/null; then
    systemctl daemon-reload
    systemctl enable fvtt.service || true
    systemctl restart fvtt.service || true
fi

exit 0
