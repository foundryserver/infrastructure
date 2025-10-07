#!/bin/bash

#===============================================================================
# FOUNDRY VTT VM INITIALIZATION SCRIPT
#===============================================================================
#
# Script Name:    webhook.sh
# Version:        1.1.3
# Purpose:        First-boot initialization script for Foundry VTT virtual machines
# Author:         Brad Knorr
# Created:        October 1, 2025
# Last Modified:  October 6, 2025
#
#===============================================================================
# DESCRIPTION
#===============================================================================
#
# This script performs one-time initialization tasks when a Foundry VTT VM
# boots for the first time. It is designed to be idempotent and robust,
# allowing safe re-execution if the script fails at any point.
#
# The script will automatically disable itself after successful completion
# by disabling the webhook.service systemd service.
#
#===============================================================================
# MAIN OPERATIONS
#===============================================================================
#
# 1. STORAGE SETUP
#    - Mounts SCSI device (/dev/sdb) to /home/fvtt/data
#    - Creates fstab entry for persistent mounting
#    - Sets up Foundry VTT directory structure
#    - Configures proper ownership and permissions
#
# 2. SOFTWARE INSTALLATION
#    - Downloads and installs latest Foundry VTT package
#    - Handles broken/incomplete installations
#    - Verifies successful installation
#
# 3. VM REGISTRATION
#    - Generates authentication token based on hostname
#    - Calls webhook API to register VM with management system
#    - Retries with fallback endpoints on failure
#    - Updates environment variables with response data
#
# 4. CLEANUP
#    - Disables webhook.service to prevent re-execution
#    - Creates completion markers for state tracking
#
#===============================================================================
# STATE TRACKING FILES
#===============================================================================
#
# /home/fvtt/webhook.running      - Script is currently executing
# /home/fvtt/webhook.succeeded    - Script completed successfully
# /home/fvtt/webhook.failed       - Script encountered an error
#
#===============================================================================
# ENVIRONMENT REQUIREMENTS
#===============================================================================
#
# Required:
# - /etc/environment file with NODE_ENV variable
# - jq package for JSON parsing
# - curl for webhook API calls
# - systemctl for service management
# - User 'fvtt' must exist
# - SCSI device at /dev/sdb
#
# Network:
# - Access to foundry-apt.sfo3.digitaloceanspaces.com
# - Access to vmapi0.vm.local and vmapi1.vm.local
#
#===============================================================================
# USAGE
#===============================================================================
#
# This script is typically executed automatically by systemd on first boot
# via the webhook.service unit file. It can also be run manually:
#
#   sudo /path/to/webhook.sh
#
# The script includes safety checks to prevent multiple concurrent executions
# and will skip operations that have already been completed successfully.
#
#===============================================================================
# LOGGING
#===============================================================================
#
# All operations are logged with timestamps to:
# - Console output (visible in systemd journal)
# - /var/log/webhook-init.log (persistent log file)
#
#===============================================================================

# version 1.1.0 - Enhanced with robustness checks

# Logging function
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a /var/log/webhook-init.log
}

# Error handling function
handle_error() {
    log "ERROR: $1"
    rm -f /home/fvtt/webhook.running
    touch /home/fvtt/webhook.failed
    exit 1
}

# Get environment variables from /etc/environment
# This is necessary to ensure that the script has access to the environment variables
if [ -f /etc/environment ]; then
    export $(grep -v '^#' /etc/environment | xargs)
    log "Loaded environment variables from /etc/environment"
else
    handle_error "WARNING: /etc/environment not found EXITING"
fi

# Check if another instance is running
if [ -f /home/fvtt/webhook.running ]; then
    log "Another webhook script is already running"
    exit 0
fi

# Check if the script has already completed successfully
if [ -f /home/fvtt/webhook.succeeded ]; then
    log "Webhook has already been completed successfully"
    exit 0
fi

# Create running marker
touch /home/fvtt/webhook.running
log "Starting one-time initialization..."

# --------------- Webhook Script ---------------

# Mount scsi1 device to the VM and put an entry in /etc/fstab
log "Checking SCSI device mount..."

# Check if already mounted
if mountpoint -q /home/fvtt/data; then
    log "SCSI device already mounted at /home/fvtt/data"
