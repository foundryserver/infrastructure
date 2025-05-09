# CHANGELOG

1.0.2 May 9, 25 - Initial Entry

================================================================================================================

# Setup of Base image for Customer VM

This is the recipe to create the clone able vm for customer provisioning. You will need to create a template on each proxmox host. Whatever the template vmids are on each node make sure you update the .env file to reflect this.

## Bash Setup

```
echo "alias ll='ls -lah'" >> /etc/bash.bashrc
mkdir /mnt/userdata  #used for nfs transition
```

## Install Necessary Packages

```
apt update
apt install htop curl nano qemu-guest-agent cron nfs-common jq netselect-apt unattended-upgrades apt-listchanges s3cmd -y
apt autoremove -y
```

## Automated Updates

You will need to make changes to the options file for this work as desired.
The netselect will help find the fastest mirror to be used.

# Security updates for stable

deb http://security.debian.org/ bookworm-security main contrib non-free non-free-firmware

```
netselect-apt -n -o /etc/apt/sources.list
# Security updates for stable
echo 'deb http://security.debian.org/ bookworm-security main contrib non-free non-free-firmware' >> /etc/apt/sources.list

sudo dpkg-reconfigure -plow unattended-upgrades

nano /etc/apt/apt.conf.d/50unattended-upgrades
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
fallocate -l 4G /swapfile
chmod 600 /swapfile
mkswap /swapfile
swapon /swapfile
echo '/swapfile none swap sw 0 0' | tee -a /etc/fstab
```

## Create fvtt user and service file.

```
sudo adduser --uid 2000 --shell=/usr/sbin/nologin --disabled-password fvtt
mkdir -p /home/fvtt/foundrydata/{Config,Logs,Data}
mkdir -p /home/fvtt/foundrycore
mkdir -p /home/fvtt/webdav
```

## Create the default webdav config and service file

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
```

```
cat << EOF > /etc/systemd/system/webdav.service
[Unit]
Description=WebDAV
After=network.target

[Service]
Environment="WD_USERNAME=admin-foundry" 'WD_PASSWORD="<REDACTED>"'
Type=simple
User=fvtt
Group=fvtt
ExecStart=/usr/bin/webdav --config /home/fvtt/webdav/config.yaml
Restart=on-failure

[Install]
WantedBy=multi-user.target

EOF

```

## Create the default options.json file.

```
cat <<EOF > /home/fvtt/foundrydata/Config/options.json
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
    "dataPath": "/home/fvtt/foundrydata/",
    "proxySSL": false,
    "proxyPort": 443,
    "world": null,
    "isElectron": false,
    "isNode": true,
    "isSSL": true,
    "background": false,
    "debug": false,
    "demo": false,
    "serviceConfig": "/home/fvtt/foundrycore/foundryserver.json",
    "updateChannel": "release"
}
EOF
```

## Create Webhook/bandwidth script file.

1. webhook.sh - this file is located at /etc/init.d/webhook.sh
2. bandwidth.sh - this file is located at /home/fvtt/bandwidth.sh
3. reset_iptables.sh - this file is located at /home/fvtt/reset_iptables.sh
4. setup_cron.sh - this file is located at /root
5. dev/prod - this file is located at /home/fvtt/{dev:prod}

Now set the perms and cron

```
chmod +x /etc/init.d/webhook.sh
chmod +x /home/fvtt/bandwidth.sh
chmod +x /home/fvtt/reset_iptables.sh
touch /home/fvtt/{dev:prod}
chown fvtt:fvtt -R /home/fvtt
```

## Install Nodejs binary

```
cd ~
wget https://nodejs.org/download/release/latest/node-v24.0.0-linux-x64.tar.gz
tar -xzf node-v24.0.0-linux-x64.tar.gz
mv ~/node-v24.0.0-linux-x64/bin/node /usr/bin
rm -rf node-v24.0.0-linux-x64*
node --version
```

## Debian Reset VM for templating

```
# Clean Cloud-Init data
sudo cloud-init clean --logs --seed

# Remove SSH host keys
sudo rm -f /etc/ssh/ssh_host_*

# Clear machine identifiers
truncate -s 0 /etc/machine-id

# Clean logs and temporary files
sudo find /var/log -type f -exec truncate -s 0 {} \;
sudo rm -rf /tmp/*
sudo rm -rf /var/tmp/*

# Remove DHCP leases
sudo dhclient -r
sudo rm -f /var/lib/dhcp/*

# Clear network configuration (Optional)
sudo rm -f /etc/network/interfaces.d/*
sudo rm -f /etc/netplan/*

sudo rm ~/.bash_history

sudo rm -rf /home/fvtt/foundrycore/*

# Shutdown the VM
sudo shutdown -h now
```
