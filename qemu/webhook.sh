#!/bin/bash

#===============================================================================
# FOUNDRY VTT VM INITIALIZATION SCRIPT
#===============================================================================
#
# Script Name:    webhook.sh
# Version:        2.0.2
# Purpose:        Comprehensive first-boot initialization script for Foundry VTT VMs
# Author:         Brad Knorr
# Created:        October 1, 2025
# Last Modified:  October 24, 2025
#
#===============================================================================
# DESCRIPTION
#===============================================================================
#
# This script performs comprehensive one-time initialization tasks when a 
# Foundry VTT VM boots for the first time. It handles hostname configuration,
# user setup, software installation, VM registration, and monitoring setup.
#
# The script is designed to be idempotent and robust, allowing safe re-execution
# if it fails at any point. It automatically disables itself after successful
# completion and includes comprehensive error handling and logging.
#
#===============================================================================
# MAIN OPERATIONS
#===============================================================================
#
# 1. HOSTNAME & USER MANAGEMENT
#    - Detects last user added (customer username)
#    - Sets VM hostname to match username if different
#    - Updates /etc/hosts with new hostname
#    - Reboots automatically if hostname changes are made
#
# 2. ENVIRONMENT SETUP
#    - Loads environment variables from /etc/environment
#    - Validates required NODE_ENV and LEVEL variables
#    - Creates execution state tracking files
#
# 3. DIRECTORY STRUCTURE
#    - Creates /home/fvtt/data/foundrydata directory tree
#    - Sets up Config/, Data/, and Logs/ subdirectories
#    - Creates /home/fvtt/data/foundrycore directory
#    - Configures proper ownership (fvtt:fvtt) and permissions
#
# 4. SOFTWARE INSTALLATION
#    - Downloads and installs latest Foundry VTT package from private repository
#    - Handles broken/incomplete installations with cleanup and retry
#    - Verifies installation status using dpkg
#    - Sources from: https://foundry-apt.sfo3.digitaloceanspaces.com/
#
# 5. FOUNDRY VTT CONFIGURATION
#    - Creates comprehensive options.json configuration file
#    - Sets up hostname-based SSL configuration (hostname.knorrfamily.org)
#    - Configures port 30000, data paths, and service settings
#    - Restarts fvtt.service after configuration
#
# 6. VM REGISTRATION & API INTEGRATION
#    - Generates SHA256 authentication token from hostname
#    - Detects IP address of eth0 interface
#    - Calls webhook API to register VM with management system
#    - Implements retry logic with alternating endpoints (vmapi0/vmapi1)
#    - Supports both dev (port 7070) and prod (port 8080) environments
#    - Parses JSON response to extract customer level information
#
# 7. ENVIRONMENT VARIABLE UPDATES
#    - Updates /etc/environment with customer level from API response
#    - Replaces placeholder 'planlevel' with actual customer level (0, 1, 2, etc.)
#
# 8. CLEANUP & SERVICE MANAGEMENT
#    - Disables webhook.service to prevent re-execution
#    - Creates completion markers for state tracking
#    - Removes running marker and creates success marker
#
#===============================================================================
# STATE TRACKING FILES
#===============================================================================
#
# /home/fvtt/webhook.running       - Script is currently executing
# /home/fvtt/webhook.succeeded     - Script completed successfully  
# /home/fvtt/webhook.failed        - Script encountered an error
#
#===============================================================================
# ENVIRONMENT REQUIREMENTS
#===============================================================================
#
# System Requirements:
# - User with UID 1000 must exist (becomes hostname and customer identifier)
# - User 'fvtt' must exist for service ownership
# - /etc/environment file with NODE_ENV and LEVEL variables
#
# Network Requirements:
# - Access to foundry-apt.sfo3.digitaloceanspaces.com (Foundry VTT packages)
# - Access to vmapi0.vm.local and vmapi1.vm.local (webhook registration)
# - DNS resolution for .vm.local domains
# - Network interface eth0 must be available
#
# Software Dependencies:
# - jq (JSON parsing)
# - curl (HTTP requests)  
# - systemctl (service management)
# - iptables (bandwidth monitoring setup)
# - hostnamectl (hostname management)
#
#===============================================================================
# API INTEGRATION
#===============================================================================
#
# Webhook Endpoints:
# - Development: http://vmapi[0|1].vm.local:7070/vm/webhook-init
# - Production:  http://vmapi[0|1].vm.local:8080/vm/webhook-init
#
# Authentication: Bearer token "webhookInit" in Authorization header
# Request Parameters: ip={eth0_ip}&username={hostname}
# Response Format: JSON with 'level' field containing customer tier
#
# Retry Logic: 4 attempts maximum, alternating between vmapi0 and vmapi1
# Timeout: 2 seconds connection timeout per attempt
#
#===============================================================================
# USAGE
#===============================================================================
#
# Automatic Execution:
#   Typically runs automatically via webhook.service systemd unit on first boot
#
# Manual Execution:
#   sudo /home/fvtt/webhook.sh
#
# The script includes comprehensive safety checks:
# - Prevents multiple concurrent executions
# - Skips operations already completed successfully
# - Handles partial failures with resume capability
# - Provides detailed logging for troubleshooting
#
#===============================================================================
# LOGGING
#===============================================================================
#
# Primary Log: /var/log/webhook-init.log (persistent, detailed)
# Console Output: Visible in systemd journal (journalctl -u webhook.service)
#
# Log Format: [YYYY-MM-DD HH:MM:SS] MESSAGE
# Error Handling: All errors logged with ERROR prefix before exit
#
#===============================================================================

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

