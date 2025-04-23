# Setup and Configure Proxmox HA Cluster

This is the general setup for the hypervisors. This is key for the success of the whole infrastructure. We will create a HA (high availability) cluster that consists of multiple hosts and replicated storage.

## Install

Each host will have to install via the virtual mount (idrac) or usb key. Two key elements to get right is the networking and storage.

## Storage

The host will have three devices. The boot device is a single 225 G ssd with raid bypass. The other two drives are 1 T SSD on raid bypass as well. We will be using ceph clustering on these machines therefore we let ceph look after drive redundancy and not the host raid controller.

Install the OS on the first ssd. No fancy partitioning required. This device is just to boot the machine and host the OS. No vms will use this drive. This drive will not have redundancy but the host will have redundancy. If this drive fails, then the whole host will fail and all vm's will move to other healthy hosts.

Ceph replicated file server will be added to these hosts to provide replicated storage for the VM's. This may add overhead to the hosts. You will have to watch for this. This file system will not see heavy traffic. There are no heavy workloads that involve large files. The vm disks will be the only thing on this file system. They will see some load however but nothing significate. The only reason we are using ceph is that comes with proxmox, easy install, and it provide out of the box replication for HA.

Remember that you will add each device on each host to the same disk pool. There is no reason for segregation of devices. We will have way more capacity than we need but remember due to replication x3, we only get 33% usable space, so 3 x 1T drives gets you 1T of useable space.

We may hold back the second drive, and keep it as a spare for future drive failures. No point in using up operation cycles if we really don't need the space. TBD.

## Network

Each host machine has 2 x 10gbs and 2 x 1gbs nic's. The two 10gbs nic's, will be bonded together using IEEE 802.3ad. This will provide link redundancy and double the network capacity. Make sure you set this up with layer 3/4 algorithm. Make sure you test this link out by physically pulling out the cable of each nic to make sure it continues to work.

One of the 1gbs nic's will be connected to the Netgear OOB switch. We will do that so that we can install a monitoring vm to run libre/prometheus/grafana to watch all the hardware. This nic will pass through the host directly to the vm. This will provide network isolation between the OOB, public and management networks.

```
eno1 (10G)
eno2 (10G) -> bond0 -> vmbr0 -> vmbr0.10 (mgmt) -> 10.10.10.?/24 (static)
                                vmbr0.21 (k8s) -> 10.10.20.?/24 (dhcp)

eno3 (1G) -> vmbr1 -> libre VM 10.5.32.?/24 (static)
eno4 (1G) -> N/C
```
