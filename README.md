# General Setup

## User Accounts.

### PVE & PVB Hosts

```
useradd -m -s /bin/bash admin
gpasswd -a admin sudo
echo "admin  ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers
mkdir /home/admin/.ssh
echo "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFK+9vVSQ3PsS5EmZoZDhnwPCl05Z/XdZ8xpG6HijOQX common-jan25" >> /home/admin/.ssh/authorized_keys
chmod 700 -R /home/admin/.ssh
chmod 600 /home/admin/.ssh/authorized_keys
chown -R admin:admin /home/admin/

useradd -m -s /bin/bash sam
gpasswd -a sam sudo
echo "sam  ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers
mkdir /home/sam/.ssh
echo "" >> /home/sam/.ssh/authorized_keys
chmod 700 -R /home/sam/.ssh
chmod 600 /home/sam/.ssh/authorized_keys
chown -R sam:sam /home/sam/







```
