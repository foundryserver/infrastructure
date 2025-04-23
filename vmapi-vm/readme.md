# Setup of Base image for Customer VM

This is the vm instructions for vm-api. We will have two running for redundancy. These vms will have tailscale client installed so that k8s can talk directly to them. We will use proxmox to clone the vms to get them up and running, then use gitlab pipeline to install the application and get it running.

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
            - 192.168.0.6/16
            gateway4: 192.168.0.1
            match:
                macaddress: bc:24:11:52:5f:2b
            nameservers:
                addresses:
                - 192.168.0.1
                - 1.1.1.1
                search:
                - mgmt.local
            set-name: eth0
        eth1:
            addresses:
            - 10.20.10.6/24
            match:
                macaddress: BC:24:11:3A:11:09
            set-name: eth1

```

## Bash Setup

```
echo "alias ll='ls -lah'" >> /etc/bash.bashrc
```

## Install Necessary Packages

```
apt update
apt install htop curl nano qemu-guest-agent -y
apt autoremove -y

```

## Automated Updates

You will need to make changes to the options file for this work as desired.
The netselect will help find the fastest mirror to be used.

```
sudo apt install netselect-apt -y
sudo netselect-apt


sudo apt install unattended-upgrades apt-listchanges -y
sudo dpkg-reconfigure -plow unattended-upgrades

 nano /etc/apt/apt.conf.d/50unattended-upgrades
```

## Setup Podman api

Podman runs a a daemon-less runtime.

```
sudo apt install podman -y
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

## Install and Setup Tailscale client

This will me a dedicated client that k8s can talk to directly. These will not be going through any subnet routing.

```
sudo curl -fsSL https://tailscale.com/install.sh | sh
```

## Configure Routes and start

```
tailscale up --auth-key=<redacted>
```