else
    log "Mounting scsi1 device to the VM..."    

    # partition /dev/sdb if it is not already partitioned
    if ! blkid /dev/sdb1 >/dev/null 2>&1; then
        log "Partitioning /dev/sdb..."
        echo -e "n\np\n1\n\n\nw" | fdisk /dev/sdb || handle_error "Failed to partition /dev/sdb"
        sleep 2
    else
        log "/dev/sdb is already partitioned"
    fi

    # Check if fstab entry exists
    if ! grep -q '/dev/sdb1 /home/fvtt/data ext4 defaults 0 2' /etc/fstab; then
        log "Adding fstab entry for /dev/sdb1"
        echo '/dev/sdb1 /home/fvtt/data ext4 defaults 0 2' >>/etc/fstab
    else
        log "fstab entry already exists"
    fi
    
    # Create mount point if it doesn't exist
    if [ ! -d /home/fvtt/data ]; then
        mkdir -p /home/fvtt/data
    fi    
    
    # Attempt to mount
    if mount /home/fvtt/data; then
        log "Successfully mounted /home/fvtt/data"
    else
        handle_error "Failed to mount /home/fvtt/data"
    fi

       # Format if not already formatted
    if ! blkid /dev/sdb1 >/dev/null 2>&1; then
        log "Formatting /dev/sdb1 as ext4..."
        mkfs.ext4 /dev/sdb1 || handle_error "Failed to format /dev/sdb1"
    else
        log "/dev/sdb1 is already formatted"
    fi
fi

# Create directory structure if it doesn't exist
log "Setting up directory structure..."

if [ ! -d /home/fvtt/data/foundrydata ]; then
    mkdir -p /home/fvtt/data/foundrydata
    mkdir -p /home/fvtt/data/foundrydata/{Data,Logs,Config}
    log "Created foundry data directory structure"
else
    log "Foundry data directory structure already exists"
fi

if [ ! -d /home/fvtt/data/foundrycore ]; then
    mkdir -p /home/fvtt/data/foundrycore
    log "Created foundry core directory structure"
else
    log "Foundry core directory structure already exists"
fi

# Set permissions (always do this to ensure correct ownership)
log "Setting ownership and permissions..."
chown -R fvtt:fvtt /home/fvtt/data
chmod 700 -R /home/fvtt/data

# Install the latest fvtt version via apt from a private repo
# link  https://foundry-apt.sfo3.digitaloceanspaces.com/foundry_latest_amd64.deb
log "Checking Foundry VTT installation..."

# Check if foundry is installed and properly configured
if dpkg -s foundry >/dev/null 2>&1; then
    # Check if the installation is complete and not broken
    INSTALL_STATUS=$(dpkg-query -W -f='${Status}' foundry 2>/dev/null)
    if [ "$INSTALL_STATUS" = "install ok installed" ]; then
        log "Foundry VTT is already installed and configured"
    else
        log "Foundry VTT installation appears incomplete or broken, reinstalling..."
        # Remove broken installation
        dpkg --remove --force-remove-reinstreq foundry 2>/dev/null || true
        apt-get -f install -y 2>/dev/null || true
        
        log "Installing Foundry VTT..."
        if wget -O /tmp/foundry.deb https://foundry-apt.sfo3.digitaloceanspaces.com/foundry_latest_amd64.deb; then
            if dpkg -i /tmp/foundry.deb; then
                log "Foundry VTT installation successful"
            else                
                handle_error "Foundry VTT installation failed"
            fi
            rm -f /tmp/foundry.deb
        else
            handle_error "Failed to download Foundry VTT package"
        fi
    fi
else
    log "Installing Foundry VTT..."
    if wget -O /tmp/foundry.deb https://foundry-apt.sfo3.digitaloceanspaces.com/foundry_latest_amd64.deb; then
        if dpkg -i /tmp/foundry.deb; then
            log "Foundry VTT installation successful"
        else
            handle_error "Foundry VTT installation failed"
        fi
        rm -f /tmp/foundry.deb
    else
        handle_error "Failed to download Foundry VTT package"
    fi
fi

# Setup options.json so foundry will start correctly.
log "Setting up Foundry VTT options.json..."
cat <<EOF > /home/fvtt/data/foundrydata/Config/options.json
{
        port: 30000,
        upnp: false,
        fullscreen: false,
        hostname: $HOSTNAME.foundryserver.com,
        routePrefix: null,
        adminKey: null,
        sslCert: null,
        sslKey: null,
        awsConfig: null,
        dataPath: /home/fvtt/data/foundrydata,
        proxySSL: false,
        proxyPort: 443,
        world: null,
        isElectron: false,
        isNode: true,
        isSSL: true,
        background: false,
        debug: false,
        demo: false,
        serviceConfig: /home/fvtt/data/foundrycore/foundryserver.json,
        updateChannel: "release",
      }
EOF
systemctl restart fvtt.service || handle_error "Failed to restart fvtt service after options.json setup"

# Set the port based on if it is dev or prod from NODE_ENV
if [ "${NODE_ENV}" = "dev" ]; then
    PORT=7070
