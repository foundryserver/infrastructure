#!/bin/bash
# Short-Description: Runs webhook.sh once on first boot
# Description:       Executes commands only on the very first boot using a marker file.
# Version:           1.0.1

# Get environment variables from /etc/environment
# This is necessary to ensure that the script has access to the environment variables
if [ -f /etc/environment ]; then
    export $(grep -v '^#' /etc/environment | xargs)
fi

# Check if another instance is running
if [ -f ~/webhook.running ]; then
    echo "Another webhook script is already running"
    exit 0
fi

# Check if the script has already completed successfully
if [ -f ~/webhook.succeeded ]; then
    echo "Webhook has already been completed successfully"
    exit 0
fi

# Create running marker
touch ~/webhook.running

echo "Running one-time initialization commands..."

# --------------- Webhook Script ---------------

# Set the port based on if it is dev or prod from NODE_ENV
if [ "${NODE_ENV}" = "dev" ]; then
    PORT=7070
else
    PORT=8080
fi

# URL to webhook server
URL0="http://vmapi0.vm.local:$PORT/vm/webhook"
URL1="http://vmapi1.vm.local:$PORT/vm/webhook"

# Create an ipcToken for the webhook
USERNAME=$(hostname)
HASH=$(echo -n "$USERNAME" | openssl dgst -sha256 | awk '{print $2}')

# We need for dhcp to assign an IP address to eth0 before we can call the webhook
echo "Waiting for eth0 to get an IP address..."
while ! ip addr show eth0 | grep -q "inet\b"; do
    sleep 1
done

# Get the IP address of eth0
IP_ADDRESS=$(ip addr show eth0 | grep "inet\b" | awk '{print $2}' | cut -d/ -f1)

# Initialize counter and status code
ATTEMPTS=0
MAX_ATTEMPTS=4
STATUS_CODE=0

# Try webhook call until success or max attempts reached
echo "Attempting to call webhook..."
while [ $ATTEMPTS -lt $MAX_ATTEMPTS ] && [ $STATUS_CODE -ne 200 ]; do
    # Increment attempts counter
    ((ATTEMPTS++))

    echo "Attempt $ATTEMPTS of $MAX_ATTEMPTS"

    # Alternate between URL0 and URL1
    if [ $((ATTEMPTS % 2)) -eq 1 ]; then
        URL=$URL0
        echo "Trying primary endpoint (URL0)"
    else
        URL=$URL1
        echo "Trying secondary endpoint (URL1)"
    fi

    # Call webhook and capture status code and response body
    RESPONSE=$(curl -s -w "%{http_code}" -X POST $URL \
        -H "Authorization: Bearer $HASH" \
        -d "ip=$IP_ADDRESS&username=$USERNAME" \
        --connect-timeout 2)

    # Extract status code (last 3 characters of the response)
    STATUS_CODE=$(echo "$RESPONSE" | tail -c 4)
    echo "Response status code: $STATUS_CODE"

    # Extract response body (all but the last 3 characters)
    RESPONSE_BODY=$(echo "$RESPONSE" | head -c -4)
    echo "Response body: $RESPONSE_BODY"

    # If not successful, wait 5 seconds before next attempt
    if [ $STATUS_CODE -ne 200 ] && [ $ATTEMPTS -lt $MAX_ATTEMPTS ]; then
        echo "Retrying in 5 seconds..."
        sleep 5
    fi
done

# Check if we succeeded
if [ $STATUS_CODE -eq 200 ]; then

    # Parse the response body to get the JSON values
    if ! command -v jq &>/dev/null; then
        echo "jq could not be found. Please install jq to parse JSON."
        rm -f ~/webhook.running
        touch ~/webhook.failed
        exit 1
    fi

    echo "Successfully called webhook"
    rm -f ~/webhook.running
    touch ~/webhook.succeeded
    # disable webhook.service from systemd
    systemctl disable webhook.service
    exit 0
else
    echo "Failed to call webhook after $MAX_ATTEMPTS attempts"
    rm -f ~/webhook.running
    touch ~/webhook.failed
    exit 1
fi

# ------------- End Webhook Script -------------

exit 0