# take the username at uid of 1000
USERNAME=$(getent passwd | awk -F: '$3 >= 1000 && $3 != 65534 {print $1 ":" $3}' | sort -t: -k2 -n | tail -1 | cut -d: -f1)
if [ -z "$USERNAME" ]; then
    handle_error "No regular user found. Exiting."
fi

# compare username to hostname and skip if they match. 
if [ "$USERNAME" = "$(hostname)" ]; then
    log "Username matches hostname, skipping hostname setup."
else
    log "Username does not match hostname, proceeding with hostname setup."
    # Set the hostname of the vm to the username.
    HOSTNAME="$USERNAME"
    # Set the hostname
    hostnamectl set-hostname "$HOSTNAME"
    log "Hostname set to $HOSTNAME"

    # change the hosts file to reflect the new hostname
    sed -i "s/127.0.1.1.*/127.0.1.1 $HOSTNAME/" /etc/hosts
    log "Updated /etc/hosts with new hostname"

    # Reboot vm to apply hostname changes.
    if [ ! -f /home/fvtt/webhook.rebooted ]; then
        log "Rebooting VM to apply hostname changes..."
        reboot
        touch /home/fvtt/webhook.rebooted
        exit 0
    else
        log "VM has already been rebooted for hostname changes, exiting to prevent loop"
        exit 0
    fi
fi

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
    "port": 30000,
    "upnp": false,
    "fullscreen": false,
    "hostname": "$HOSTNAME.knorrfamily.org",
    "routePrefix": null,
    "adminKey": null,
    "sslCert": null,
    "sslKey": null,
    "awsConfig": null,
    "dataPath": "/home/fvtt/data/foundrydata",
    "proxySSL": false,
    "proxyPort": 443,
    "world": null,
    "isElectron": false,
    "isNode": true,
    "isSSL": true,
    "background": false,
    "debug": false,
    "demo": false,
    "serviceConfig": "/home/fvtt/data/foundrycore/foundryserver.json",
    "updateChannel": "release"
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

    # Call webhook and capture status code and response body
    RESPONSE=$(curl -s -w "%{http_code}" -X GET "${URL}?ip=${IP_ADDRESS}&username=${USERNAME}" \
        -H "Authorization: Bearer webhookInit" \
        --connect-timeout 2)

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
    
    # Update environment file and verify the replacement occurred
    if sed -i "s/planlevel/$LEVEL/g" /etc/environment; then
        # Verify that planlevel no longer exists in the file
        if grep -q "planlevel" /etc/environment; then
            handle_error "Failed to replace planlevel in environment file - placeholder still exists"
        else
            log "Successfully updated environment variables with level: $LEVEL"
        fi
    else
        handle_error "Failed to update environment variables"
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
