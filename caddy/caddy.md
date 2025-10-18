# Setup and Install Caddy Proxy Server

## Network Setup

```
# This file is generated from information provided by the datasource.  Changes
# to it will not persist across an instance reboot.  To disable cloud-init's
# network configuration capabilities, write a file
# /etc/cloud/cloud.cfg.d/99-disable-network-config.cfg with the following:
# network: {config: disabled}
network:
    version: 2
    ethernets:
        eth0:
            addresses:
            - 192.168.0.x/16
            match:
                macaddress:
            set-name: eth0

        eth1:
            addresses:
            - 199.45.150.7/28
            gateway4: 199.45.150.1
            match:
                macaddress:
            nameservers:
                addresses:
                - 192.168.0.1
                - 1.1.1.1
            set-name: eth1
```

## UFW Installation and configuration

```
apt install ufw -y
```

This configuration will only allow the public ip into this vm on port 80 & 443.

```
# UFW Configuration Script

# Reset UFW to default settings
sudo ufw --force reset

# Set default policies
sudo ufw default deny incoming
sudo ufw default allow outgoing

# Allow connections from 192.168.0.0/16 subnet to any on ports 22 and 4334
sudo ufw allow in on eth0 from 192.168.0.0/16 to any port 22 proto tcp
sudo ufw allow in on eth0 from 192.168.0.0/16 to any port 4334 proto tcp

# Allow incoming connections to ports 80 and 443
sudo ufw allow http
sudo ufw allow https


# Enable the firewall (with force to avoid prompt)
sudo ufw --force enable

# Display status
sudo ufw status verbose
```

## Install

```
apt install -y debian-keyring debian-archive-keyring apt-transport-https curl -y
curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' | sudo gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg
curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' | sudo tee /etc/apt/sources.list.d/caddy-stable.list
apt update
apt install caddy -y

```

## Add Modules

Caddy can support plugin modules. We need clouldflare dns challenge.

```
caddy add-package github.com/caddy-dns/cloudflare

```

## Change caddy service file.

```
systemctl stop caddy
systemctl disable caddy
systemctl enable --now caddy-api

```

## Load initial Config

You will need to take caddy.json and save it as file on the server. Then apply the config via the api so that it will persist

```
curl localhost:2019/load \
	-H "Content-Type: application/json" \
	-d @caddy.json
```

Now you need to confirm the file is loaded. Note the port number change. The default port is now 4334.

```
curl localhost:4334/config/

```

## Cloudflare & Letsencrypt

Caddy will automatically provision pubic certs via letsencrypt. We will use the dns challenge as we want to use a wildcard certificate and dns challenge is the only way to do that. The starting config will have this configuration. You will need to provide a valid cloudflare api token when you deploy this.
