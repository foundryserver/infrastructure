#! /bin/bash
### BEGIN INIT INFO
# Provides:          webhook.sh
# Required-Start:    $local_fs $syslog
# Required-Stop:     $local_fs $syslog
# Default-Start:     2 3 4 5
# Default-Stop:      0 1 6
# Short-Description: runs webhook.sh once on first boot
# Description:       Executes commands only on the very first boot using a marker file.
### END INIT INFO

# Check if the script has already been run
if [ -f /home/admin/webhook.succeeded ]; then
    exit 0
fi

echo "Running one-time initialization commands..."

# --------------- Webhook Script ---------------

# Set the port based on if it is dev or prod. This comes from the env called NODE_ENV

if [ ${NODE_ENV} = "dev" ]; then
    PORT=7070
else
    PORT=8080
fi

# URL to webhook server
URL0="http://vmapi0.vm.local:$PORT/vm/webhook"
URL1="http://vmapi1.vm.local:$PORT/vm/webhook"

# Set Initial url to vmapi0
URL=$URL0

# We need to create an ipcToken for the webhook
USERNAME=$(hostname)
HASH=$(echo -n "$USERNAME" | openssl dgst -sha256 | awk '{print $2}')

# Get the IP address of eth0
IP_ADDRESS=$(ip addr show eth0 | grep "inet\b" | awk '{print $2}' | cut -d/ -f1)

# using sed replace the text "username" with the value of $USERNAME in the file /home/fvtt/foundrydata/Config/options.json
sed -i "s/username/$USERNAME/g" /home/fvtt/foundrydata/Config/options.json

# Initialize counter and status code
ATTEMPTS=0
MAX_ATTEMPTS=5
STATUS_CODE=0

# Try webhook call until success or max attempts reached
while [ $ATTEMPTS -lt $MAX_ATTEMPTS ] && [ $STATUS_CODE -ne 200 ]; do
    # Increment attempts counter
    ((ATTEMPTS++))

    echo "Attempt $ATTEMPTS of $MAX_ATTEMPTS"

    # Call webhook and capture status code and response body
    RESPONSE=$(curl -s -w "%{http_code}" -X POST $URL \
        -H "Authorization: Bearer $HASH" \
        -d "ip=$IP_ADDRESS&username=$USERNAME" \
        --connect-timeout 5 \
        --max-time 30)

    # Extract status code (last 3 characters of the response)
    STATUS_CODE=$(echo "$RESPONSE" | tail -c 4)

    # Extract response body (all but the last 3 characters)
    RESPONSE_BODY=$(echo "$RESPONSE" | head -c -4)

    echo "Response status code: $STATUS_CODE"
    echo "Response body: $RESPONSE_BODY"

    # If not successful, wait 5 seconds before next attempt
    if [ $STATUS_CODE -ne 200 ] && [ $ATTEMPTS -lt $MAX_ATTEMPTS ]; then
        echo "Retrying in 5 seconds..."
        URL=$URL1
        sleep 5
    fi
done

# Check if we succeeded
if [ $STATUS_CODE -eq 200 ]; then
    echo "Successfully called webhook"
    touch /home/admin/webhook.succeeded
    # parse the response body to get the json values.
    # jq is a command-line JSON processor. Install it if not already installed.
    if ! command -v jq &>/dev/null; then
        echo "jq could not be found. Please install jq to parse JSON."
        exit 1
    fi
    LEVEL=$(echo "$RESPONSE_BODY" | jq -r '.level')
    # using sed replace the text "{level}" with the value of $LEVEL
    sed -i "s/{planlevel}/$LEVEL/g" /etc/environment
    exit 0
else
    echo "Failed to call webhook after $MAX_ATTEMPTS attempts"
    touch /home/admin/webhook.failed
    exit 1
fi

# ------------- End Webhook Script -------------

exit 0
