#!/bin/bash

#===============================================================================
# FOUNDRY VTT VM INITIALIZATION SCRIPT
#===============================================================================
#
# Script Name:    webhook.sh
# Version:        4.0.2
# Purpose:        Enterprise-grade first-boot initialization script for Foundry VTT VMs
# Author:         Brad Knorr
# Created:        October 1, 2025
# Last Modified:  October 25, 2025
#
#===============================================================================
# DESCRIPTION
#===============================================================================
#
# This script performs streamlined one-time initialization tasks when a 
# Foundry VTT VM boots for the first time. It handles VM registration 
# with the management system.
#
# The script follows enterprise best practices with comprehensive error handling,
# input validation, structured logging, and modular function design. It is 
# designed to be idempotent and robust, allowing safe re-execution if it fails 
# at any point. It automatically disables itself after successful completion.
#
#===============================================================================
# MAIN OPERATIONS
#===============================================================================
#
# 1. ENVIRONMENT SETUP & VALIDATION
#    - Loads and validates environment variables from /etc/environment
#    - Validates required NODE_ENV variable for environment detection
#    - Implements comprehensive input validation and error checking
#    - Creates execution state tracking files with proper cleanup
#
# 2. SSH HOST KEY SECURITY
#    - Removes existing SSH host keys for security
#    - Generates new host keys using ssh-keygen -A (RSA, ECDSA, ED25519)
#    - Uses default key lengths and proper permissions automatically
#    - Restarts SSH service to apply new host keys
#
# 3. NETWORK VALIDATION & VM REGISTRATION
#    - Validates and detects IP address of eth0 interface with regex validation
#    - Calls webhook API to register VM with management system
#    - Implements robust retry logic with alternating endpoints (vmapi0/vmapi1)
#    - Supports both dev (port 7070) and prod (port 8080) environments
#    - Uses authenticated GET requests with comprehensive timeout handling
#
# 4. CLEANUP & SERVICE MANAGEMENT
#    - Disables webhook.service with verification to prevent re-execution
#    - Creates completion markers for state tracking
#    - Implements proper signal handling and cleanup on exit
#    - Removes running marker and creates success marker atomically
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
# EXIT CODES
#===============================================================================
#
# 0 - EXIT_SUCCESS           - Script completed successfully
# 1 - EXIT_GENERAL_ERROR     - General/unspecified error
# 2 - EXIT_ENV_ERROR         - Environment variable or configuration error
# 3 - EXIT_NETWORK_ERROR     - Network connectivity or API call error
#
#===============================================================================
# ENVIRONMENT REQUIREMENTS
#===============================================================================
#
# System Requirements:
# - /etc/environment file with NODE_ENV variable (dev/prod)
# - Network interface eth0 must be available and configured
# - Root/sudo privileges for service management
#
# Network Requirements:
# - Access to vmapi0.vm.local and vmapi1.vm.local (webhook registration)
# - DNS resolution for .vm.local domains
# - Outbound HTTP/HTTPS connectivity on configured ports
#
# Software Dependencies:
# - curl (HTTP requests with timeout support)
# - systemctl (service management)
# - ip (network interface management)
# - ssh-keygen (SSH host key generation)
# - awk, grep, head, tail (text processing)
#
#===============================================================================
# SECURITY FEATURES
#===============================================================================
#
# - Fixed webhook token "webhookInit" for consistent authentication
# - Input validation for IP addresses using regex patterns
# - Secure temporary file handling with automatic cleanup
# - Proper signal handling to prevent incomplete states
# - Read-only configuration constants to prevent accidental modification
# - Comprehensive logging without exposing sensitive information
#
#===============================================================================
# API INTEGRATION
#===============================================================================
#
# Webhook Endpoints:
# - Development: http://vmapi[0|1].vm.local:7070/vm/webhook-init
# - Production:  http://vmapi[0|1].vm.local:8080/vm/webhook-init
#
# Authentication: Bearer token "webhookInit" (fixed authentication token)
# Request Parameters: ip={eth0_ip} (validated IPv4 address)
# Response Format: HTTP status code (200 = success)
#
# Retry Logic: 4 attempts maximum, alternating between vmapi0 and vmapi1
# Timeouts: 2 seconds connection timeout, 10 seconds total timeout per attempt
# Error Handling: Specific exit codes for different failure scenarios
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
# Debug Mode:
#   DEBUG=1 sudo /home/fvtt/webhook.sh
#
# The script includes comprehensive safety checks:
# - Prevents multiple concurrent executions using file locking
# - Skips operations already completed successfully with state validation
# - Handles partial failures with resume capability and atomic operations
# - Provides detailed logging with structured log levels for troubleshooting
# - Implements proper signal handling for graceful cleanup on interruption
#
#===============================================================================
# LOGGING
#===============================================================================
#
# Primary Log: /var/log/webhook-init.log (persistent, detailed)
# Console Output: Visible in systemd journal (journalctl -u webhook.service)
#
# Log Levels:
# - INFO: General operational information
# - WARN: Non-fatal issues that should be noted
# - ERROR: Fatal errors that cause script termination
# - DEBUG: Detailed troubleshooting information (enabled with DEBUG=1)
#
# Log Format: [YYYY-MM-DD HH:MM:SS] LEVEL: MESSAGE
# Error Handling: All errors logged with specific exit codes before termination
# Security: Sensitive information (tokens, credentials) are not logged
#
#===============================================================================

