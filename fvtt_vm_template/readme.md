# CHANGELOG

1.0.2 May 9, 25 - Initial Entry
1.0.5 June 14, 25 - Added zip binary

================================================================================================================

# Setup of Base image for Customer VM

This is the recipe to create the clone able vm for customer provisioning. You will need to create a template on each proxmox host. Whatever the template vmids are on each node make sure you update the .env file to reflect this.

## Bash Setup

```
echo "alias ll='ls -lah'" >> /etc/bash.bashrc
```

## User Accounts

```
useradd -m -s /bin/bash -p $(openssl passwd -1 '') admin
usermod -aG sudo admin
echo "admin  ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers
chown -R admin:admin /home/admin/
chmod 700 -R /home/admin/.ssh
chmod 600 /home/admin/.ssh/authorized_keys
```

## Install Necessary Packages

```
apt update
apt upgrade -y
apt install htop curl nano qemu-guest-agent cron nfs-common jq unattended-upgrades s3cmd zip -y
apt autoremove -y
```

## Automated Updates

```
dpkg-reconfigure --priority=low unattended-upgrades
nano /etc/apt/apt.conf.d/50unattended-upgrades
unattended-upgrade --dry-run --debug
```

## Timezone

```
timedatectl set-timezone America/Vancouver
```

## Set sshd Config file.

```
cat <<EOF > /etc/ssh/sshd_config
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
```

## Setup Swap

```
fallocate -l 2G /swapfile
chmod 600 /swapfile
mkswap /swapfile
swapon /swapfile
echo '/swapfile none swap sw 0 0' | tee -a /etc/fstab
```

## Create fvtt user and service file.

```
mkdir -p /home/fvtt/foundrydata
mkdir -p /home/fvtt/foundrycore
mkdir -p /home/fvtt/webdav
```

## Create the default webdav config and service file

Download binary and install

```
wget https://github.com/hacdias/webdav/releases/download/v5.8.0/linux-amd64-webdav.tar.gz
tar -xzf linux-amd64-webdav.tar.gz
mv webdav /usr/bin
rm linux-amd64-webdav.tar.gz
```

```
cat << EOF > /home/fvtt/webdav/config.yaml

# Listen ip and port

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

directory: /home/fvtt/foundrydata

# The default permissions for users. This is a case insensitive option. Possible

# permissions: C (Create), R (Read), U (Update), D (Delete). You can combine multiple

# permissions. For example, to allow to read and create, set "RC". Default is "R".

permissions: CRUD

# The list of users. If the list is empty, then there will be no authentication.

# Otherwise, basic authentication will automatically be configured.

#

users:

- username: "place#username"
  password: "place#password"
  EOF

```

```

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

```

## Create Webhook/bandwidth script file.

1. webhook.sh - this file is located at /home/admin/webhook.sh
2. bandwidth.sh - this file is located at /home/admin/bandwidth.sh
3. reset_iptables.sh - this file is located at /home/admin/reset_iptables.sh
4. setup_cron.sh - this file is located at /root

Now set the perms and cron

```

chmod +x /home/admin/webhook.sh
chmod +x /home/admin/bandwidth.sh
chmod +x /home/admin/reset_iptables.sh
chown admin:admin -R /home/admin

```

## Setup webhook

```

cat << EOF > /etc/systemd/system/webhook.service
[Unit]
Description=One-time webhook script
After=network-online.target
Wants=network-online.target

[Service]
Type=oneshot
ExecStart=/home/admin/webhook.sh

[Install]
WantedBy=multi-user.target
EOF

systemctl enable webhook.service

```

## Install Nodejs binary

```

cd ~
wget https://nodejs.org/download/release/latest/node-v24.9.0-linux-x64.tar.gz
tar -xzf node-v24.9.0-linux-x64.tar.gz
mv ~/node-v24.9.0-linux-x64/bin/node /usr/bin
rm -rf node-v24.9.0-linux-x64\*
node --version

```

## Debian Reset VM for templating

```

# Clean Cloud-Init data

sudo cloud-init clean --logs --seed

# Remove SSH host keys

sudo rm -f /etc/ssh/ssh_host*

# Clear machine identifiers

truncate -s 0 /etc/machine-id

# Clean logs and temporary files

sudo find /var/log -type f -exec truncate -s 0 {} \;
sudo rm -rf /tmp/_
sudo rm -rf /var/tmp/_

# Remove DHCP leases

sudo dhclient -r
sudo rm -f /var/lib/dhcp/*

sudo rm ~/.bash_history

# Shutdown the VM

sudo shutdown -h now

```
