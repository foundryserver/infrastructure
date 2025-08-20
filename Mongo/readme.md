# Install and Setup of Replicated Mongo db

This will be in a VM on each hypervisor to provide HA. We will be using a stock ubuntu 22.04.3 Release.

## Proxmox VM Settings

## User Accounts

```
usermod -aG sudo brad
echo "brad  ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers
sudo echo "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFK+9vVSQ3PsS5EmZoZDhnwPCl05Z/XdZ8xpG6HijOQX eddsa-key-20230810" > /home/brad/.ssh/authorized_keys
sudo echo "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAII2CPU5hFFykneUVbrBYdGxwBfZfmOnNoQBS704QIq33 eddsa-key-20230916" >> /home/brad/.ssh/authorized_keys
chown -R brad:brad /home/brad/
chmod 700 -R /home/brad/.ssh
chmod 600 /home/brad/.ssh/authorized_keys
```

## Apt Packages

```

sudo apt update
sudo apt upgrade -y
sudo apt-get install gnupg curl qemu-guest-agent atop nano zip unzip htop iputils-ping -y

```

## Setup Keys

```

curl -fsSL https://pgp.mongodb.com/server-7.0.asc | sudo gpg -o /usr/share/keyrings/mongodb-server-7.0.gpg --dearmor
echo "deb [ arch=amd64,arm64 signed-by=/usr/share/keyrings/mongodb-server-7.0.gpg ] https://repo.mongodb.org/apt/ubuntu jammy/mongodb-org/7.0 multiverse" | sudo tee /etc/apt/sources.list.d/mongodb-org-7.0.list

```

## Setup Max_Map_Count

```
cat <<EOF>> /etc/sysctl.conf

# Required for mongo db
vm.max_map_count=128000
EOF
```

## Install Mongo

```

sudo apt update
sudo apt-get install -y mongodb-org
systemctl enable mongod
systemctl start mongod
systemctl status mongod
```

## Configure Mongo for Replication

```

cat << EOF > /etc/mongod.conf

# mongod.conf

# for documentation of all options, see:
#   http://docs.mongodb.org/manual/reference/configuration-options/

# Where and how to store data.
storage:
  dbPath: /var/lib/mongodb


# where to write logging data.
systemLog:
  destination: file
  logAppend: true
  path: /var/log/mongodb/mongod.log

# network interfaces
net:
  port: 27017
  bindIpAll: true


# how the process runs
processManagement:
  timeZoneInfo: /usr/share/zoneinfo

security:
    authorization: disabled

#operationProfiling:

replication:
   replSetName: "rs0"


#sharding:

## Enterprise-Only Options:

#auditLog:

EOF
systemctl restart mongod
systemctl status mongod

```

## Set DNS

Once the 3 vms are created make sure you update hosts file or dns. We assume the following:

- mongo1.vm.foundryserver.com
- mongo2.vm.foundryserver.com
- mongo3.vm.foundryserver.com

Login into any one mongo machine.

### Create the replica set

```

mongosh

rs.initiate( {
_id : "rs0",
members: [
{ _id: 0, host: "mongo1.vm.foundryserver.com:27017" },
{ _id: 1, host: "mongo2.vm.foundryserver.com:27017" },
{ _id: 2, host: "mongo3.vm.foundryserver.com:27017" }
]
})

```

### Validate config

```

rs.conf()

```

### See Status

```

rs.status()

```

## Setup Node Exporter (upgrades as well)

```

sudo systemctl stop nodeexporter.service
sudo wget https://github.com/prometheus/node_exporter/releases/download/v1.6.1/node_exporter-1.6.1.linux-amd64.tar.gz
sudo tar xvfz node_exporter-1.6.1.linux-amd64.tar.gz
cd node_exporter-1.6.1.linux-amd64
sudo chmod +x node_exporter
sudo yes | cp node_exporter /usr/bin
sudo mkdir /etc/node_exporter

# sudo systemctl start nodeexporter.service issue this for upgrades and stop.

sudo cat <<EOF > /etc/systemd/system/nodeexporter.service
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

sudo echo 'OPTIONS="--collector.textfile.directory /var/lib/node_exporter/textfile_collector"' >> /etc/node_exporter/node_exporter.conf
sudo useradd node_exporter --system --no-create-home --shell /usr/sbin/nologin
sudo mkdir -p /var/lib/node_exporter/textfile_collector
sudo chown node_exporter.node_exporter /var/lib/node_exporter/textfile_collector
sudo systemctl enable nodeexporter.service
sudo systemctl start nodeexporter.service

```
