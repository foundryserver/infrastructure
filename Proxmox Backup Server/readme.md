# Setup and Configure Proxmox Backup Server.

## Disk layout

The backup server has three (3) 8T ssd drives that are configured as raid 0 via the hardware controller. This does NOT give any kind of failover.

```
sda      8:0    0 21.8T  0 disk
└─sda1   8:1    0 21.8T  0 part /backup
sdb      8:16   0  223G  0 disk
├─sdb1   8:17   0    1G  0 part /boot/efi
├─sdb2   8:18   0  220G  0 part /
└─sdb3   8:19   0  1.9G  0 part [SWAP]

```

## Install Backup os

Proxmox backup server is installed as an iso via the idrac interface. For reference see
https://www.proxmox.com/en/products/proxmox-backup-server/get-started

## Network

This host will only need to connect to the mgmt network on vlan 10. The other connection will be on the oob netwrok for idrac.

## Configuration

This will be done via the gui once the os is installed.
