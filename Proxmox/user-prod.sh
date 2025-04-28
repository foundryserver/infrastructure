#!/bin/sh

# Create ADMIN user and set password.
useradd -m -s /bin/bash admin
echo "admin:<redacted>" | chpasswd
usermod -aG sudo admin
echo "admin ALL=(ALL) NOPASSWD: ALL" >>/etc/sudoers
mkdir -p /home/admin/.ssh
chmod 700 /home/admin/.ssh
echo "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFK+9vVSQ3PsS5EmZoZDhnwPCl05Z/XdZ8xpG6HijOQX common-jan25" >>/home/admin/.ssh/authorized_keys
echo "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILXC8ewQSURYdaH6TWS0/Pv6KGY2tYap7t1eAizeQjKY ansible-client" >>/home/admin/.ssh/authorized_keys
chmod 600 /home/admin/.ssh/authorized_keys

# Create the fvtt user and set password.
useradd -m -s /bin/bash fvtt
echo "fvtt:<redacted>" | chpasswd
mkdir -p /home/fvtt/.ssh
chmod 700 /home/fvtt/.ssh
echo "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILXC8ewQSURYdaH6TWS0/Pv6KGY2tYap7t1eAizeQjKY ansible-client" >>/home/fvtt/.ssh/authorized_keys
chmod 600 /home/fvtt/.ssh/authorized_keys
mkdir -p /home/fvtt/foundrydata/{Config,Logs,Data}
mkdir -p /home/fvtt/foundrycore
mkdir -p /home/fvtt/webdav
touch /home/fvtt/prod

# Do misc setup and config.
apt update 
apt install htop curl nano qemu-guest-agent cron -y
echo "alias ll='ls -lah'" >> /etc/bash.bashrc
sudo apt install netselect-apt -y
sudo netselect-apt -n -o /etc/apt/sources.list
timedatectl set-timezone America/Vancouver

# Setup SSH config.
cat > /etc/ssh/sshd_config << EOF
Include /etc/ssh/sshd*config.d/\*.conf
PermitRootLogin no
PasswordAuthentication no
ChallengeResponseAuthentication no
UsePAM yes
X11Forwarding no
PrintMotd no
AcceptEnv LANG LC*\*
Subsystem sftp /usr/lib/openssh/sftp-server
EOF
systemctl restart ssh

# Setup Swap
fallocate -l 4G /swapfile
chmod 600 /swapfile
mkswap /swapfile
swapon /swapfile
echo '/swapfile none swap sw 0 0' | tee -a /etc/fstab


# Install and Setup webdav server.

wget https://github.com/hacdias/webdav/releases/download/v5.7.4/linux-amd64-webdav.tar.gz -O /tmp/webdav.tar.gz
tar -xzf /tmp/webdav.tar.gz -C /usr/bin
chmod +x /usr/bin/webdav

cat > /home/fvtt/webdav/config.yaml << EOF
#Listen ip and port
address: 0.0.0.0
port: 3030

# Prefix to apply to the WebDAV path-ing. Default is '/'.
prefix: /

# Whether the server runs behind a trusted proxy or not. When this is true,
# the header X-Forwarded-For will be used for logging the remote addresses
# of logging attempts (if available).
behindProxy: true

# The directory that will be able to be accessed by the users when connecting.
# This directory will be used by users unless they have their own 'directory' defined.
# Default is '.' (current directory).
directory: /foundrydata

# The default permissions for users. This is a case insensitive option. Possible
# permissions: C (Create), R (Read), U (Update), D (Delete). You can combine multiple
# permissions. For example, to allow to read and create, set "RC". Default is "R".
permissions: CRUD

# The list of users. If the list is empty, then there will be no authentication.
# Otherwise, basic authentication will automatically be configured.
#
users:
  - username: "username"
    password: "password"
   # Example user whose details will be picked up from the environment.
  - username: "{env}WD_USERNAME"
    password: "{env}WD_PASSWORD"
EOF

cat > /etc/systemd/system/webdav.service << EOF
[Unit]
Description=WebDAV
After=network.target

[Service]
Environment="WD_USERNAME=admin-foundry" "WD_PASSWORD=<REDACTED>"
Type=simple
User=fvtt
Group=fvtt
ExecStart=/usr/bin/webdav --config /home/fvtt/webdav/config.yaml
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF

