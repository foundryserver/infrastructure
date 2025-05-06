# Setup Ceph on proxmox cluster.

ref: https://www.apalrd.net/posts/2022/cluster_ceph/

Use the gui in proxmox to install ceph on each node in the cluster. You will add only one monitor during the initialization others will be added later.

## Setup Ceph Manager Dashboard.

create self signed cert will fail, however there will be instructions on how to do this in the failure message.

```
apt install ceph-mgr-dashboard
ceph mgr module enable dashboard
ceph dashboard create-self-signed-cert
echo 'alskdflasdfjasj342354lkjdfg' > password.text
ceph dashboard ac-user-create admin -i password.txt administrator
rm password.txt
ceph mgr module disable dashboard
ceph mgr module enable dashboard

```

## Prep OSD drives for use

```
ceph-volume lvm zap /dev/sdX --destroy
```

## Add additional monitor

On each of the remaining nodes, go to ceph and create a monitor. This is done post initialization of the ceph cluster.

## Create Pools.

Each host will have 2 x 1 T ssd drives. We are going to only use one. The second one will not be initialized into ceph, as we don't need the space and we want the second drive to be a cold spare for physical replacement. We will have replication x3 with a min of 2. There will be no fancy configuration of db or wall, they will simply use the osd drives for this functionality.

## Setup Alerting

On any pve host where ceph is is installed and enabled. This will set the cluster wide value.

```
ceph mgr module enable alerts

ceph config set mgr mgr/alerts/smtp_host mail.smtp2go.com
ceph config set mgr mgr/alerts/smtp_destination admin@foundryserver.com
ceph config set mgr mgr/alerts/smtp_sender noreply@foundryserver.com
ceph config set mgr mgr/alerts/smtp_ssl true
ceph config set mgr mgr/alerts/smtp_port 465
ceph config set mgr mgr/alerts/smtp_user ceph
ceph config set mgr mgr/alerts/smtp_password <redacted>
ceph config set mgr mgr/alerts/smtp_from_name 'Ceph Cluster - Foundry 1'
ceph config set mgr mgr/alerts/interval "5m"
```

## Prometheus Monitoring

```
ceph mgr module enable prometheus
ceph config set mgr mgr/prometheus/server_addr 0.0.0.0
ceph config set mgr mgr/prometheus/server_port 9283
ceph config set mgr mgr/prometheus/scrape_interval 15
ceph config set mgr mgr/prometheus/rbd_stats_pools "*"
ceph config set mgr mgr/prometheus/exclude_perf_counters false

```
