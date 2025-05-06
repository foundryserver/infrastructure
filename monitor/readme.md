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
    scrape_interval: 15s
    static_configs:
      - targets: ['pve0.mgmt.local:9283', 'pve1.mgmt.local:9283']
        labels:
          ceph_cluster: 'Foundry-cluster'

  - job_name: 'idrac'
    static_configs:
      - targets: ['10.90.90.20','10.90.90.21','10.90.90.22','10.90.90.23','10.90.90.24','10.90.90.25','10.90.90.26','10.90.90.27','10.90.90.28']
    relabel_configs:
      - source_labels: [__address__]
        target_label: __param_target
      - source_labels: [__param_target]
        target_label: instance
      - target_label: __address__
        replacement: localhost:9348

  - job_name: 'snmp'
    static_configs:
      - targets: ['pve0.oob.local', 'pve1.oob.local','pve2.oob.local','pve3.oob.local','nfs1.oob.local','nfs2.oob.local','backup1.oob.local','spare0.oob.local','spare1.oob.local']
    metrics_path: /snmp
    params:
      auth: [public_v2]
      module: [dell_idrac]
    relabel_configs:
      - source_labels: [__address__]
        target_label: __param_target
      - source_labels: [__param_target]
        target_label: instance
      - target_label: __address__
        replacement: 127.0.0.1:9116  # The SNMP exporter's real hostname:port.

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

This creates a binary in the folder go/bin/idrac_exporter You will need to move this to /usr/bin and create a systemd file.

```
go install github.com/mrlhansen/idrac_exporter/cmd/idrac_exporter@latest

cp go/bin/idrac_exporter /usr/bin

cat > /etc/systemd/system/idrac-exporter.service << EOF
[Unit]
Description=idrac-exporter
After=network.target

[Service]
Type=simple
User=prometheus
ExecStart=/usr/bin/idrac_exporter
Restart=on-failure

[Install]
WantedBy=multi-user.target

EOF

systemctl daemon-reload
systemctl enable --now idrac-exporter
systemctl status idrac-exporter

```

Setup Scrape Points

```
cat > /etc/prometheus/idrac.yml <<EOF

address: 127.0.0.1 # Listen address
port: 9348         # Listen port
timeout: 10        # HTTP timeout (in seconds) for Redfish API calls
hosts:
  10.90.90.20
    username: exporter
    password: <redacted>
  10.90.90.21
    username: exporter
    password: <redacted>
  10.90.90.22
    username: exporter
    password: <redacted>
  10.90.90.23
    username: exporter
    password: <redacted>
  10.90.90.24
    username: exporter
    password: <redacted>
  10.90.90.25
    username: exporter
    password: <redacted>
  10.90.90.26
    username: exporter
    password: <redacted>
  10.90.90.27
    username: exporter
    password: <redacted>
  10.90.90.28
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

## SNMP Exporter

https://github.com/prometheus/snmp_exporter
https://github.com/billykwooten/idrac_promethus_snmp_module

```
wget https://github.com/prometheus/snmp_exporter/releases/download/v0.29.0/snmp_exporter-0.29.0.linux-amd64.tar.gz
tar -xzf snmp_exporter-0.29.0.linux-amd64.tar.gz
cd snmp_exporter-0.29.0.linux-amd64
cp snmp_exporter /usr/bin
cp snmp.yaml /etc/prometheus/snmp_exporter/


cat > /etc/systemd/system/snmp-exporter.service << EOF
[Unit]
Description=SNMP Exporter
After=network-online.target

# This assumes you are running snmp_exporter under the user "prometheus"

[Service]
User=prometheus
Restart=on-failure
ExecStart=/usr/bin/snmp_exporter --config.file=/etc/prometheus/snmp_exporter/snmp.yml

[Install]
WantedBy=multi-user.target

EOF



systemctl daemon-reload
systemctl enable --now snmp-exporter
systemctl status snmp-exporter


```
