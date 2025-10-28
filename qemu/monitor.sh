#!/bin/bash
# Version 2.0.3
# Description: Combined monitoring script for VM resource usage
# - Monitors bandwidth usage on port 30000 (levels 0 and 1)
# - Monitors uptime limits for Level 0 customers (15-hour monthly limit)
# - Checks bandwidth threshold for Level 0 & 1 customers (3000 bytes over 3 hours)

set -euo pipefail  # Exit on error, undefined variables, and pipe failures
source /etc/environment # Load environment variables

# ============================================================================
# DEPENDENCY CHECKS
# ============================================================================

# Function to check for required system commands and utilities
check_dependencies() {
    local missing_deps=()
    local required_commands=(
        "iptables"
        "date" 
        "curl"
        "openssl"
        "journalctl"
        "wc"
        "tail"
        "head"
        "awk"
        "grep"
        "hostname"
        "poweroff"
    )
    
    echo "Checking system dependencies..."
    
    for cmd in "${required_commands[@]}"; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            missing_deps+=("$cmd")
            echo "✗ Missing: $cmd"
        else
            echo "✓ Found: $cmd"
        fi
    done
    
    # Check for systemd (journalctl functionality)
    if ! systemctl --version >/dev/null 2>&1; then
        missing_deps+=("systemd")
        echo "✗ Missing: systemd (required for journalctl functionality)"
    else
        echo "✓ Found: systemd"
    fi
    
    # Check for root privileges
    if [ "$EUID" -ne 0 ]; then
        missing_deps+=("root privileges")
        echo "✗ Missing: root privileges (script must be run as root)"
    else
        echo "✓ Found: root privileges"
    fi
    
    # Check write access to /var/log/
    if [ ! -w "/var/log" ]; then
        missing_deps+=("write access to /var/log")
        echo "✗ Missing: write access to /var/log directory"
    else
        echo "✓ Found: write access to /var/log"
    fi
    
    # Report results
    if [ ${#missing_deps[@]} -eq 0 ]; then
        echo "✓ All dependencies satisfied"
        return 0
    else
        echo ""
        echo "ERROR: Missing required dependencies:"
        for dep in "${missing_deps[@]}"; do
            echo "  - $dep"
        done
        echo ""
        echo "Please install missing dependencies and ensure script is run with proper privileges."
        exit 1
    fi
}

# ============================================================================
# CONFIGURATION
# ============================================================================

# Check if LEVEL environment variable is set to 0 or 1
if [ -z "${LEVEL:-}" ]; then
    echo "LEVEL environment variable is not set. Exiting."
    exit 0
fi

if [ "$LEVEL" != "0" ] && [ "$LEVEL" != "1" ]; then
    echo "LEVEL must be 0 or 1. Current value: $LEVEL. Exiting."
    exit 0
fi

# Bandwidth monitoring configuration
BANDWIDTH_LOG="/var/log/bandwidth_log.txt"
BANDWIDTH_JSON="/var/log/current_bandwidth.json"
COUNTER_FILE="/var/log/bandwidth_counter.txt"
MIN_BANDWIDTH=3000  # Minimum bytes over 3 hours
PORT=30000          # Port to monitor
MAX_LOG_ENTRIES=1000  # Log rotation limit

# Uptime monitoring configuration (Level 0 only)
UPTIME_LOG="/var/log/uptime_monitor.log"
UPTIME_LIMIT_HOURS=15  # Monthly uptime limit in hours

# ============================================================================
# BANDWIDTH MONITORING FUNCTIONS
# ============================================================================

# Function to get current timestamp
get_timestamp() {
    date "+%Y-%m-%d %H:%M:%S"
}

# Create required files if they don't exist
init_bandwidth_files() {
    if [ ! -f "$BANDWIDTH_LOG" ]; then
        touch "$BANDWIDTH_LOG" || { echo "Error: Cannot create bandwidth log file"; exit 1; }
    fi

    if [ ! -f "$BANDWIDTH_JSON" ]; then
        echo '{"bandwidth": 0}' >"$BANDWIDTH_JSON" || { echo "Error: Cannot create JSON file"; exit 1; }
    fi

    if [ ! -f "$COUNTER_FILE" ]; then
        echo "0" >"$COUNTER_FILE" || { echo "Error: Cannot create counter file"; exit 1; }
    fi
}

# Set up iptables rules if they don't exist
setup_iptables() {
    # Check if we have necessary permissions
    if ! iptables -L -n >/dev/null 2>&1; then
        echo "Error: Unable to access iptables. Check permissions." >&2
        exit 1
    fi

    # Check if INPUT rules already exist
    if ! iptables -L INPUT -v -n | grep -q "dpt:$PORT"; then
        # Create rules to track incoming TCP traffic on port 30000
        iptables -A INPUT -p tcp --dport "$PORT" -j ACCEPT || { echo "Error: Failed to add INPUT TCP rule"; exit 1; }
    fi

    # Check if OUTPUT rules already exist
    if ! iptables -L OUTPUT -v -n | grep -q "spt:$PORT"; then
        # Create rules to track outgoing TCP traffic on port 30000
        iptables -A OUTPUT -p tcp --sport "$PORT" -j ACCEPT || { echo "Error: Failed to add OUTPUT TCP rule"; exit 1; }
    fi
}

# Get bandwidth values from iptables (calculates delta from previous reading)
get_bandwidth() {
    # Get incoming bytes (RX) - TCP only
    rx_bytes=$(iptables -L INPUT -v -n -x | grep -E "tcp.*dpt:$PORT" | awk '{sum += $2} END {print (sum == "" ? 0 : sum)}')
    
    # Get outgoing bytes (TX) - TCP only
    tx_bytes=$(iptables -L OUTPUT -v -n -x | grep -E "tcp.*spt:$PORT" | awk '{sum += $2} END {print (sum == "" ? 0 : sum)}')
    
    # Sum of bytes (current cumulative total)
    current_total=$((rx_bytes + tx_bytes))
    
    # Read previous total from counter file
    previous_total=$(cat "$COUNTER_FILE" 2>/dev/null || echo "0")
    
    # Calculate delta (bytes transferred since last check)
    # Handle counter reset (if current < previous, assume reset and use current value)
    if [ "$current_total" -lt "$previous_total" ]; then
        delta=$current_total
    else
        delta=$((current_total - previous_total))
    fi
    
    # Save current total for next iteration
    echo "$current_total" >"$COUNTER_FILE"
    
    echo "$delta"
}

# Rotate log file to prevent unbounded growth
rotate_log_file() {
    local line_count
    line_count=$(wc -l < "$BANDWIDTH_LOG")
    
    if [ "$line_count" -gt "$MAX_LOG_ENTRIES" ]; then
        # Keep only the most recent MAX_LOG_ENTRIES entries
        tail -n "$MAX_LOG_ENTRIES" "$BANDWIDTH_LOG" > "${BANDWIDTH_LOG}.tmp" && mv "${BANDWIDTH_LOG}.tmp" "$BANDWIDTH_LOG"
        echo "Log file rotated, kept last $MAX_LOG_ENTRIES entries"
    fi
}

# Log bandwidth data
log_bandwidth() {
    local timestamp
    local current_bandwidth
    
    timestamp=$(get_timestamp)
    current_bandwidth=$(get_bandwidth)

    # Log with timestamp
    echo "$timestamp,$current_bandwidth" >>"$BANDWIDTH_LOG"

    # Update JSON file
    printf '{"bandwidth": %d, "timestamp": "%s"}\n' "$current_bandwidth" "$timestamp" >"$BANDWIDTH_JSON"

    echo "Logged bandwidth: $current_bandwidth bytes at $timestamp"
    
    # Rotate log file if it exceeds MAX_LOG_ENTRIES
    rotate_log_file
}

# Check if we have enough history in the log file
has_enough_history() {
    local oldest_entry
    local current_time
    local oldest_time
    local hours_diff
    
    # Get the oldest entry timestamp
    oldest_entry=$(head -n 1 "$BANDWIDTH_LOG" 2>/dev/null | cut -d',' -f1)

    # If file is empty, we don't have enough history
    if [ -z "$oldest_entry" ]; then
        return 1
    fi

    # Calculate how many hours of history we have
    current_time=$(date +%s)
    oldest_time=$(date -d "$oldest_entry" +%s 2>/dev/null || echo "$current_time")
    hours_diff=$(( (current_time - oldest_time) / 3600 ))

    # Return success if we have at least 3 hours of history
    [ "$hours_diff" -ge 3 ]
}

# Check if bandwidth is below threshold for the past 3 hours
check_bandwidth_threshold() {
    local three_hours_ago_timestamp
    local bandwidth_sum
    
    # First check if we have enough history
    if ! has_enough_history; then
        echo "Not enough history (less than 3 hours of data). Skipping bandwidth check."
        return 0
    fi

    # Calculate the timestamp from 3 hours ago (use seconds for reliable comparison)
    three_hours_ago_timestamp=$(date -d '3 hours ago' +%s)

    # Sum up bandwidth data from the last 3 hours using numeric timestamp comparison
    bandwidth_sum=$(awk -v cutoff="$three_hours_ago_timestamp" '
        BEGIN { FS=","; sum=0 }
        {
            # Parse the timestamp and convert to epoch seconds
            cmd = "date -d \"" $1 "\" +%s 2>/dev/null"
            cmd | getline ts
            close(cmd)
            
            # If timestamp is within the 3-hour window, add bandwidth
            if (ts >= cutoff) {
                sum += $2
            }
        }
        END { print (sum == "" ? 0 : sum) }
    ' "$BANDWIDTH_LOG")

    bandwidth_sum=${bandwidth_sum:-0}

    echo "Total bandwidth in last 3 hours: $bandwidth_sum bytes (threshold: $MIN_BANDWIDTH bytes)"

    # Compare with threshold
    if [ "$bandwidth_sum" -lt "$MIN_BANDWIDTH" ]; then
        echo "WARNING: Bandwidth of $bandwidth_sum bytes is below threshold ($MIN_BANDWIDTH bytes)."
        echo "Shutting down system in 10 seconds. Press Ctrl+C to cancel."
        sleep 10
        
        # Log the shutdown event before removing the log
        echo "$(get_timestamp),SHUTDOWN - Bandwidth threshold not met" >>"${BANDWIDTH_LOG}.shutdown"
        
        # Clean up and shutdown
        rm -f "$BANDWIDTH_LOG"
        /sbin/poweroff
    else
        echo "Bandwidth check passed: $bandwidth_sum >= $MIN_BANDWIDTH bytes"
    fi
}

# ============================================================================
# UPTIME MONITORING FUNCTIONS (LEVEL 0 ONLY)
# ============================================================================

# Send webhook to vmapi servers
send_webhook() {
    local url=$1
    local server_name=$2
    local username=$3
    
    echo "Sending webhook to $server_name..."
    
    RESPONSE=$(curl -s -w "%{http_code}" -X GET "${url}?username=${username}" \
        -H "Authorization: Bearer webhookUptime" \
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

# Check uptime for Level 0 customers
check_uptime_limit() {
    echo "================================================"
    echo "Checking uptime limit for Level 0 customer"
    echo "================================================"
    
    # Create authentication token for webhook
    USERNAME=$(hostname)
    
    # Get current month and year
    current_month=$(date +%Y-%m)
    
    echo "Checking uptime for $current_month for hostname: $USERNAME"
    
    # Get boot records for current month
    boots=$(journalctl --list-boots --no-pager | grep "$current_month" || true)
    
    # Calculate total uptime in seconds
    total_uptime=0
    boot_count=0
    
    if [ -n "$boots" ]; then
        while read -r line; do
            if [ -n "$line" ]; then
                # Extract boot time and last entry time
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
    
    # Check if uptime exceeds limit
    if [ "$total_uptime_hours" -ge "$UPTIME_LIMIT_HOURS" ]; then
        echo "WARNING: Monthly uptime limit exceeded ($total_uptime_hours hours >= $UPTIME_LIMIT_HOURS hours)"
        
        # Determine API port based on environment
        if [ "${NODE_ENV:-}" = "dev" ]; then
            PORT_API=7070
            echo "Using development environment (port $PORT_API)"
        else
            PORT_API=8080
            echo "Using production environment (port $PORT_API)"
        fi
        
        # Webhook URLs for both vmapi servers
        URL0="http://192.168.0.6:$PORT_API/vm/webhook-uptime"
        URL1="http://192.168.0.7:$PORT_API/vm/webhook-uptime"
        
        # Send webhooks to both servers for redundancy
        send_webhook "$URL0" "vmapi0" "$USERNAME"
        send_webhook "$URL1" "vmapi1" "$USERNAME"
        
        # Log the uptime limit exceeded event
        echo "$(get_timestamp) - Uptime limit exceeded: ${total_uptime_hours}h ${total_uptime_minutes}m" >> "$UPTIME_LOG"
    else
        echo "Uptime within limits ($total_uptime_hours hours < $UPTIME_LIMIT_HOURS hours)"
    fi
    
    echo "Uptime check completed"
}

# ============================================================================
# MAIN EXECUTION
# ============================================================================

echo "========================================"
echo "Monitor Script - $(get_timestamp)"
echo "LEVEL: $LEVEL"
echo "========================================"

# Check all dependencies before proceeding
check_dependencies

# Initialize bandwidth monitoring (always runs for LEVEL 0 and 1)
init_bandwidth_files
setup_iptables
log_bandwidth

# Both LEVEL 0 and LEVEL 1: Check bandwidth threshold (can trigger shutdown)
if [ "$LEVEL" = "0" ] || [ "$LEVEL" = "1" ]; then
    echo ""
    echo "Checking bandwidth threshold..."
    check_bandwidth_threshold
fi

# LEVEL 0 ONLY: Check uptime limit (runs once per hour)
# Only check uptime if current minute is :00 (effectively hourly when run every 5 minutes)
if [ "$LEVEL" = "0" ]; then
    current_minute=$(date +%M)
    if [ "$current_minute" = "00" ]; then
        echo ""
        check_uptime_limit
    else
        echo ""
        echo "Level 0 customer: Uptime check skipped (runs at :00 minutes only)"
    fi
fi

echo "========================================"
echo "Monitor script completed successfully"
echo "========================================"

exit 0
