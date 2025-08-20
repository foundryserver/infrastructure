# Setup and Configure Remote Monitoring.

Simple low cost vms from different parts of the world to access the website url to test connectivity issues. The alert goes to the discord channel.

## Monitoring Script

```
#!/bin/bash

# Configuration
WEBSITE="foundryserver.com"
WEBHOOK_URL="https://discord.com/api/webhooks/1349491954232066088/l-RQkVN5_d9dmyfmOd9RA-FDx4XnUZrL70_zuoeqbmAuXcpDqyod4DwxyBEbK1jjf8Lt"
CHECK_INTERVAL=60  # Check every 60 seconds (1 minute)

echo "Starting monitoring of $WEBSITE..."

while true; do
    # Try to ping the website (send 2 packets, wait 5 seconds max)
    if ! ping -c 2 -W 5 $WEBSITE > /dev/null 2>&1; then
        # Ping failed, prepare timestamp
        TIMESTAMP=$(date "+%Y-%m-%d %H:%M:%S")

        # Send message to Discord
        curl -s -X POST -H "Content-Type: application/json" \
             -d "{\"content\": \"@here ⚠️ **ALERT**: {change to location value} is unable to reach $WEBSITE at $TIMESTAMP\"}" \
             $WEBHOOK_URL

        echo "[$TIMESTAMP] Alert sent: Unable to reach $WEBSITE"
    fi

    # Wait for the next check
    sleep $CHECK_INTERVAL
done
```

## Systemd Unit File

```
cat <<EOF > /etc/systemd/system/monitor.service
[Unit]
Description=Foundry Monitor Script

[Install]
WantedBy=multi-user.target

[Service]
Type=simple
ExecStart=/root/monitor.sh
Restart=on-failure
EOF


systemctl enable monitor
systemctl start monitor
```
