#!/bin/bash

# QEMU VM Base Image Setup Script
# Version: 1.0.5
# Description: Automates the setup of base image for customer VM provisioning

set -e

echo "Starting QEMU VM Base Image Setup..."

# Bash Setup
echo "Setting up bash aliases..."
echo "alias ll='ls -lah'" >> /etc/bash.bashrc

# User Accounts
echo "Creating fvtt user account..."
useradd -m -s /usr/sbin/nologin fvtt

# Install Necessary Packages
echo "Updating package lists and installing required packages..."
apt update
apt upgrade -y
apt install htop curl nano qemu-guest-agent cron nfs-common jq unattended-upgrades s3cmd zip wireless-regdb -y
apt autoremove -y

# Automated Updates
echo "Configuring automated updates..."
dpkg-reconfigure --priority=low unattended-upgrades
cat << EOF > /etc/apt/apt.conf.d/50unattended-upgrades
// Unattended-Upgrade::Origins-Pattern controls which packages are
// upgraded.
//

Unattended-Upgrade::Origins-Pattern {
        "origin=Debian,codename=${distro_codename},label=Debian";
        "origin=Debian,codename=${distro_codename},label=Debian-Security";
        "origin=Debian,codename=${distro_codename}-security,label=Debian-Security";

Unattended-Upgrade::Package-Blacklist {};

// Remove unused automatically installed kernel-related packages
// (kernel images, kernel headers and kernel version locked tools).
Unattended-Upgrade::Remove-Unused-Kernel-Packages "true";

// Do automatic removal of newly unused dependencies after the upgrade
Unattended-Upgrade::Remove-New-Unused-Dependencies "true";

// Do automatic removal of unused packages after the upgrade
// (equivalent to apt-get autoremove)
Unattended-Upgrade::Remove-Unused-Dependencies "true";

// Automatically reboot *WITHOUT CONFIRMATION* if
//  the file /var/run/reboot-required is found after the upgrade
Unattended-Upgrade::Automatic-Reboot "true";

// If automatic reboot is enabled and needed, reboot at the specific
// time instead of immediately
//  Default: "now"
Unattended-Upgrade::Automatic-Reboot-Time "03:00";
EOF

# Timezone
echo "Setting timezone to America/Vancouver..."
timedatectl set-timezone America/Vancouver

# Setup Swap
echo "Setting up swap file..."
fallocate -l 2G /swapfile
chmod 600 /swapfile
mkswap /swapfile
swapon /swapfile
echo '/swapfile none swap sw 0 0' | tee -a /etc/fstab

# Create fvtt directories
echo "Creating fvtt directories..."
mkdir -p /home/fvtt/data
mkdir -p /home/fvtt/webdav
chown fvtt:fvtt -R /home/fvtt/*

# Download and install WebDAV binary
echo "Installing WebDAV server..."
wget https://github.com/hacdias/webdav/releases/download/v5.8.0/linux-amd64-webdav.tar.gz
tar -xzf linux-amd64-webdav.tar.gz
mv webdav /usr/bin
rm linux-amd64-webdav.tar.gz

# Create WebDAV config
echo "Creating WebDAV configuration..."
cat << EOF > /home/fvtt/webdav/config.yaml
address: 0.0.0.0
port: 3030
prefix: /
behindProxy: true
directory: /home/fvtt/data/foundrydata
permissions: CRUD
users:
- username: "place#username"
  password: "place#password"
EOF

# Create WebDAV service
echo "Creating WebDAV service..."
cat << EOF > /etc/systemd/system/webdav.service
[Unit]
Description=WebDAV Server
After=network.target

[Service]
Type=simple
User=fvtt
Group=fvtt
ExecStart=/usr/bin/webdav --config /home/fvtt/webdav/config.yaml
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF

systemctl enable --now webdav.service

# Setup log cleanup cronjob
echo "Setting up log cleanup cronjob..."
(crontab -l 2>/dev/null; echo "0 2 1 * * /usr/bin/find /var/log -name \"*.gz\" -type f -delete") | crontab -

# Setup webhook service
echo "Creating webhook service..."
cat << EOF > /etc/systemd/system/webhook.service
[Unit]
Description=One-time webhook script
After=network-online.target
Wants=network-online.target

[Service]
Type=oneshot
ExecStart=/home/fvtt/webhook.sh

[Install]
WantedBy=multi-user.target
EOF

systemctl enable webhook.service

# Install Node.js binary
echo "Installing Node.js..."
cd ~
wget https://nodejs.org/download/release/latest/node-v24.9.0-linux-x64.tar.gz
tar -xzf node-v24.9.0-linux-x64.tar.gz
mv ~/node-v24.9.0-linux-x64/bin/node /usr/bin
rm -rf node-v24.9.0-linux-x64*
node --version
