# Create and Setup Haproxy for K8s HA

This is a debian based lxc container with haproxy installed. This container should be unprivileged as we don't need to access lower ports.

## Proxmox Configuration

CPU: 1
Ram: 512M
HDD: 3G on vm_pool
Template: Debian 12
Net: vmbr0 tag 20

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

backend kubeAPI_backend
    mode tcp
    server k0s-controller1 10.20.20.xxx:6443 check check-ssl verify none
    server k0s-controller2 10.20.20.xxx:6443 check check-ssl verify none
    server k0s-controller3 10.20.20.xxx:6443 check check-ssl verify none

backend konnectivity_backend
    mode tcp
    server k0s-controller1 10.20.20.xxx:8132 check check-ssl verify none
    server k0s-controller2 10.20.20.xxx:8132 check check-ssl verify none
    server k0s-controller3 10.20.20.xxx:8132 check check-ssl verify none

backend controllerJoinAPI_backend
    mode tcp
    server k0s-controller1 10.20.20.xxx:9443 check check-ssl verify none
    server k0s-controller2 10.20.20.xxx:9443 check check-ssl verify none
    server k0s-controller3 10.20.20.xxx:9443 check check-ssl verify none

listen stats
   bind *:9000
   mode http
   stats enable
   stats uri /
EOF
```

Start Haproxy:

```
systemctl start haproxy
```