else
    PORT=8080
fi

# URL to webhook server
URL0="http://vmapi0.vm.local:$PORT/vm/webhook-init"
URL1="http://vmapi1.vm.local:$PORT/vm/webhook-init"

# Create an ipcToken for the webhook
USERNAME=$(hostname)
HASH=$(echo -n "$USERNAME" | openssl dgst -sha256 | awk '{print $2}')

# Get the IP address of eth0
IP_ADDRESS=$(ip addr show eth0 | grep "inet\b" | awk '{print $2}' | cut -d/ -f1)

# Initialize counter and status code
ATTEMPTS=0
MAX_ATTEMPTS=4
STATUS_CODE=0

# Try webhook call until success or max attempts reached
log "Attempting to call webhook..."
while [ $ATTEMPTS -lt $MAX_ATTEMPTS ] && [ $STATUS_CODE -ne 200 ]; do
    # Increment attempts counter
    ((ATTEMPTS++))

    log "Attempt $ATTEMPTS of $MAX_ATTEMPTS"

    # Alternate between URL0 and URL1
    if [ $((ATTEMPTS % 2)) -eq 1 ]; then
        URL=$URL0
        log "Trying primary endpoint (URL0)"
    else
        URL=$URL1
        log "Trying secondary endpoint (URL1)"
    fi

    # Debug: Log the values being sent
    log "Sending data: ip=${IP_ADDRESS}, username=${USERNAME}"
    log "Using URL: $URL"

    # Call webhook and capture status code and response body with verbose output
    RESPONSE=$(curl -v -s -w "%{http_code}" -X GET "${URL}?ip=${IP_ADDRESS}&username=${USERNAME}" \
        -H "Authorization: Bearer $HASH" \
        --connect-timeout 2 2>&1)

    # Extract status code (last 3 characters of the response)
    STATUS_CODE=$(echo "$RESPONSE" | tail -c 4)
    log "Response status code: $STATUS_CODE"

    # Extract response body (all but the last 3 characters)
    RESPONSE_BODY=$(echo "$RESPONSE" | head -c -4)
    log "Response body: $RESPONSE_BODY"

    # If not successful, wait 5 seconds before next attempt
    if [ $STATUS_CODE -ne 200 ] && [ $ATTEMPTS -lt $MAX_ATTEMPTS ]; then
        log "Retrying in 5 seconds..."
        sleep 5
    fi
done

# Check if we succeeded
if [ $STATUS_CODE -eq 200 ]; then

    # Parse the response body to get the JSON values
    if ! command -v jq &>/dev/null; then
        handle_error "jq could not be found. Please install jq to parse JSON."
    fi

    log "Setting up environment variables..."
    LEVEL=$(echo "$RESPONSE_BODY" | jq -r '.level')
    
    # Check if the level was successfully parsed
    if [ "$LEVEL" = "null" ] || [ -z "$LEVEL" ]; then
        handle_error "Failed to parse level from webhook response"
    fi
    
    # Update environment file
    if sed -i "s/planlevel/$LEVEL/g" /etc/environment; then
        log "Successfully updated environment variables with level: $LEVEL"
        touch /home/fvtt/webhook.env.updated
    else
        handle_error "Failed to update environment variables"
    fi

    # Set cron jobs based on level (0 = 15 hr/mon , 1 = 3 hour idle shutdown)
    if [ "$LEVEL" -eq 0 ]; then
        (crontab -l 2>/dev/null; echo "0 * * * * /home/fvtt/uptime.sh >> /var/log/uptime_execution.log 2>&1") | crontab -
        log "Set uptime cron job for level 0"
    elif [ "$LEVEL" -eq 1 ]; then
        (crontab -l 2>/dev/null; echo "*/10 * * * * /home/fvtt/bandwidth.sh >> /var/log/bandwidth_execution.log 2>&1") | crontab -
        (crontab -l 2>/dev/null; echo "1 0 1 * * /home/fvtt/reset_iptables.sh >> /var/log/reset_iptables_execution.log 2>&1") | crontab -
        log "Set bandwidth cron job for level 1"
    fi

    log "Successfully called webhook"
    rm -f /home/fvtt/webhook.running
    touch /home/fvtt/webhook.succeeded
    
    # Disable webhook service if it's enabled
    if systemctl is-enabled webhook.service >/dev/null 2>&1; then
        log "Disabling webhook service..."
        systemctl disable webhook.service
    else
        log "Webhook service already disabled"
    fi
    exit 0
else
    handle_error "Failed to call webhook after $MAX_ATTEMPTS attempts"
fi

# ------------- End Webhook Script -------------

exit 0
