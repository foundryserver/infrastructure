# Setup of Base image for Customer VM

This is the recipe to create the clone able vm for customer provisioning. You will need to create a template on each proxmox host. Whatever the template vmids are on each node make sure you update the .env file to reflect this. This vm will need to be a single partition no swap partition. The swap will be a file on the main partition.

## Boot Strap

You will need to come into the vm via the proxmox shell for the vm. Login as root and then Install these packages. The key one is sudo. You will then need to add the manager user to the sudo group so you can ssh into and continue the build.

```
apt install sudo -y
nano /etc/group   #( sudo:x:27:manager)
ip a # to get dhcp ip to ssh in
```

Now ssh into vm with user manager and then sudo to root to complete the install.

## User Accounts

Need to update the manager user that is added during the install process.

```
# usermod -aG sudo manager  (this is done in the boot strap phase)
echo "manager  ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers
mkdir /home/manager/.ssh
sudo echo "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILXC8ewQSURYdaH6TWS0/Pv6KGY2tYap7t1eAizeQjKY brad@dev1" > /home/manager/.ssh/authorized_keys
sudo echo "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFK+9vVSQ3PsS5EmZoZDhnwPCl05Z/XdZ8xpG6HijOQX common-jan25" >> /home/manager/.ssh/authorized_keys
chown -R manager:manager /home/manager/
chmod 700 -R /home/manager/.ssh
chmod 600 /home/manager/.ssh/authorized_keys
```

Setup fvtt user account.

```
useradd -m -s /usr/sbin/nologin fvtt

```

## Install Necessary Packages

```
apt update
apt upgrade -y
apt install htop curl nano qemu-guest-agent cron nfs-common jq unattended-upgrades s3cmd zip iptables -y
apt autoremove -y
```

## Edit Grub to speed up boot

```
cat <<EOF > /etc/default/grub
GRUB_DEFAULT=0
GRUB_TIMEOUT=0
GRUB_DISTRIBUTOR=`( . /etc/os-release && echo ${NAME} )`
GRUB_CMDLINE_LINUX_DEFAULT="quiet"
GRUB_CMDLINE_LINUX=""
GRUB_DISABLE_OS_PROBER=true
#GRUB_BADRAM="0x01234567,0xfefefefe,0x89abcdef,0xefefefef"
GRUB_DISABLE_RECOVERY="true"
GRUB_TIMEOUT_STYLE=hidden
EOF
update-grub

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

## Setup Swap

```
fallocate -l 1.7G /swapfile
chmod 600 /swapfile
mkswap /swapfile
swapon /swapfile
echo '/swapfile none swap sw 0 0' | tee -a /etc/fstab
```

## Mount Data rbd drive

It is important to note that we are not creating any partitions on this data drive. This makes expanding
the disk very easy as we are not dealing with partitions. so we can just run resize2fs and life is good.
We get the UUID from blkid for sdb and then use that to make the fstab entry.

```
# Get the UUID and store it in a variable
UUID=$(sudo blkid -s UUID -o value /dev/sdb)

# Add entry to fstab (replace /home/fvtt/data with your desired mount point)
echo "UUID=$UUID /home/fvtt/data ext4 defaults 0 2" | sudo tee -a /etc/fstab

# format the drive
mkfs.ext4 /home/fvtt/data
```

## Create fvtt user and service file.

```
mkdir -p /home/fvtt/data/foundrydata/{Config,Data,Logs}
mkdir -p /home/fvtt/data/foundrycore
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
*/5 * * * * /home/fvtt/monitor.sh >/dev/null 2>&1
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
wget https://nodejs.org/download/release/latest/node-v25.0.0-linux-x64.tar.gz
tar -xzf node-v25.0.0-linux-x64.tar.gz
mv ~/node-v25.0.0-linux-x64/bin/node /usr/bin
rm -rf node-*
node --version

```

## we need to run resize2fs /dev/sdb1 every time the vm boots

```
cat <<EOF> /etc/systemd/system/resize-sdb.service
[Unit]
Description=Resize /dev/sdb and filesystem to fill the disk
DefaultDependencies=no
Before=local-fs-pre.target
Wants=local-fs-pre.target

[Service]
User=root
Group=root
Type=oneshot
ExecStart=/usr/sbin/resize2fs /dev/sdb
RemainAfterExit=yes

[Install]
WantedBy=local-fs.target
EOF
sudo systemctl daemon-reload
sudo systemctl enable resize-sdb.service

```

## Debian Reset VM for templating

```
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
