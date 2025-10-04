#!/bin/bash

# This script sets up the cron jobs for bandwidth monitoring and monthly counter resets

# Define the correct paths to the scripts
BANDWIDTH_SCRIPT="/home/admin/bandwidth.sh"
RESET_SCRIPT="/home/admin/reset_iptables.sh"
UPTIME_SCRIPT="/home/admin/uptime.sh"

# Make sure the scripts are executable
chmod +x "${BANDWIDTH_SCRIPT}"
chmod +x "${RESET_SCRIPT}"
chmod +x "${UPTIME_SCRIPT}"

# Create a temporary file for the new crontab
TEMP_CRON=$(mktemp)

# Export existing crontab
crontab -l > "$TEMP_CRON" 2>/dev/null

# Check if bandwidth.sh entry already exists
if ! grep -q "bandwidth.sh" "$TEMP_CRON"; then
    echo "# Run bandwidth monitoring every 10 minutes" >> "$TEMP_CRON"
    echo "*/10 * * * * ${BANDWIDTH_SCRIPT} >> /var/log/bandwidth_execution.log 2>&1" >> "$TEMP_CRON"
    echo "Entry for bandwidth.sh added to crontab"
else
    echo "Entry for bandwidth.sh already exists in crontab"
fi

# Check if reset_iptables.sh entry already exists
if ! grep -q "reset_iptables.sh" "$TEMP_CRON"; then
    echo "# Reset iptables counters on the 1st of each month at 00:01" >> "$TEMP_CRON"
    echo "1 0 1 * * ${RESET_SCRIPT} >> /var/log/bandwidth_reset.log 2>&1" >> "$TEMP_CRON"
    echo "Entry for reset_iptables.sh added to crontab"
else
    echo "Entry for reset_iptables.sh already exists in crontab"
fi

# Check if uptime.sh entry already exists
if ! grep -q "uptime.sh" "$TEMP_CRON"; then
    echo "# Check VM uptime every hour" >> "$TEMP_CRON"
    echo "0 * * * * ${UPTIME_SCRIPT} >> /var/log/uptime_execution.log 2>&1" >> "$TEMP_CRON"
    echo "Entry for uptime.sh added to crontab"
else
    echo "Entry for uptime.sh already exists in crontab"
fi

# Install the updated crontab
crontab "$TEMP_CRON"
rm "$TEMP_CRON"

echo "Cron jobs have been set up successfully."

# Show the current crontab for verification
echo "Current crontab entries:"
crontab -l

exit 0