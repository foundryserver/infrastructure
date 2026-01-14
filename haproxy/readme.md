# Create and Setup Haproxy for K8s HA

This is a debian based lxc container with haproxy installed. This container should be unprivileged as we don't need to access lower ports.

## Proxmox Configuration

CPU: 1
Ram: 512M
HDD: 3G on vm_pool
Template: Debian 12
Net0: vmbr0 tag 20 10.20.20.200/24
Net1: vmbr1 tag 10 10.20.30.200/24

## Haproxy Setup

Install:

```
apt update
apt upgrade -y
apt install haproxy ufw -y
```

Stop Process:

```
systemctl stop haproxy
```
