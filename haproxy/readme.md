# Create and Setup Haproxy for K8s HA

This is a debian based lxc container with haproxy installed. This container should be unprivileged as we don't need to access lower ports.

## Proxmox Configuration

CPU: 1
Ram: 512M
HDD: 3G on vm_pool
Template: Debian 12
Net0: vmbr0 tag 20 10.20.20.199/42
Net1: vmbr0 tag 10 10.20.10.199/42

## Haproxy Setup

Install:

```
apt update
apt upgrade -y
apt install haproxy
```

Stop Process:

```
systemctl stop haproxy
```

Configuration:

```
cat <<EOF > /etc/haproxy/haproxy.cfg
global
    log /dev/log    local0
    log /dev/log    local1 notice
    chroot /var/lib/haproxy
    stats socket /run/haproxy/admin.sock mode 660 level admin
    stats timeout 30s
    user haproxy
    group haproxy
    daemon

defaults
    log     global
    mode    http
    option  httplog
    option  dontlognull
    timeout connect 5000
    timeout client  50000
    timeout server  50000

frontend kubeAPI
    bind :6443
    mode tcp
    default_backend kubeAPI_backend

frontend konnectivity
    bind :8132
    mode tcp
    default_backend konnectivity_backend

frontend controllerJoinAPI
    bind :9443
    mode tcp
    default_backend controllerJoinAPI_backend

frontend emailAPI
    bind :31001
    mode tcp
    default_backend emailAPI_backend

frontend errorAPI
    bind :31000
    mode tcp
    default_backend errorAPI_backend

frontend proxmoxAPI
    bind :8006
    mode tcp
    default_backend proxmoxAPI_backend

backend kubeAPI_backend
    mode tcp
    server k0s-controller1 10.20.20.200:6443 check check-ssl verify none
    server k0s-controller2 10.20.20.201:6443 check check-ssl verify none
    server k0s-controller3 10.20.20.202:6443 check check-ssl verify none

backend konnectivity_backend
    mode tcp
    server k0s-controller1 10.20.20.200:8132 check check-ssl verify none
    server k0s-controller2 10.20.20.201:8132 check check-ssl verify none
    server k0s-controller3 10.20.20.202:8132 check check-ssl verify none

backend controllerJoinAPI_backend
    mode tcp
    server k0s-controller1 10.20.20.200:9443 check check-ssl verify none
    server k0s-controller2 10.20.20.201:9443 check check-ssl verify none
    server k0s-controller3 10.20.20.202:9443 check check-ssl verify none

backend emailAPI_backend
    mode tcp
    server k0s-worker1 10.20.20.203:31001 check verify none
    server k0s-worker2 10.20.20.204:31001 check verify none
    server k0s-worker3 10.20.20.205:31001 check verify none

backend errorAPI_backend
    mode tcp
    server k0s-worker1 10.20.20.203:31000 check verify none
    server k0s-worker2 10.20.20.204:31000 check verify none
    server k0s-worker3 10.20.20.205:31000 check verify none

backend proxmoxAPI_backend
    mode tcp
    server pve0 10.20.10.20:8006 check check-ssl verify none sni str(pve0.mgmt.local)
    server pve1 10.20.10.21:8006 check check-ssl verify none sni str(pve1.mgmt.local)
    server pve2 10.20.10.22:8006 check check-ssl verify none sni str(pve2.mgmt.local)
    server pve3 10.20.10.28:8006 check check-ssl verify none sni str(pve3.mgmt.local)


listen stats
   bind *:9000
   mode http
   stats enable
   stats uri /
EOF
```

Start Haproxy:

```
systemctl restart haproxy
```
