# Proxmox Setup

This is pretty straight forward. There are two house cleaning issues that you will need to do. You will need to enable the OS repo so that proxmox gets the appropriate updates and you will also need to make a change to the systemd settings so that lxc containers don't have high load averages.

## Fix Systemd

The fix is "-l" on the execstart line. If you don't do this the lxc container will run with excessive high load averages. This has to do with file system contention. This is for version 8.40+ versions of proxmox.

```
cat <<EOF > /lib/systemd/system/lxcfs.service

[Unit]
Description=FUSE filesystem for LXC
ConditionVirtualization=!container
Before=lxc.service
Documentation=man:lxcfs(1)

[Service]
OOMScoreAdjust=-1000
ExecStartPre=/bin/mkdir -p /var/lib/lxcfs
ExecStart=/usr/bin/lxcfs -l /var/lib/lxcfs
KillMode=process
Restart=on-failure
ExecStopPost=-/bin/fusermount -u /var/lib/lxcfs
Delegate=yes
ExecReload=/bin/kill -USR1 $MAINPID

[Install]
WantedBy=multi-user.target
EOF

systemctl restart lxcfs.service
```

## Setup Upgrade Repo
