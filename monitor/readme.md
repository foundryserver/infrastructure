# Monitor Install and Setup

This vm will take care of all the monitoring for the site. It will have a boot drive that is located on the local hdd, and the data drive will be on a separate disk on the host. The goal is to keep it off the ceph cluster as we don't need the replication and all the overhead that would cause. No point it using up all the ssd capacity.

## Add Packages.

```
apt update
apt install curl wget sudo htop atop zip unzip cron xfsprogs gpg -y
```

## Add shell alias

```
timedatectl set-timezone America/Vancouver
echo "alias ll='ls -lah'" >> /etc/bash.bashrc
```

## User Setup

The working user will be added when the install happens. We just need to modify it afterwards to make it use ssh etc.

```
gpasswd -a brad sudo
echo "brad  ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers
mkdir /home/brad/.ssh
echo "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFK+9vVSQ3PsS5EmZoZDhnwPCl05Z/XdZ8xpG6HijOQX common-jan25" >> /home/brad/.ssh/authorized_keys
chmod 700 -R /home/brad/.ssh
chmod 600 /home/brad/.ssh/authorized_keys
chown -R brad:brad /home/brad/
```

## Setup Data Disk

```
echo -e "nn\np\n1\n\n\nw" | fdisk /dev/sdb
mkdir /data
mount -t xfs /dev/sdb1 /data
echo "/dev/sdb1  /data  xfs  defaults,noatime  0 2" | sudo tee -a /etc/fstab
```

## Install Influx db v2

```
# Ubuntu and Debian
# Add the InfluxData key to verify downloads and add the repository
curl --silent --location -O \
https://repos.influxdata.com/influxdata-archive.key
echo "943666881a1b8d9b849b74caebf02d3465d6beb716510d86a39f6c8e8dac7515  influxdata-archive.key" \
| sha256sum --check - && cat influxdata-archive.key \
| gpg --dearmor \
| tee /etc/apt/trusted.gpg.d/influxdata-archive.gpg > /dev/null \
&& echo 'deb [signed-by=/etc/apt/trusted.gpg.d/influxdata-archive.gpg] https://repos.influxdata.com/debian stable main' \
| tee /etc/apt/sources.list.d/influxdata.list
# Install influxdb
apt-get update && apt-get install influxdb2 -y

service influxdb start
service influxdb status
```

## Install Grafana

```
sudo apt-get install -y adduser libfontconfig1 musl
wget https://dl.grafana.com/oss/release/grafana_11.5.2_amd64.deb
sudo dpkg -i grafana_11.5.2_amd64.deb

systemctl enable  grafana-server
systemctl start  grafana-server

```

## Install Prometheus

```
apt-get install prometheus -y
```

This will set the data drive and retention

```
cat <<EOF> /lib/systemd/system/prometheus.service
[Unit]
Description=Monitoring system and time series database
Documentation=https://prometheus.io/docs/introduction/overview/ man:prometheus(1)
After=time-sync.target

[Service]
Restart=on-failure
User=prometheus
EnvironmentFile=/etc/default/prometheus
ExecStart=/usr/bin/prometheus $ARGS \
  --storage.tsdb.path=/data/prometheus \
  --storage.tsdb.retention.time=30d \
  --storage.tsdb.retention.size=50GB
ExecReload=/bin/kill -HUP $MAINPID
TimeoutStopSec=20s
SendSIGKILL=no

# systemd hardening-options
AmbientCapabilities=
CapabilityBoundingSet=
DeviceAllow=/dev/null rw
DevicePolicy=strict
LimitMEMLOCK=0
LimitNOFILE=32768
LockPersonality=true
MemoryDenyWriteExecute=true
NoNewPrivileges=true
PrivateDevices=true
PrivateTmp=true
PrivateUsers=true
ProtectControlGroups=true
ProtectHome=true
ProtectKernelModules=true
ProtectKernelTunables=true
ProtectSystem=full
RemoveIPC=true
RestrictNamespaces=true
RestrictRealtime=true
SystemCallArchitectures=native

[Install]
WantedBy=multi-user.target
EOF
```
