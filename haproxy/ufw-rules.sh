#!/bin/bash

# UFW rules for HAProxy configuration
# Based on analysis of haproxy.cfg

echo "Setting up UFW rules for HAProxy configuration..."

# Reset UFW to default state
sudo ufw --force reset

# Set default policies
sudo ufw default deny incoming
sudo ufw default allow outgoing

# Allow SSH (port 22) - Essential for remote management
sudo ufw allow 22/tcp comment "SSH"

# Allow ICMP (ping) - for network diagnostics
sudo ufw allow in proto icmp comment "ICMP incoming (ping responses)"
sudo ufw allow out proto icmp comment "ICMP outgoing (ping requests)"

# Frontend ports that HAProxy listens on (incoming traffic)
echo "Allowing HAProxy frontend ports..."

# Kubernetes API Server
sudo ufw allow 6443/tcp comment "Kubernetes API (kubeAPI frontend)"

# Konnectivity service
sudo ufw allow 8132/tcp comment "Konnectivity (konnectivity frontend)"

# Controller Join API
sudo ufw allow 9443/tcp comment "Controller Join API (controllerJoinAPI frontend)"

# Error API
sudo ufw allow 31000/tcp comment "Error API (errorAPI frontend)"

# Email API
sudo ufw allow 31001/tcp comment "Email API (emailAPI frontend)"

# VM API
sudo ufw allow 31002/tcp comment "VM API (vmAPI frontend)"

# Proxmox API
sudo ufw allow 8006/tcp comment "Proxmox API (proxmoxAPI frontend)"

# HAProxy stats page
sudo ufw allow 9000/tcp comment "HAProxy stats"

# Backend connections (outgoing to specific IPs)
echo "Allowing outgoing connections to backend servers..."

# Allow outgoing to Kubernetes controllers (10.20.20.200-202)
sudo ufw allow out to 10.20.20.200 port 6443 comment "k0s-controller1 kubeAPI"
sudo ufw allow out to 10.20.20.200 port 8132 comment "k0s-controller1 konnectivity"
sudo ufw allow out to 10.20.20.200 port 9443 comment "k0s-controller1 controllerJoin"

sudo ufw allow out to 10.20.20.201 port 6443 comment "k0s-controller2 kubeAPI"
sudo ufw allow out to 10.20.20.201 port 8132 comment "k0s-controller2 konnectivity"
sudo ufw allow out to 10.20.20.201 port 9443 comment "k0s-controller2 controllerJoin"

sudo ufw allow out to 10.20.20.202 port 6443 comment "k0s-controller3 kubeAPI"
sudo ufw allow out to 10.20.20.202 port 8132 comment "k0s-controller3 konnectivity"
sudo ufw allow out to 10.20.20.202 port 9443 comment "k0s-controller3 controllerJoin"

# Allow outgoing to Kubernetes workers (10.20.20.203-205)
sudo ufw allow out to 10.20.20.203 port 31000 comment "k0s-worker1 errorAPI"
sudo ufw allow out to 10.20.20.203 port 31001 comment "k0s-worker1 emailAPI"
sudo ufw allow out to 10.20.20.203 port 31002 comment "k0s-worker1 vmAPI"

sudo ufw allow out to 10.20.20.204 port 31000 comment "k0s-worker2 errorAPI"
sudo ufw allow out to 10.20.20.204 port 31001 comment "k0s-worker2 emailAPI"
sudo ufw allow out to 10.20.20.204 port 31002 comment "k0s-worker2 vmAPI"

sudo ufw allow out to 10.20.20.205 port 31000 comment "k0s-worker3 errorAPI"
sudo ufw allow out to 10.20.20.205 port 31001 comment "k0s-worker3 emailAPI"
sudo ufw allow out to 10.20.20.205 port 31002 comment "k0s-worker3 vmAPI"

# Allow outgoing to Proxmox servers (10.20.10.20-22, 10.20.10.28)
sudo ufw allow out to 10.20.10.20 port 8006 comment "pve0 proxmox"
sudo ufw allow out to 10.20.10.21 port 8006 comment "pve1 proxmox"
sudo ufw allow out to 10.20.10.22 port 8006 comment "pve2 proxmox"
sudo ufw allow out to 10.20.10.28 port 8006 comment "pve3 proxmox"

# Allow DNS (needed for health checks and general operation)
sudo ufw allow out 53 comment "DNS"

# Allow NTP (for time synchronization)
sudo ufw allow out 123 comment "NTP"

# Enable UFW
sudo ufw --force enable

echo "UFW rules applied successfully!"
echo ""
echo "Summary of allowed ports:"
echo "Incoming:"
echo "  - 22/tcp (SSH)"
echo "  - ICMP (ping responses)"
echo "  - 6443/tcp (Kubernetes API)"
echo "  - 8132/tcp (Konnectivity)"
echo "  - 9443/tcp (Controller Join API)"
echo "  - 31000/tcp (Error API)"
echo "  - 31001/tcp (Email API)"
echo "  - 31002/tcp (VM API)"
echo "  - 8006/tcp (Proxmox API)"
echo "  - 9000/tcp (HAProxy stats)"
echo ""
echo "Outgoing:"
echo "  - ICMP (ping requests)"
echo "  - DNS (port 53)"
echo "  - NTP (port 123)"
echo "  - Connections to backend servers in ranges:"
echo "  - 10.20.20.200-202 (Kubernetes controllers)"
echo "  - 10.20.20.203-205 (Kubernetes workers)"
echo "  - 10.20.10.20-22, 10.20.10.28 (Proxmox servers)"
echo ""
echo "Use 'sudo ufw status numbered' to see all rules"