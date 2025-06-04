#!/bin/bash

# Configuration
TARGET_URL="https://foundryserver.com"
LOG_FILE="/var/log/http_monitor.csv"
DISCORD_WEBHOOK_URL="https://discord.com/api/webhooks/1374797458969854076/HEdsb8ZEDuMMNPig1E-Ic9bQBsu4Da1uwWKXyGfYNwsLdBFXh6wRFT7KzxWcw9QaJ3H0" # Replace with your Discord webhook URL

# Create log directory if it doesn't exist
mkdir -p "$(dirname "$LOG_FILE")"

# Create CSV header if the file doesn't exist
if [ ! -f "$LOG_FILE" ]; then
    echo "DateTime,Event,RoundTripTime,StatusCode" >"$LOG_FILE"
fi

# Timestamp
TIMESTAMP=$(date +"%Y-%m-%d %H:%M:%S")

# Make HTTP request and measure time with more reliable format and options
echo "[$TIMESTAMP] Checking connection to $TARGET_URL..."
RESPONSE=$(curl -s -L --connect-timeout 10 -w "%{time_total},%{http_code}" -o /dev/null "$TARGET_URL" 2>/dev/null)

# Debug output
echo "DEBUG: Raw curl response: '$RESPONSE'"

# Parse the response (format is now "time_total,http_code")
TIME=$(echo "$RESPONSE" | cut -d',' -f1)
HTTP_CODE=$(echo "$RESPONSE" | cut -d',' -f2)

echo "DEBUG: Parsed TIME='$TIME', HTTP_CODE='$HTTP_CODE'"

# Convert time to milliseconds with error checking
if [[ -n "$TIME" && "$TIME" != "0" ]]; then
    TIME_MS=$(printf "%.0f" $(echo "$TIME * 1000" | bc 2>/dev/null || echo "$TIME * 1000" | awk '{print $1}'))
    # If calculation failed, try a simpler approach
    if [[ -z "$TIME_MS" || "$TIME_MS" == "0" ]]; then
        TIME_MS="${TIME}ms (raw)"
    fi
else
    TIME_MS="unknown"
fi

# Check if the request was successful
if [[ $HTTP_CODE -ge 200 && $HTTP_CODE -lt 400 ]]; then
    # Success - log the round trip time as CSV
    EVENT="SUCCESS"
    echo "$TIMESTAMP,$EVENT,$TIME_MS,$HTTP_CODE" >>"$LOG_FILE"
    echo "[$TIMESTAMP] Connection successful - HTTP Code: $HTTP_CODE, Round Trip Time: ${TIME_MS}ms"
else
    # Failure - log the error as CSV and send Discord webhook
    EVENT="FAILURE"
    
    # Handle the 000 status code case with a more descriptive message
    if [[ "$HTTP_CODE" == "000" ]]; then
        STATUS_MSG="No connection established (timeout or DNS failure)"
    else
        STATUS_MSG="HTTP Code: $HTTP_CODE"
    fi
    
    echo "$TIMESTAMP,$EVENT,$TIME_MS,$HTTP_CODE" >>"$LOG_FILE"

    ERROR_MESSAGE="[$TIMESTAMP] Connection failed to $TARGET_URL - $STATUS_MSG"
    echo "$ERROR_MESSAGE"

    # Send notification to Discord
    DISCORD_MESSAGE="{ \"content\": \"@here ⚠️ **Alert**: $ERROR_MESSAGE\" }"

    echo "Sending alert to Discord webhook..."
    WEBHOOK_RESPONSE=$(curl -s -H "Content-Type: application/json" -d "$DISCORD_MESSAGE" "$DISCORD_WEBHOOK_URL")

    if [[ -n "$WEBHOOK_RESPONSE" ]]; then
        echo "[$TIMESTAMP] Discord notification sent: $WEBHOOK_RESPONSE"
    else
        echo "[$TIMESTAMP] Discord notification sent successfully"
    fi
fi

exit 0
