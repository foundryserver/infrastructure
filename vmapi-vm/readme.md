# Setup vmapi vm

We will start with a non cloud image debian 13 fresh install. There is an issue that the fresh install doesn't install sudo so it makes it a bit of a challenge to bootstrap the install. Seems weird to me.

## Boot Strap

You will need to come into the vm via the proxmox shell for the vm. Login as root and then Install these packages. The key one is sudo. You will then need to add the manager user to the sudo group so you can ssh into and continue the build.

```
apt install sudo -y
nano /etc/group   #( sudo:x:27:manager)
ip a # to get dhcp ip to ssh in
```

Now ssh into vm with user manager and then sudo to root to complete the install.

## Setup Networking

Make sure you change the ips for the two different hosts.

```
cat <<EOF > /etc/network/interfaces
# /etc/network/interfaces
# Network configuration for Debian 13

# Loopback interface
auto lo
iface lo inet loopback

# Primary network interface (ens18)
auto ens18
iface ens18 inet static
    address 192.168.0.7/16
    gateway 192.168.0.1
    dns-nameservers 192.168.0.1 1.1.1.1
    dns-search vm.local

   # Add a second IP address
    up ip addr add 10.20.20.7/24 dev ens18
    down ip addr del 10.20.20.7/24 dev ens18

# Secondary network interface (ens19)
auto ens19
iface ens19 inet static
    address 10.20.10.7/24

EOF
reboot
```

## Install packages

```
apt update
apt upgrade -y
apt install sudo htop atop zip unzip curl wget qemu-guest-agent unattended-upgrades rsync -y
apt autoremove -y
```

## Setup ENV'

```
echo "alias ll='ls -lah'" >> /etc/bash.bashrc

```

## Users

Need to update the manager user that is added during the install process.

```
# usermod -aG sudo manager  (this is done in the boot strap phase)
echo "manager  ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers
mkdir /home/manager/.ssh
sudo echo "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILXC8ewQSURYdaH6TWS0/Pv6KGY2tYap7t1eAizeQjKY brad@dev1" > /home/manager/.ssh/authorized_keys
sudo echo "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFK+9vVSQ3PsS5EmZoZDhnwPCl05Z/XdZ8xpG6HijOQX common-jan25" >> /home/manager/.ssh/authorized_keys
chown -R manager:manager /home/manager/
chmod 700 -R /home/manager/.ssh
chmod 600 /home/manager/.ssh/authorized_keys
```

## Automated Updates

```
dpkg-reconfigure --priority=low unattended-upgrades
nano /etc/apt/apt.conf.d/50unattended-upgrades
unattended-upgrade --dry-run --debug
```

## Install Nodejs binary

```
NODE_VERSION=v25.0.0  # example
curl -fsSL https://nodejs.org/dist/$NODE_VERSION/node-$NODE_VERSION-linux-x64.tar.xz | tar -xJ
sudo mv node-$NODE_VERSION-linux-x64 /opt/node
sudo ln -s /opt/node/bin/node /usr/local/bin/node
sudo ln -s /opt/node/bin/npm /usr/local/bin/npm
```

## Setup Application Dir

```
mkdir -p /home/manager/dev/vm_api
mkdir -p /home/manager/prod/vm_api
chown manager:manager -R /home/manager
```
