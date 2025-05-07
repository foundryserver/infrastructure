#!/bin/bash
# Version 1.0.0
# Description: This script monitors bandwidth usage on a specific port (30000) and logs the data.
# It checks if the bandwidth is below a certain threshold (3000 bytes) over a 3-hour period and shuts down the system if it is.

# Path to the log file that will store bandwidth data
LOG_FILE="/var/log/bandwidth_log.txt"
# Path to the file that will store the current bandwidth value in JSON format
JSON_FILE="/var/log/current_bandwidth.json"
# Threshold for minimum bandwidth (in bytes) over 3 hours
MIN_BANDWIDTH=3000
# Port to monitor
PORT=30000

# Create the log file if it doesn't exist
if [ ! -f "$LOG_FILE" ]; then
    touch "$LOG_FILE"
fi

# Create the JSON file if it doesn't exist
if [ ! -f "$JSON_FILE" ]; then
    echo '{"bandwidth": 0}' >"$JSON_FILE"
fi

# Function to get current timestamp
get_timestamp() {
    date "+%Y-%m-%d %H:%M:%S"
}

# Set up iptables rules if they don't exist
setup_iptables() {
    # Check if our rules already exist
    if ! iptables -L INPUT -v -n | grep -q "port $PORT"; then
        # Create rules to track incoming traffic on port 30000
        iptables -A INPUT -p tcp --dport $PORT -j ACCEPT
        iptables -A INPUT -p udp --dport $PORT -j ACCEPT
    fi

    if ! iptables -L OUTPUT -v -n | grep -q "port $PORT"; then
        # Create rules to track outgoing traffic on port 30000
        iptables -A OUTPUT -p tcp --sport $PORT -j ACCEPT
        iptables -A OUTPUT -p udp --sport $PORT -j ACCEPT
    fi
}

# Get bandwidth values from iptables
get_bandwidth() {
    # Get incoming bytes (RX)
    rx_bytes=$(iptables -L INPUT -v -n -x | grep "dpt:$PORT" | awk '{sum += $2} END {print sum}')
    rx_bytes=${rx_bytes:-0}

    # Get outgoing bytes (TX)
    tx_bytes=$(iptables -L OUTPUT -v -n -x | grep "spt:$PORT" | awk '{sum += $2} END {print sum}')
    tx_bytes=${tx_bytes:-0}

    # Sum of bytes
    total_bytes=$((rx_bytes + tx_bytes))

    echo $total_bytes
}

# Log bandwidth data
log_bandwidth() {
    timestamp=$(get_timestamp)
    current_bandwidth=$(get_bandwidth)

    # Log with timestamp
    echo "$timestamp,$current_bandwidth" >>"$LOG_FILE"

    # Update JSON file
    echo "{\"bandwidth\": $current_bandwidth}" >"$JSON_FILE"

    echo "Logged bandwidth: $current_bandwidth bytes at $timestamp"
}

# Check if we have enough history in the log file
has_enough_history() {
    # Get the oldest entry timestamp
    oldest_entry=$(head -n 1 "$LOG_FILE" | cut -d',' -f1)

    # If file is empty, we don't have enough history
    if [ -z "$oldest_entry" ]; then
        return 1
    fi

    # Calculate how many hours of history we have
    current_time=$(date +%s)
    oldest_time=$(date -d "$oldest_entry" +%s)
    hours_diff=$((($current_time - $oldest_time) / 3600))

    # Return success if we have at least 3 hours of history
    [ $hours_diff -ge 3 ]
}

# Check if bandwidth is below threshold for the past 3 hours
check_bandwidth_threshold() {
    # First check if we have enough history
    if ! has_enough_history; then
        echo "Not enough history (less than 3 hours of data). Skipping bandwidth check."
        return 0
    fi

    # Calculate the timestamp from 3 hours ago
    three_hours_ago=$(date -d '3 hours ago' "+%Y-%m-%d %H:%M:%S")

    # Sum up bandwidth data from the last 3 hours
    bandwidth_sum=$(awk -v date="$three_hours_ago" '
        BEGIN { FS="," }
        $1 >= date { sum += $2 }
        END { print sum }
    ' "$LOG_FILE")

    bandwidth_sum=${bandwidth_sum:-0}

    echo "Total bandwidth in last 3 hours: $bandwidth_sum bytes"

    # Compare with threshold
    if [ "$bandwidth_sum" -lt "$MIN_BANDWIDTH" ]; then
        echo "Bandwidth of $bandwidth_sum is below threshold ($MIN_BANDWIDTH bytes). Shutting down system."
        rm -f "$LOG_FILE"
        /sbin/poweroff
    fi
}

# Main execution
setup_iptables
log_bandwidth
if [ "$LEVEL" = "1" ]; then
    check_bandwidth_threshold
fi

# Exit with success status