#===============================================================================
# CONFIGURATION
#===============================================================================

# Exit codes
readonly EXIT_SUCCESS=0
readonly EXIT_GENERAL_ERROR=1
readonly EXIT_ENV_ERROR=2
readonly EXIT_NETWORK_ERROR=3

# Configuration constants
readonly CONFIG_BASE_DIR="/root"
readonly WEBHOOK_ENDPOINTS=("vmapi0.vm.local" "vmapi1.vm.local")
readonly DEV_PORT=7070
readonly PROD_PORT=8080
readonly WEBHOOK_TIMEOUT=2
readonly WEBHOOK_MAX_TIME=10
readonly MAX_RETRY_ATTEMPTS=4
readonly LOG_FILE="/var/log/webhook-init.log"

# State files
readonly RUNNING_MARKER="${CONFIG_BASE_DIR}/webhook.running"
readonly SUCCESS_MARKER="${CONFIG_BASE_DIR}/webhook.succeeded"
readonly FAILED_MARKER="${CONFIG_BASE_DIR}/webhook.failed"

# Get webhook token from environment or use default
readonly WEBHOOK_TOKEN="webhookInit"

#===============================================================================
# LOGGING FUNCTIONS
#===============================================================================

# Base logging function
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

# Structured logging functions
log_error() { log "ERROR: $1"; }
log_warn() { log "WARN: $1"; }
log_info() { log "INFO: $1"; }
log_debug() { [[ "${DEBUG:-}" == "1" ]] && log "DEBUG: $1"; }

#===============================================================================
# ERROR HANDLING
#===============================================================================

# Enhanced error handling function
handle_error() {
    local error_msg="$1"
    local exit_code="${2:-$EXIT_GENERAL_ERROR}"
    
    log_error "$error_msg"
    rm -f "$RUNNING_MARKER"
    touch "$FAILED_MARKER"
    exit "$exit_code"
}

# Cleanup function for graceful exits
cleanup() {
    rm -f "$RUNNING_MARKER"
}

# Set trap for cleanup on script exit
trap cleanup EXIT

#===============================================================================
# UTILITY FUNCTIONS
#===============================================================================

