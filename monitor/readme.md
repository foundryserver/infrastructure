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

# Create directory on your data disk (assuming mounted at /data)
sudo mkdir -p /data/influxdb
# Set proper ownership
sudo chown -R influxdb:influxdb /data/influxdb

# Create custom config file
sudo tee /etc/influxdb/config.toml <<EOF
bolt-path = "/data/influxdb/influxd.bolt"
engine-path = "/data/influxdb/engine"
EOF


service influxdb start
systemctl enable influxdb
service influxdb status
```

## Install Grafana

```
sudo apt-get install -y adduser libfontconfig1 musl
wget https://dl.grafana.com/oss/release/grafana_11.5.2_amd64.deb
sudo dpkg -i grafana_11.5.2_amd64.deb

systemctl daemon-reload
systemctl enable  grafana-server
systemctl start  grafana-server
systemctl status grafana-server
```

## Install Prometheus

```
apt-get install prometheus -y
```

Setup data dir

```
mkdir /data/prometheus
chown prometheus:prometheus /data/prometheus
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

systemctl daemon-reload
systemctl enable prometheus
systemctl restart prometheus
systemctl status prometheus
```

Setup Scrape Configs

```
cat > /etc/prometheus/prometheus.yml <<EOF

# Sample config for Prometheus.

global:
  scrape_interval:     30s # Set the scrape interval to every 15 seconds. Default is every 1 minute.
  evaluation_interval: 30s # Evaluate rules every 15 seconds. The default is every 1 minute.
  # scrape_timeout is set to the global default (10s).

  # Attach these labels to any time series or alerts when communicating with
  # external systems (federation, remote storage, Alertmanager).
  external_labels:
      monitor: 'example'

# Alertmanager configuration
alerting:
  alertmanagers:
  - static_configs:
    - targets: ['localhost:9093']

# Load rules once and periodically evaluate them according to the global 'evaluation_interval'.
rule_files:
  # - "first_rules.yml"
  # - "second_rules.yml"

# A scrape configuration containing exactly one endpoint to scrape:
# Here it's Prometheus itself.
scrape_configs:
  # The job name is added as a label `job=<job_name>` to any timeseries scraped from this config.
  - job_name: 'prometheus'

    # Override the global default and scrape targets from this job every 5 seconds.
    scrape_interval: 5s
    scrape_timeout: 5s

    # metrics_path defaults to '/metrics'
    # scheme defaults to 'http'.

    static_configs:
      - targets: ['localhost:9090']

  - job_name: 'ceph'
    honor_labels: true
    scrape_interval: 30s
    static_configs:
      - targets: ['pve0.mgmt.local:9283', 'pve1.mgmt.local:9283','pve2.mgmt.local:9283','pve3.mgmt.local:9283']
        labels:
          ceph_cluster: 'Foundry-cluster'
EOF

systemctl restart prometheus
systemctl status prometheus

```

## Setting Up idrac Redfish API Exporter.

https://github.com/mrlhansen/idrac_exporter?tab=readme-ov-file

Install GO

```
cd ~
wget https://go.dev/dl/go1.24.2.linux-amd64.tar.gz
rm -rf /usr/local/go && tar -C /usr/local -xzf go1.24.2.linux-amd64.tar.gz
export PATH=$PATH:/usr/local/go/bin
```

Compile Exporter

```
go install github.com/mrlhansen/idrac_exporter/cmd/idrac_exporter@latest
```

Setup Scrape Points

```
cat > /etc/prometheus/idrac.yml <<EOF

address: 127.0.0.1 # Listen address
port: 9348         # Listen port
timeout: 10        # HTTP timeout (in seconds) for Redfish API calls
hosts:
  pve0.oob.local:
    username: exporter
    password: <redacted>
  pve1.oob.local:
    username: exporter
    password: <redacted>
  pve2.oob.local:
    username: exporter
    password: <redacted>
  pve3.oob.local:
    username: exporter
    password: <redacted>
  nfs1.oob.local:
    username: exporter
    password: <redacted>
  nfs2.oob.local:
    username: exporter
    password: <redacted>
  backup1.oob.local:
    username: exporter
    password: <redacted>
  spare0.oob.local:
    username: exporter
    password: <redacted>
  spare1.oob.local:
    username: exporter
    password: <redacted>

metrics:
  system: true
  sensors: true
  power: true
  events: true
  storage: true
  memory: true
  network: true

EOF
```
