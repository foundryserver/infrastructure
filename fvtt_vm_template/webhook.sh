#!/bin/bash
### BEGIN INIT INFO
# Provides:          webhook.sh
# Required-Start:    $local_fs $syslog
# Required-Stop:     $local_fs $syslog
# Default-Start:     2 3 4 5
# Default-Stop:      0 1 6
# Short-Description: Runs webhook.sh once on first boot
# Description:       Executes commands only on the very first boot using a marker file.
### END INIT INFO

# Check if another instance is running
if [ -f /home/admin/webhook.running ]; then
    echo "Another webhook script is already running"
    exit 0
fi

# Check if the script has already completed successfully
if [ -f /home/admin/webhook.succeeded ]; then
    echo "Webhook has already been completed successfully"
    exit 0
fi

# Create running marker
touch /home/admin/webhook.running

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

# Get the IP address of eth0
IP_ADDRESS=$(ip addr show eth0 | grep "inet\b" | awk '{print $2}' | cut -d/ -f1)

# Using sed replace the text "username" with the value of $USERNAME in the file
sed -i "s/username/$USERNAME/g" /home/fvtt/foundrydata/Config/options.json

# Install the latest foundry version.
echo "Installing the latest Foundry version..."
curl -s https://foundry-apt.sfo3.digitaloceanspaces.com/foundry_latest_amd64.deb | sudo bash -c "cat > /tmp/pkg.deb && dpkg -i /tmp/pkg.deb && rm /tmp/pkg.deb"

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
        rm -f /home/admin/webhook.running
        touch /home/admin/webhook.failed
        exit 1
    fi

    echo "Setting up environment variables..."
    LEVEL=$(echo "$RESPONSE_BODY" | jq -r '.level')
    sed -i "s/planlevel/$LEVEL/g" /etc/environment

    echo "Successfully called webhook"
    rm -f /home/admin/webhook.running
    touch /home/admin/webhook.succeeded
    exit 0
else
    echo "Failed to call webhook after $MAX_ATTEMPTS attempts"
    rm -f /home/admin/webhook.running
    touch /home/admin/webhook.failed
    exit 1
fi

# ------------- End Webhook Script -------------

exit 0
