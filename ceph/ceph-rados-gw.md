# RADOS Gateway (RGW) Installation on Proxmox Ceph Cluster

This guide explains how to install and configure RADOS Gateway (Object Storage) on a Proxmox Ceph cluster from scratch.

## Overview

RADOS Gateway (RGW) is an object storage interface built on top of librados to provide applications with a RESTful gateway to Ceph Storage Clusters. It supports two interfaces:

- S3-compatible: Provides object storage functionality with an interface compatible with Amazon S3 RESTful API
- Swift-compatible: Provides object storage functionality with an interface compatible with OpenStack Swift API

**Official Documentation References:**

- [Proxmox VE Ceph Documentation](https://pve.proxmox.com/wiki/Deploy_Hyper-Converged_Ceph_Cluster)
- [Ceph RADOS Gateway Documentation](https://docs.ceph.com/en/latest/radosgw/)
- [Proxmox Ceph Server Documentation](https://pve.proxmox.com/pve-docs/chapter-pveceph.html)

## Prerequisites

Before installing RADOS Gateway, ensure:

1. You have a working Proxmox VE cluster (version 7.0 or later recommended)
2. Ceph cluster is installed and operational
3. At least 3 Ceph monitors are running
4. Ceph OSDs are operational with sufficient storage
5. Network connectivity between all Ceph nodes

Verify Ceph cluster health:

```bash
ceph -s
```

The output should show `HEALTH_OK` or acceptable warnings.

## Installation Steps

### Step 1: Install RADOS Gateway Package

On the Proxmox node where you want to run the RADOS Gateway:

```bash
# Update package lists
apt update

# Install radosgw package
apt install radosgw
```

### Step 2: Create RADOS Gateway Instance via Proxmox GUI

**Using Proxmox Web Interface (Recommended for Proxmox 7.x+):**

1. Navigate to Datacenter → Ceph in the Proxmox web interface
2. Select the node where you want to install RGW
3. Click on "Object Gateway" in the left menu
4. Click "Create" button
5. Configure the following settings:
   - **Name**: Default is usually fine (hostname)
   - **Port**: Default 7480 (or 443 for HTTPS)
   - **Certificate**: Optional - select SSL certificate for HTTPS

The Proxmox interface will automatically:

- Create the necessary Ceph pools
- Configure the RGW daemon
- Start the service

### Step 3: Create RADOS Gateway Instance via CLI

**Alternative Method - Using Command Line:**

Create the RADOS Gateway instance:

```bash
# Create RGW instance on the local node
pveceph rgw create

# Or create with specific options
pveceph rgw create --rgwid <name> --node <nodename> --port 7480
```

This command will:

- Create necessary RGW pools (`.rgw.root`, `.rgw.control`, `.rgw.meta`, etc.)
- Configure the RGW daemon
- Enable and start the `ceph-radosgw@rgw.<hostname>.<name>` service

### Step 4: Verify RADOS Gateway Service

Check that the RGW service is running:

```bash
# Check service status
systemctl status ceph-radosgw@rgw.$(hostname).rgw0

# Or use Ceph commands
ceph -s

# List RGW daemons
radosgw-admin status
```

Verify the gateway is accessible:

```bash
# Test HTTP access (replace with your node IP)
curl http://<node-ip>:7480
```

You should receive an XML response similar to:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<ListAllMyBucketsResult xmlns="http://s3.amazonaws.com/doc/2006-03-01/">
...
</ListAllMyBucketsResult>
```

### Step 5: Create RGW User for S3 Access

Create a user with S3 credentials:

```bash
# Create a new S3 user
radosgw-admin user create --uid=s3user --display-name="S3 User" --email=user@example.com

# The output will contain access_key and secret_key - SAVE THESE!
```

Example output:

```json
{
    "user_id": "s3user",
    "display_name": "S3 User",
    "email": "user@example.com",
    "keys": [
        {
            "user": "s3user",
            "access_key": "ABCDEFGHIJKLMNOPQRST",
            "secret_key": "abcdefghijklmnopqrstuvwxyz1234567890ABCD"
        }
    ],
    ...
}
```

### Step 6: Configure High Availability (Optional)

For production environments, deploy multiple RGW instances:

```bash
# On another Proxmox node
pveceph rgw create

# Or via GUI on each node
```

Use HAProxy or a load balancer to distribute traffic across multiple RGW instances.

## Configuration

### RGW Configuration File

The RGW configuration is stored in `/etc/ceph/ceph.conf`. Proxmox automatically manages this, but you can customize:

```bash
# Edit ceph.conf
nano /etc/ceph/ceph.conf
```

Common RGW configuration options:

```ini
[client.rgw.<hostname>.rgw0]
    host = <hostname>
    keyring = /etc/pve/priv/ceph.client.rgw.<hostname>.rgw0.keyring
    log file = /var/log/ceph/client.rgw.<hostname>.rgw0.log
    rgw_frontends = beast port=7480
    rgw_zone = default
```

After editing, restart the RGW service:

```bash
systemctl restart ceph-radosgw@rgw.$(hostname).rgw0
```

### SSL/TLS Configuration

To enable HTTPS:

**Method 1: Using Beast Frontend with SSL**

Edit `/etc/ceph/ceph.conf`:

```ini
[client.rgw.<hostname>.rgw0]
    rgw_frontends = beast ssl_port=443 ssl_certificate=/path/to/cert.pem
```

**Method 2: Using Reverse Proxy (Recommended)**

Use nginx or HAProxy in front of RGW for SSL termination.

## Pool Management

RADOS Gateway automatically creates several pools:

```bash
# List RGW pools
ceph osd lspools | grep rgw

# Common RGW pools:
# .rgw.root - Gateway configuration
# .rgw.control - Control pool
# .rgw.meta - Metadata
# .rgw.log - Log information
# .rgw.buckets.index - Bucket index
# .rgw.buckets.data - Object data
```

View pool details:

```bash
ceph df
```

## User Management

### Create Additional Users

```bash
# Create user
radosgw-admin user create --uid=<username> --display-name="<Display Name>"

# Create subuser (Swift)
radosgw-admin subuser create --uid=<username> --subuser=<username>:swift --access=full

# Generate new keys
radosgw-admin key create --uid=<username> --key-type=s3 --gen-access-key --gen-secret
```

### List Users

```bash
# List all users
radosgw-admin user list

# Get user information
radosgw-admin user info --uid=<username>
```

### Modify User

```bash
# Modify user email
radosgw-admin user modify --uid=<username> --email=newemail@example.com

# Suspend user
radosgw-admin user suspend --uid=<username>

# Re-enable user
radosgw-admin user enable --uid=<username>
```

### Delete User

```bash
# Delete user and all associated data
radosgw-admin user rm --uid=<username> --purge-data
```

## Testing S3 Access

### Using AWS CLI

Install AWS CLI:

```bash
apt install awscli
```

Configure AWS CLI:

```bash
aws configure

# Enter:
# AWS Access Key ID: <your_access_key>
# AWS Secret Access Key: <your_secret_key>
# Default region: us-east-1
# Default output format: json
```

Test S3 operations:

```bash
# Create bucket
aws --endpoint-url http://<node-ip>:7480 s3 mb s3://testbucket

# List buckets
aws --endpoint-url http://<node-ip>:7480 s3 ls

# Upload file
aws --endpoint-url http://<node-ip>:7480 s3 cp testfile.txt s3://testbucket/

# List objects in bucket
aws --endpoint-url http://<node-ip>:7480 s3 ls s3://testbucket/

# Download file
aws --endpoint-url http://<node-ip>:7480 s3 cp s3://testbucket/testfile.txt downloaded.txt

# Delete object
aws --endpoint-url http://<node-ip>:7480 s3 rm s3://testbucket/testfile.txt

# Delete bucket
aws --endpoint-url http://<node-ip>:7480 s3 rb s3://testbucket
```

### Using s3cmd

Install s3cmd:

```bash
apt install s3cmd
```

Configure s3cmd:

```bash
s3cmd --configure

# Or create config file manually at ~/.s3cfg
```

Example `.s3cfg`:

```ini
[default]
access_key = <your_access_key>
secret_key = <your_secret_key>
host_base = <node-ip>:7480
host_bucket = <node-ip>:7480
use_https = False
```

Test operations:

```bash
s3cmd ls
s3cmd mb s3://testbucket
s3cmd put testfile.txt s3://testbucket/
```

## Monitoring and Troubleshooting

### Check RGW Status

```bash
# Service status
systemctl status ceph-radosgw@rgw.$(hostname).rgw0

# View logs
journalctl -u ceph-radosgw@rgw.$(hostname).rgw0 -f

# Or traditional logs
tail -f /var/log/ceph/client.rgw.*.log
```

### Common Issues

**Issue: RGW service won't start**

```bash
# Check configuration
cat /etc/ceph/ceph.conf

# Verify keyring exists
ls -la /etc/pve/priv/ceph.client.rgw.*

# Check Ceph cluster health
ceph -s
```

**Issue: Cannot connect to RGW**

```bash
# Check if port is listening
netstat -tlnp | grep 7480

# Check firewall
ufw status
iptables -L -n | grep 7480

# Allow port if needed
ufw allow 7480/tcp
```

**Issue: S3 operations fail with authentication errors**

```bash
# Verify user exists
radosgw-admin user info --uid=<username>

# Check access keys
radosgw-admin user info --uid=<username> | grep access_key

# Regenerate keys if needed
radosgw-admin key create --uid=<username> --key-type=s3 --gen-access-key --gen-secret
```

### Performance Monitoring

```bash
# Check RGW pool usage
ceph df detail

# Monitor RGW performance
radosgw-admin usage show

# Check bucket statistics
radosgw-admin bucket stats

# Check specific bucket
radosgw-admin bucket stats --bucket=<bucket-name>
```

## Backup and Maintenance

### Backup RGW Configuration

```bash
# Backup ceph.conf
cp /etc/ceph/ceph.conf /root/ceph.conf.backup

# Backup keyring
cp /etc/pve/priv/ceph.client.rgw.* /root/

# Export user list
radosgw-admin user list > /root/rgw-users.json
```

### Pool Maintenance

```bash
# Check pool PG stats
ceph osd pool stats

# Adjust pool size if needed
ceph osd pool set .rgw.buckets.data size 3
ceph osd pool set .rgw.buckets.data min_size 2
```

## Multi-Site Configuration (Advanced)

For multi-site replication (optional):

```bash
# Create realm
radosgw-admin realm create --rgw-realm=<realm-name> --default

# Create zonegroup
radosgw-admin zonegroup create --rgw-zonegroup=<zonegroup-name> --master --default

# Create zone
radosgw-admin zone create --rgw-zonegroup=<zonegroup-name> --rgw-zone=<zone-name> --master --default

# Commit period
radosgw-admin period update --commit

# Restart RGW
systemctl restart ceph-radosgw@*
```

Refer to [Ceph Multi-Site Documentation](https://docs.ceph.com/en/latest/radosgw/multisite/) for detailed multi-site setup.

## Security Best Practices

1. **Use HTTPS**: Always use SSL/TLS in production
2. **Firewall Rules**: Restrict RGW port access to trusted networks
3. **Strong Credentials**: Use complex access keys and secrets
4. **Regular Updates**: Keep Proxmox and Ceph packages updated
5. **User Permissions**: Create users with minimal required permissions
6. **Audit Logs**: Regularly review RGW access logs
7. **Network Isolation**: Use separate networks for storage traffic

## References

- [Proxmox VE Ceph Documentation](https://pve.proxmox.com/pve-docs/chapter-pveceph.html)
- [Ceph RADOS Gateway Documentation](https://docs.ceph.com/en/latest/radosgw/)
- [Ceph RADOS Gateway Admin Guide](https://docs.ceph.com/en/latest/radosgw/admin/)
- [Ceph RADOS Gateway S3 API](https://docs.ceph.com/en/latest/radosgw/s3/)
- [Proxmox VE Admin Guide](https://pve.proxmox.com/pve-docs/pve-admin-guide.html)

## Summary

This guide covered:

- Installing RADOS Gateway on Proxmox Ceph cluster
- Creating and managing S3 users
- Testing S3 access with AWS CLI and s3cmd
- Monitoring and troubleshooting RGW
- Security best practices
- Basic multi-site concepts

RADOS Gateway provides enterprise-grade object storage with S3/Swift compatibility, making it an excellent solution for cloud storage needs on Proxmox infrastructure.

## Create Buckets and Users

```bash
# Create velero user
radosgw-admin user create --uid="velero-user" --display-name="Velero User"
radosgw-admin user info --uid=velero-user

# Create velero bucket (using AWS CLI with velero-user credentials)
aws --endpoint-url http://<node-ip>:7480 s3 mb s3://velero-bucket

# Create export user
radosgw-admin user create --uid="export-user" --display-name="Export User"
radosgw-admin user info --uid=export-user

# Create export bucket (using AWS CLI with export-user credentials)
aws --endpoint-url http://<node-ip>:7480 s3 mb s3://export-bucket

# List all buckets (admin command)
radosgw-admin bucket list
```
