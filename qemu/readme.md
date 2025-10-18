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

## Fix Reslove for .local domains.

```
mkdir -p /etc/systemd/resolved.conf.d
cat <<EOF > /etc/systemd/resolved.conf.d/forward-local.conf
[Resolve]
DNS=192.168.0.1 1.1.1.1
Domains=~vm.local
EOF
sudo systemctl restart systemd-resolved

```

## User Accounts

```
useradd -m -s /usr/sbin/nologin fvtt

```

## Install Necessary Packages

```
apt update
apt upgrade -y
apt install htop curl nano qemu-guest-agent cron nfs-common jq unattended-upgrades s3cmd zip wireless-regdb -y
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
mkdir -p /home/fvtt/data
mkdir -p /home/fvtt/webdav
chown fvtt:fvtt -R /home/fvtt/*
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

systemctl daemon-reload
systemctl enable --now webdav.service

```

## Create Webhook/bandwidth script file.

1. webhook.sh - this file is located at /home/fvtt/webhook.sh
2. monitor.sh - this file is located at /home/fvtt/monitor.sh

Now set the perms and cron

```

chmod +x /home/fvtt/webhook.sh
chmod +x /home/fvtt/monitor.sh
chown fvtt:fvtt -R /home/fvtt

```

## Setup Cronjob to clean up old log files.

```
crontab -e
0 2 1 * * /usr/bin/find /var/log -name "*.gz" -type f -delete
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
ExecStart=/home/fvtt/webhook.sh

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
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

## we need to run resize2fs /dev/sdb1 every time the vm boots

```
cat <<EOF> /etc/systemd/system/resize-sdb.service
[Unit]
Description=Resize /dev/sdb to fill the disk
DefaultDependencies=no
Before=local-fs-pre.target
Wants=local-fs-pre.target

[Service]
User=root
Group=root
Type=oneshot
ExecStart=/sbin/resize2fs /dev/sdb
RemainAfterExit=yes

[Install]
WantedBy=local-fs.target
EOF
sudo systemctl daemon-reload
sudo systemctl enable resize-sdb.service

```

## Debian Reset VM for templating

```
sudo cloud-init clean --logs --seed
sudo rm -f /etc/ssh/ssh_host*
sudo truncate -s 0 /etc/machine-id
sudo find /var/log -type f -exec truncate -s 0 {} \;
sudo rm -rf /tmp/_
sudo rm -rf /var/tmp/_
sudo rm -f /var/lib/dhcp/*
sudo rm ~/.bash_history
sudo rm /home/fvtt/webhook.success
sudo rm /home/fvtt/webhook.failed
sudo rm /home/fvtt/webhook.running
sudo shutdown -h now
```
