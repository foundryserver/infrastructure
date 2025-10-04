# Template for Customer LXC Container

This template is based on the Debian 12 Linux distribution. The goal is for something small, fast and simple. Proxmox has a base template for Alpine that we will add to customize for our needs.

## File Storage Layout

The container will have 2 filesystems. This will provide max flexibility and storage efficiency.

rootfs - / - Proxmox ceph rbd (vm_pool) 3 GB
user game data - /foundrydata - Proxmox ceph rbd (vm_pool) 5-75 GB

## Packages installed.

```
apt update
apt upgrade -y
apt install curl wget nano htop -y
apt autoremove -y
```

## Setup Alias & Environment

```
echo "alias ll='ls -lah'" >> /etc/bash.bashrc

```

## Clean up Unnessary Processes

```
systemctl stop postfix
systemctl disable postfix
```

## Install Nodejs binary

```
cd ~
wget https://nodejs.org/download/release/latest/node-v24.7.0-linux-x64.tar.gz
tar -xzf node-v24.7.0-linux-x64.tar.gz
mv ~/node-v24.7.0-linux-x64/bin/node /usr/bin
rm -rf node-v24.7.0-linux-x64*
node --version
```

## Timezone

```
echo "America/Vancouver" | tee /etc/timezone
ln -sf /usr/share/zoneinfo/America/Vancouver /etc/localtime
dpkg-reconfigure -f noninteractive tzdata
```

## Set sshd Config file.

```
cat <<EOF > /etc/ssh/sshd_config
Include /etc/ssh/sshd*config.d/*.conf
PermitRootLogin prohibit-password
PasswordAuthentication no
ChallengeResponseAuthentication no
UsePAM yes
X11Forwarding no
PrintMotd no
AcceptEnv LANG LC_*
# Subsystem sftp /usr/lib/openssh/sftp-server
EOF
systemctl restart ssh
```

## Basic Container layout with appropriate mounts.

This is what the proxmox lxc will look like when it is configured appropriately. Keep in mind the values are changed dependant on the plan level chosen.

```
arch: amd64
cores: 1
cpulimit: 0.25
hostname: lxc-template
memory: 1536
mp0: vm_pool:vm-5000-disk-1,mp=/foundrydata,backup=1,size=3G
nameserver: 192.168.0.1 1.1.1.1
net0: name=eth0,bridge=vmbr0,hwaddr=BC:24:11:C6:A2:5F,ip=dhcp,tag=20,type=veth
ostype: debian
rootfs: vm_pool:vm-5000-disk-0,size=8G
swap: 1024
unprivileged: 1
```

## Create the default webdav config and service file

The webdav server we are using is located at https://github.com/hacdias/webdav. To install just download the binary and add it to /usr/bin/

```
cd ~
wget https://github.com/hacdias/webdav/releases/download/v5.8.0/linux-amd64-webdav.tar.gz
tar -zxf linux-amd64-webdav.tar.gz
mv webdav /usr/bin/
rm linux-amd64-webdav.tar.gz
```

```
mkdir /etc/webdav
cat << EOF > /etc/webdav/config.yaml
address: 0.0.0.0
port: 3030
prefix: /
behindProxy: true
directory: /foundrydata
permissions: CRUD
users:
- username: "place_username99"
  password: "place_password99"
EOF
```

```
cat << EOF > /etc/systemd/system/webdav.service
[Unit]
Description=WebDAV
After=network.target

[Service]
Type=simple
User=root
Group=root
ExecStart=/usr/bin/webdav --config /etc/webdav/config.yaml
Restart=on-failure

[Install]
WantedBy=multi-user.target

EOF

systemctl daemon-reload
systemctl enable webdav
systemctl start webdav
```

## Node Exporter