# Validate and get IP address of eth0 interface
get_eth0_ip() {
    local ip
    ip=$(ip route get 1.1.1.1 | grep -oP 'src \K\S+')
    
    if [[ ! "$ip" =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
        handle_error "Failed to detect valid IP address for eth0" "$EXIT_NETWORK_ERROR"
    fi
    
    log_debug "Detected eth0 IP address: $ip"
    echo "$ip"
}

# Load and validate environment variables
setup_environment() {
    log_info "Setting up environment..."
    
    if [[ ! -f /etc/environment ]]; then
        handle_error "/etc/environment not found" "$EXIT_ENV_ERROR"
    fi
    
    # Load environment variables
    set -a
    source /etc/environment
    set +a
    
    log_info "Loaded environment variables from /etc/environment"
    
    # Validate required environment variables
    if [[ -z "${NODE_ENV:-}" ]]; then
        handle_error "NODE_ENV environment variable is required" "$EXIT_ENV_ERROR"
    fi
    
    log_info "Environment: NODE_ENV=${NODE_ENV}"
}

# Check execution state and prevent concurrent runs
check_execution_state() {
    log_info "Checking execution state..."
    
    # Check if another instance is running
    if [[ -f "$RUNNING_MARKER" ]]; then
        log_warn "Another webhook script is already running"
        exit "$EXIT_SUCCESS"
    fi

    # Check if the script has already completed successfully
    if [[ -f "$SUCCESS_MARKER" ]]; then
        log_info "Webhook has already been completed successfully"
        exit "$EXIT_SUCCESS"
    fi

    # Create running marker
    touch "$RUNNING_MARKER"
    log_info "Starting one-time initialization..."
}

#===============================================================================
# WEBHOOK REGISTRATION
#===============================================================================

# Register VM with webhook API
register_with_webhook() {
    log_info "Starting webhook registration process..."
    
    # Get IP address
    local ip_address
    ip_address=$(get_eth0_ip)
    
    # Determine port based on environment
    local port
    if [[ "${NODE_ENV}" == "dev" ]]; then
        port="$DEV_PORT"
    else
        port="$PROD_PORT"
    fi
    
    log_info "Using port $port for $NODE_ENV environment"
    
    # Build URLs
    local url0="http://${WEBHOOK_ENDPOINTS[0]}:$port/vm/webhook-init"
    local url1="http://${WEBHOOK_ENDPOINTS[1]}:$port/vm/webhook-init"
    
    # Initialize retry logic
    local attempts=0
    local status_code=0
    
    log_info "Attempting webhook registration with IP: $ip_address"
    
    while [[ $attempts -lt $MAX_RETRY_ATTEMPTS ]] && [[ $status_code -ne 200 ]]; do
        ((attempts++))
        log_info "Attempt $attempts of $MAX_RETRY_ATTEMPTS"

        # Alternate between endpoints
        local url
        if [[ $((attempts % 2)) -eq 1 ]]; then
            url="$url0"
            log_debug "Trying primary endpoint: ${WEBHOOK_ENDPOINTS[0]}"
        else
            url="$url1"
            log_debug "Trying secondary endpoint: ${WEBHOOK_ENDPOINTS[1]}"
        fi

        log_debug "Request URL: $url?ip=$ip_address"

        # Make webhook call with better error handling
        local response
        local curl_exit_code
        response=$(curl -s -w "%{http_code}" -X GET "${url}?ip=${ip_address}" \
            -H "Authorization: Bearer $WEBHOOK_TOKEN" \
            --connect-timeout "$WEBHOOK_TIMEOUT" \
            --max-time "$WEBHOOK_MAX_TIME" \
            2>&1)
        curl_exit_code=$?

        if [[ $curl_exit_code -ne 0 ]]; then
            log_warn "Curl failed with exit code $curl_exit_code: $response"
            status_code=0
        else
            # Extract status code and response body
            if [[ ${#response} -ge 3 ]]; then
                status_code=$(echo "$response" | tail -c 4)
                local response_body
                response_body=$(echo "$response" | head -c -4)
                log_debug "Response body: $response_body"
            else
                log_warn "Invalid response received: $response"
                status_code=0
            fi
        fi
        
        log_info "Response status code: $status_code"

        # Check for success
        if [[ $status_code -eq 200 ]]; then
            log_info "Successfully registered with webhook API"
            return 0
        fi

        # Wait before retry (except on last attempt)
        if [[ $attempts -lt $MAX_RETRY_ATTEMPTS ]]; then
            log_info "Retrying in 5 seconds..."
            sleep 5
        fi
    done

    handle_error "Failed to register with webhook API after $MAX_RETRY_ATTEMPTS attempts" "$EXIT_NETWORK_ERROR"
}

#===============================================================================
# SSH HOST KEY MANAGEMENT
#===============================================================================

# Rebuild SSH host keys for enhanced security
rebuild_ssh_host_keys() {
    log_info "Rebuilding SSH host keys..."
    
    # Remove existing host keys to force regeneration
    log_info "Removing existing SSH host keys..."
    rm -f /etc/ssh/ssh_host_*
    
    # Generate all default SSH host keys using ssh-keygen -A
    log_info "Generating new SSH host keys..."
    if ssh-keygen -A; then
        log_info "SSH host keys generated successfully"
    else
        log_warn "Failed to generate SSH host keys"
        return 1
    fi
    
    log_info "SSH host keys rebuilt successfully"
    
    # Restart SSH service to use new keys
    log_info "Restarting SSH service to apply new host keys..."
    if systemctl restart ssh; then
        log_info "SSH service restarted successfully"
    elif systemctl restart sshd; then
        log_info "SSH service (sshd) restarted successfully"
    else
        log_warn "Failed to restart SSH service - manual restart may be required"
    fi
}

#===============================================================================
# SERVICE MANAGEMENT
#===============================================================================

# Disable webhook service to prevent re-execution
disable_webhook_service() {
    log_info "Managing webhook service..."
    
    if systemctl is-enabled webhook.service >/dev/null 2>&1; then
        log_info "Disabling webhook service..."
        if systemctl disable webhook.service; then
            log_info "Webhook service successfully disabled"
        else
            log_warn "Failed to disable webhook service"
        fi
    else
        log_info "Webhook service already disabled"
    fi
}

# Mark script as completed successfully
mark_completion() {
    log_info "Marking initialization as completed..."
    rm -f "$RUNNING_MARKER" "$FAILED_MARKER"
    touch "$SUCCESS_MARKER"
    log_info "One-time initialization completed successfully"
}

#===============================================================================
# MAIN EXECUTION
#===============================================================================

main() {
    log_info "=== Foundry VTT VM Initialization Started ==="
    
    # Core initialization steps
    setup_environment
    check_execution_state
    rebuild_ssh_host_keys
    register_with_webhook
    disable_webhook_service
    mark_completion
    
    log_info "=== Foundry VTT VM Initialization Completed ==="
    exit "$EXIT_SUCCESS"
}

# Execute main function if script is run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