systemctl enable webdav
systemctl enable --now webdav.service

# Setup Fvtt application 
cat <<EOF > /etc/systemd/system/fvtt.service
[Unit]
Description=Fvtt Server
After=network.target

[Service]
Type=simple
User=fvtt
Group=fvtt
ExecStart=node /home/fvtt/foundrycore/resources/app/main.js --dataPath=/home/fvtt/foundrydata --noupdate --port=30000 --serviceKey=32kljrekj43kjl3
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF
systemctl enable fvtt
systemctl enable fvtt.service

cat > /home/fvtt/foundrydata/Config/options.json << EOF
{
    "port": 30000,
    "upnp": false,
    "fullscreen": false,
    "hostname": "username.foundryserver.com",
    "routePrefix": null,
    "adminKey": null,
    "sslCert": null,
    "sslKey": null,
    "awsConfig": null,
    "dataPath": "/foundrydata/",
    "proxySSL": false,
    "proxyPort": 443,
    "world": null,
    "isElectron": false,
    "isNode": true,
    "isSSL": true,
    "background": false,
    "debug": false,
    "demo": false,
    "serviceConfig": "/foundrycore/foundryserver.json",
    "updateChannel": "release"
}
EOF

# Setup Bandwidth Scripts

cat > /home/fvtt/bandwidth.sh << EOF 
#!/bin/bash

# Path to the log file that will store bandwidth data
LOG_FILE="/var/log/bandwidth_log.txt"
# Path to the file that will store the current bandwidth value in JSON format
JSON_FILE="/var/log/current_bandwidth.json"
# Threshold for minimum bandwidth (in bytes) over 3 hours
MIN_BANDWIDTH=3000
# Port to monitor
PORT=30000
# File to indicate package level.  /home/fvtt/level1
LEVEL_FILE="/home/fvtt/level1"

# Create the log file if it doesn't exist
if [ ! -f "$LOG_FILE" ]; then
    touch "$LOG_FILE"
fi

# Create the JSON file if it doesn't exist
if [ ! -f "$JSON_FILE" ]; then
    echo '{"bandwidth": 0}' > "$JSON_FILE"
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
    echo "$timestamp,$current_bandwidth" >> "$LOG_FILE"
    
    # Update JSON file
    echo "{\"bandwidth\": $current_bandwidth}" > "$JSON_FILE"
    
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
    hours_diff=$(( ($current_time - $oldest_time) / 3600 ))
    
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
        # /sbin/poweroff
    fi
}

# Main execution
setup_iptables
log_bandwidth
if [ -f "$LEVEL_FILE" ]; then
    check_bandwidth_threshold
fi

# Exit with success status
exit 0
EOF

cat > /home/fvtt/reset_iptables.sh << EOF 
#!/bin/bash

# Script to reset iptables byte counters but retain rules
# This will be run once per month via cron

# Port to monitor - should match the one in bandwidth.sh
PORT=30000

# Log file
LOG_FILE="/var/log/bandwidth_reset.log"

# Function to get current timestamp
get_timestamp() {
    date "+%Y-%m-%d %H:%M:%S"
}

# Record timestamp of reset
echo "$(get_timestamp) - Resetting iptables counters for port $PORT" >> "$LOG_FILE"

# Reset counters by using iptables-save/restore which preserves rules but resets counters
iptables-save > /tmp/iptables.rules
iptables-restore < /tmp/iptables.rules
rm -f /tmp/iptables.rules

echo "$(get_timestamp) - iptables counters reset successfully" >> "$LOG_FILE"

# Exit with success status
exit 0
EOF

# This script sets up the cron jobs for bandwidth monitoring and monthly counter resets

# Define the correct paths to the scripts
BANDWIDTH_SCRIPT="/home/fvtt/bandwidth.sh"
RESET_SCRIPT="/home/fvtt/reset_iptables.sh"

# Make sure the scripts are executable
chmod +x "${BANDWIDTH_SCRIPT}"
chmod +x "${RESET_SCRIPT}"

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

# Install the updated crontab
crontab "$TEMP_CRON"
rm "$TEMP_CRON"
