#!/bin/bash

# This script will be used to determine how long the VM has been run in the current calendar month
# Level 0 customers only have a 15 hour per month limit.  We are going to use journalctl --list-boots
# to determine how many hours the VM has been running in the current month.  The sample output of this command is:
#
#  IDX BOOT ID                          FIRST ENTRY                 LAST ENTRY
#  0 0f81bfd1429741b6a7df541ce8c73b3d Fri 2025-10-03 17:22:44 PDT Fri 2025-10-03 18:49:03 PDT

# If a total of 15 hours or more is detected, the script will issue a webhook to the vmapi server.
# This script will run as a cron job at the top of every hour.


# get level from the environment file only run if level is 0
source /etc/environment
if [ "$LEVEL" != "0" ]; then
  exit 0
fi

# Create an ipcToken for the webhook
USERNAME=$(hostname)
HASH=$(echo -n "$USERNAME" | openssl dgst -sha256 | awk '{print $2}')


# Get the current month and year
current_month=$(date +%m)
current_year=$(date +%Y)

# Get the list of boots for the current month
boots=$(journalctl --list-boots --no-pager | grep "$current_year-$current_month")

# Calculate the total uptime in hours
total_uptime=0
while read -r line; do
  # Extract the boot time and calculate the duration
  boot_time=$(echo "$line" | awk '{print $3, $4}')
  last_entry=$(echo "$line" | awk '{print $5, $6}')
  duration=$(( $(date -d "$last_entry" +%s) - $(date -d "$boot_time" +%s) ))
  total_uptime=$((total_uptime + duration))
done <<< "$boots"

# Convert total uptime to hours
total_uptime_hours=$((total_uptime / 3600))

# Check if the total uptime exceeds the limit
if [ "$total_uptime_hours" -ge 15 ]; then
  # Determine the port based on NODE_ENV
  if [ "$NODE_ENV" = "dev" ]; then
    port=7070
  else
    port=8080
  fi

  # Issue webhooks to both vmapi servers to make sure that if one is down the other will get it
# Call webhook and capture status code and response body
    RESPONSE=$(curl -s -w "%{http_code}" -X POST http://vmapi0.vm.local:$port/webhookUptime \
        -H "Authorization: Bearer $HASH" \
        -d "exceed=true&username=$USERNAME" \
        --connect-timeout 2)

    HTTP_STATUS=$(echo "$RESPONSE" | tail -n1)
    if [ "$HTTP_STATUS" -eq 200 ]; then
      echo "Webhook sent successfully to vmapi0"
    else
      echo "Failed to send webhook to vmapi0"
    fi

    RESPONSE=$(curl -s -w "%{http_code}" -X POST http://vmapi1.vm.local:$port/webhookUptime \
        -H "Authorization: Bearer $HASH" \
        -d "exceed=true&username=$USERNAME" \
        --connect-timeout 2)

    HTTP_STATUS=$(echo "$RESPONSE" | tail -n1)
    if [ "$HTTP_STATUS" -eq 200 ]; then
      echo "Webhook sent successfully to vmapi1"
    else
      echo "Failed to send webhook to vmapi1"
    fi
fi