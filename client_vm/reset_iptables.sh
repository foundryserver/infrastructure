#!/bin/bash

# Script to reset iptables byte counters but retain rules
# This will be run once per month via cron

# Port to monitor - should match the one in bandwidth.sh
PORT=30000

# Log file
LOG_FILE="/var/log/bandwidth_reset.log"

# Function to get current timestamp
get_timestamp() {
    date "+%Y-%m-%d %H:%M:%S"
}

# Record timestamp of reset
echo "$(get_timestamp) - Resetting iptables counters for port $PORT" >> "$LOG_FILE"

# Reset counters by using iptables-save/restore which preserves rules but resets counters
iptables-save > /tmp/iptables.rules
iptables-restore < /tmp/iptables.rules
rm -f /tmp/iptables.rules

echo "$(get_timestamp) - iptables counters reset successfully" >> "$LOG_FILE"

# Exit with success status
exit 0