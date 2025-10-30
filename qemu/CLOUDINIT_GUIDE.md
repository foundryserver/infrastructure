# Cloud-Init Template Setup for Proxmox 8.4 Debian 13

VERSION: 1.0.0  
LAST EDIT: Oct 29, 2025

This guide explains how to use the cloud-init YAML snippet to automate the creation of Debian 13 Foundry VTT templates in Proxmox 8.4.

## Files

- `debian13-fvtt-cloudinit.yaml` - Cloud-init configuration file
- `readme.md` - Original manual setup instructions
- This guide - Usage instructions

## Prerequisites

1. **Proxmox 8.4** with cloud-init support
2. **Debian 13 cloud image** (qcow2 format)
3. **Storage** configured for VM templates
4. **Network** access for package downloads

## Quick Setup Guide

### Step 1: Download Debian 13 Cloud Image

```bash
# On Proxmox host, download the official Debian 13 cloud image
cd /var/lib/vz/template/iso/
wget https://cloud.debian.org/images/cloud/bookworm/latest/debian-13-generic-amd64.qcow2

# Or use the official cloud image URL when it becomes available
```

### Step 2: Create VM with Cloud Image

```bash
# Create a new VM (adjust VMID as needed)
qm create 9000 --memory 2048 --core 2 --name debian13-fvtt-template --net0 virtio,bridge=vmbr0

# Import the cloud image as a disk
qm importdisk 9000 debian-13-generic-amd64.qcow2 local-lvm

# Attach the disk to the VM
qm set 9000 --scsihw virtio-scsi-pci --scsi0 local-lvm:vm-9000-disk-0

# Add cloud-init drive
qm set 9000 --ide2 local-lvm:cloudinit

# Configure boot from the imported disk
qm set 9000 --boot c --bootdisk scsi0

# Add serial console
qm set 9000 --serial0 socket --vga serial0

# Add second disk for data (adjust size as needed)
qm set 9000 --scsi1 local-lvm:32G
```

### Step 3: Configure Cloud-Init

#### Option A: Using Proxmox Web Interface

1. **Go to VM → Cloud-Init tab**
2. **Upload the YAML file**:
   - Click "Edit"
   - Paste contents of `debian13-fvtt-cloudinit.yaml`
   - Click "OK"

#### Option B: Using Command Line

```bash
# Copy the cloud-init file to Proxmox
scp debian13-fvtt-cloudinit.yaml root@proxmox-host:/tmp/

# On Proxmox host, set the cloud-init configuration
qm set 9000 --cicustom "user=local:snippets/debian13-fvtt-cloudinit.yaml"

# Copy the file to snippets directory
cp /tmp/debian13-fvtt-cloudinit.yaml /var/lib/vz/snippets/
```

### Step 4: Start VM and Monitor Setup

```bash
# Start the VM
qm start 9000

# Monitor the console to see cloud-init progress
qm monitor 9000
# Or via web interface: VM → Console
```

### Step 5: Verify Setup

After the VM boots and cloud-init completes:

```bash
# SSH into the VM as manager user
ssh manager@VM_IP

# Check services status
sudo systemctl status qemu-guest-agent
sudo systemctl status webdav
sudo systemctl status ufw

# Verify firewall rules
sudo ufw status

# Check mount points
df -h
```

### Step 6: Customize and Finalize

1. **Update WebDAV credentials**:

   ```bash
   sudo nano /home/fvtt/webdav/config.yaml
   # Replace "place#username" and "place#password"
   ```

2. **Customize scripts** (if needed):

   ```bash
   sudo nano /root/webhook.sh
   sudo nano /root/monitor.sh
   ```

3. **Test services**:
   ```bash
   sudo systemctl start webdav
   curl http://localhost:3030/
   ```

### Step 7: Convert to Template

```bash
# Shutdown the VM
qm shutdown 9000

# Convert to template
qm template 9000

# Rename template appropriately
qm set 9000 --name db13-fvtt-tpl-dev
```

## What Cloud-Init Automates

✅ **System Configuration**:

- Timezone (America/Vancouver)
- Locale (en_US.UTF-8)
- Package updates and installations

✅ **User Management**:

- Manager user with SSH keys and sudo access
- FVTT system user

✅ **Storage Setup**:

- 1.7GB swap file
- Data drive formatting and mounting
- Directory structure creation

✅ **Services**:

- UFW firewall (ports 22, 3030, 30000)
- WebDAV server installation and configuration
- Webhook service setup
- Auto-resize service for data drive

✅ **Software Installation**:

- All required packages
- WebDAV binary
- Node.js v25.0.0

✅ **System Optimization**:

- GRUB configuration for faster boot
- Unattended upgrades setup
- Cron jobs for maintenance

## Using the Template

### Clone from Template

```bash
# Clone a new VM from template
qm clone 9000 101 --name foundry-vm-01

# Customize the clone
qm set 101 --memory 4096
qm set 101 --cores 4

# Start the cloned VM
qm start 101
```

### Post-Clone Customization

Each cloned VM will need:

1. **Unique WebDAV credentials**
2. **Custom webhook configuration**
3. **Application-specific setup**

## Troubleshooting

### Cloud-Init Logs

```bash
# Check cloud-init status
cloud-init status

# View cloud-init logs
sudo cat /var/log/cloud-init.log
sudo cat /var/log/cloud-init-output.log
```

### Service Issues

```bash
# Check failed services
systemctl --failed

# Check specific service
sudo systemctl status webdav
sudo journalctl -u webdav
```

### Storage Issues

```bash
# Check disk layout
lsblk

# Check mounts
mount | grep fvtt

# Manual mount if needed
sudo mount /dev/sdb /home/fvtt/data
```

## Customization Notes

- **SSH Keys**: Update in the `users` section of the YAML
- **Firewall**: Modify the `ufw` section for different ports
- **Software**: Add packages to the `packages` list
- **Scripts**: Customize webhook.sh and monitor.sh content in `write_files`
- **Storage**: Adjust swap size and disk configuration as needed

## Security Considerations

- Manager user has passwordless sudo (change if needed)
- SSH keys are embedded in the template
- UFW firewall enabled with minimal required ports
- Unattended upgrades configured for security updates

This cloud-init approach provides a fully automated, repeatable template creation process that eliminates manual steps and ensures consistency across deployments.
