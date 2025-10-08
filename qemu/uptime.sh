#!/bin/bash

# VM Uptime Monitor Script
# Description: Monitors VM uptime for Level 0 customers (15 hour monthly limit)
# Uses journalctl --list-boots to determine runtime in current calendar month
# Sample output:
# IDX BOOT ID                          FIRST ENTRY                 LAST ENTRY
# -36 63a0743c8ac341ce932b84c26bcf2a52 Thu 2024-10-17 07:42:56 PDT Thu 2024-10-17 07:44:22 PDT
# -35 7e9becbc7047439d89a9fadb82e4a590 Thu 2024-10-17 07:44:30 PDT Thu 2024-10-17 07:54:40 PDT
# -34 401e00d9bec04e2eb6fa8f775adf9a42 Thu 2024-10-17 07:54:48 PDT Sun 2024-10-27 07:55:06 PDT
# -33 f4863355e0c44ceea9f8849e51a25fb7 Sun 2024-10-27 07:55:27 PDT Tue 2024-12-17 15:45:01 PST
#
# If 15+ hours detected, sends webhook to vmapi server
# Runs as cron job at the top of every hour

set -e

# Only run for Level 0 customers
source /etc/environment
if [ "$LEVEL" != "0" ]; then
    echo "Not a Level 0 customer (LEVEL=$LEVEL), exiting"
    exit 0
fi

# Create authentication token for webhook
USERNAME=$(hostname)
HASH=$(echo -n "$USERNAME" | openssl dgst -sha256 | awk '{print $2}')

# Get current month and year
current_month=$(date +%Y-%m)
current_year=$(date +%Y)

echo "Checking uptime for $current_month for hostname: $USERNAME"

# Get boot records for current month
boots=$(journalctl --list-boots --no-pager | grep "$current_month")

# Calculate total uptime in seconds
total_uptime=0
boot_count=0

if [ -n "$boots" ]; then
    while read -r line; do
        if [ -n "$line" ]; then
            # Extract boot time and last entry time
            # Format: IDX BOOT_ID DAY DATE TIME TZ DAY DATE TIME TZ
            boot_time=$(echo "$line" | awk '{print $4, $5}')
            last_entry=$(echo "$line" | awk '{print $8, $9}')
            
            # Get the boot index to check if this is current boot (index 0)
            boot_idx=$(echo "$line" | awk '{print $1}')
            
            # Calculate duration for this boot session
            boot_start=$(date -d "$boot_time" +%s 2>/dev/null)
            
            # Skip this entry if we can't parse the boot time
            if [ $? -ne 0 ]; then
                echo "  Warning: Could not parse boot time '$boot_time', skipping"
                continue
            fi
            
            # If this is the current boot (index 0), use current time instead of last entry
            if [ "$boot_idx" = "0" ]; then
                boot_end=$(date +%s)
                echo "Boot $boot_count (CURRENT): $boot_time to $(date) (ongoing)"
            else
                boot_end=$(date -d "$last_entry" +%s 2>/dev/null)
                if [ $? -ne 0 ]; then
                    echo "  Warning: Could not parse last entry time '$last_entry', skipping"
                    continue
                fi
                echo "Boot $boot_count: $boot_time to $last_entry"
            fi
            
            duration=$((boot_end - boot_start))
            total_uptime=$((total_uptime + duration))
            boot_count=$((boot_count + 1))
            
            echo "  Duration: $(($duration / 3600))h $(($duration % 3600 / 60))m"
        fi
    done <<< "$boots"
else
    echo "No boot records found for current month"
fi

# Convert total uptime to hours
total_uptime_hours=$((total_uptime / 3600))
total_uptime_minutes=$(((total_uptime % 3600) / 60))

echo "Total uptime this month: ${total_uptime_hours}h ${total_uptime_minutes}m"

# Check if uptime exceeds 15-hour monthly limit
if [ "$total_uptime_hours" -ge 15 ]; then
    echo "WARNING: Monthly uptime limit exceeded ($total_uptime_hours hours >= 15 hours)"
    
    # Determine API port based on environment
    if [ "$NODE_ENV" = "dev" ]; then
        PORT=7070
        echo "Using development environment (port $PORT)"
    else
        PORT=8080
        echo "Using production environment (port $PORT)"
    fi
    
    # Webhook URLs for both vmapi servers
    URL0="http://vmapi0.vm.local:$PORT/vm/webhook-uptime"
    URL1="http://vmapi1.vm.local:$PORT/vm/webhook-uptime"
    
    # Function to send webhook
    send_webhook() {
        local url=$1
        local server_name=$2
        
        echo "Sending webhook to $server_name..."
        
        RESPONSE=$(curl -s -w "%{http_code}" -X GET "${url}?username=${USERNAME}" \
            -H "Authorization: Bearer $HASH" \
            --connect-timeout 5 \
            --max-time 10 2>/dev/null)
        
        HTTP_STATUS=$(echo "$RESPONSE" | tail -n1)
        
        if [ "$HTTP_STATUS" -eq 200 ]; then
            echo "✓ Webhook sent successfully to $server_name"
            return 0
        else
            echo "✗ Failed to send webhook to $server_name (HTTP $HTTP_STATUS)"
            return 1
        fi
    }
    
    # Send webhooks to both servers for redundancy
    send_webhook "$URL0" "vmapi0"
    send_webhook "$URL1" "vmapi1"
    
else
    echo "Uptime within limits ($total_uptime_hours hours < 15 hours)"
fi

echo "Uptime check completed"