```
systemctl stop nodeexporter.service
wget https://github.com/prometheus/node_exporter/releases/download/v1.9.1/node_exporter-1.9.1.linux-amd64.tar.gz
tar xvfz node_exporter-1.9.1.linux-amd64.tar.gz
cd node_exporter-1.9.1.linux-amd64
chmod +x node_exporter
yes | cp node_exporter /usr/bin
mkdir /etc/node_exporter

# systemctl start node-exporter.service issue this for upgrades and stop.

cat <<EOF > /etc/systemd/system/node-exporter.service
[Unit]
Description=Node Exporter

[Service]
User=node_exporter
EnvironmentFile=/etc/node_exporter/node_exporter.conf
ExecStart=/usr/bin/node_exporter \$OPTIONS
Restart=always

[Install]
WantedBy=multi-user.target
EOF

echo 'OPTIONS="--collector.textfile.directory /var/lib/node_exporter/textfile_collector"' >> /etc/node_exporter/node_exporter.conf
useradd node_exporter --system --no-create-home --shell /usr/sbin/nologin
mkdir -p /var/lib/node_exporter/textfile_collector
chown node_exporter:node_exporter /var/lib/node_exporter/textfile_collector
systemctl daemon-reload
systemctl enable node-exporter.service
systemctl start node-exporter.service

```

## Unattended Upgrades

```

apt install -y unattended-upgrades
cat <<EOF > /etc/apt/apt.conf.d/50unattended-upgrades
Unattended-Upgrade::Origins-Pattern {
"origin=Debian,codename=${distro_codename},label=Debian";
    "origin=Debian,codename=${distro_codename},label=Debian-Security";
    "origin=Debian,codename=${distro_codename}-security,label=Debian-Security";
};
Unattended-Upgrade::Allowed-Origins {
    "${distro_id}:${distro_codename}-security";
    "${distro_id}:${distro_codename}-updates";
};
Unattended-Upgrade::Automatic-Reboot "true";
Unattended-Upgrade::Automatic-Reboot-Time "03:00";

EOF

cat <<EOF > /etc/apt/apt.conf.d/20auto-upgrades
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Unattended-Upgrade "1";
APT::Periodic::AutocleanInterval "7";
APT::Periodic::Unattended-Upgrade "1";
EOF

```

## Setup Webhook

We need to run a bash script to report back to vmapi the ip address of this container. Once that has happened then vmapi will make some changes to the container and get the fvtt to start running. Here is the systemd file. Put the webhook.sy file is the roots home dir. Make it executable.

```
cat << EOF>  /etc/systemd/system/webhook.service
[Unit]
Description=One-time webhook script
After=network-online.target
Wants=network-online.target

[Service]
Type=oneshot
User=root
Group=root
ExecStart=/root/webhook.sh
ExecStopPost=/bin/systemctl disable webhook.service

[Install]
WantedBy=multi-user.target

EOF
systemctl daemon-reload
systemctl enable webhook

```

## Debian Reset VM for templating

```

# Remove SSH host keys (they will regenerate on first boot)

rm -f /etc/ssh/ssh*host*\*

# Clear machine ID
truncate -s 0 /etc/machine-id
rm -f /var/lib/dbus/machine-id
ln -s /etc/machine-id /var/lib/dbus/machine-id

# Clean apt cache
apt clean
rm -rf /var/lib/apt/lists/\*

# Clear logs
find /var/log -type f -exec truncate -s 0 {} \;
rm -rf /tmp/_
rm -rf /var/tmp/_

# (Optional) Remove bash history
rm -f /root/.bash_history


```

## Build os template from .raw file

### Dev Template

```
losetup -fP /var/lib/vz/images/5010/vm-5010-disk-0.raw
mkdir /mnt/temp
mount /dev/loop0 /mnt/temp
echo "NODE_ENV=dev" >> /mnt/temp/etc/environment
tar --numeric-owner --owner=0 --group=0 -czf /mnt/pve/cephfs/template/cache/debian13-custom-$(date +%Y%m%d)-dev.tar.gz -C /mnt/temp/ .
umount /mnt/temp
losetup -d /dev/loop0
rmdir /mnt/temp
echo "Make sure you edit the .env files with the new template name of: debian13-custom-$(date +%Y%m%d)-dev.tar.gz"
```

### PROD Template

```
losetup -fP /var/lib/vz/images/5010/vm-5010-disk-0.raw
mkdir /mnt/temp
mount /dev/loop0 /mnt/temp
echo "NODE_ENV=prod" >> /mnt/temp/etc/environment
tar --numeric-owner --owner=0 --group=0 -czf /mnt/pve/cephfs/template/cache/debian13-custom-$(date +%Y%m%d)-prod.tar.gz -C /mnt/temp/ .
umount /mnt/temp
losetup -d /dev/loop0
rmdir /mnt/temp
echo "Make sure you edit the .env files with the new template name of: debian13-custom-$(date +%Y%m%d)-prod.tar.gz"
```
