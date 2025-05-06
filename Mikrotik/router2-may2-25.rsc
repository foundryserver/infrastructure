# 2025-05-02 19:32:26 by RouterOS 7.16.2
# software id = 8TPU-C45K
#
# model = RB5009UG+S+
# serial number = EC1A0F8468CB
/interface ethernet
set [ find default-name=ether1 ] disabled=yes
set [ find default-name=ether2 ] disabled=yes
set [ find default-name=ether3 ] disabled=yes
set [ find default-name=ether4 ] disabled=yes
set [ find default-name=ether5 ] disabled=yes
set [ find default-name=ether6 ] disabled=yes
set [ find default-name=ether7 ] disabled=yes
set [ find default-name=ether8 ] comment="OOB Configuration Port" name=\
    ether8_oob
set [ find default-name=sfp-sfpplus1 ] comment=\
    "Downlink Trunk Port To Switch" name=sfpplus1_CRS317-1
/interface vlan
add comment="Mgmt Vlan" interface=sfpplus1_CRS317-1 name=vlan10 vlan-id=10
add comment="VM Vlan" interface=sfpplus1_CRS317-1 name=vlan20 vlan-id=20
add comment="Public IP Vlan" interface=sfpplus1_CRS317-1 name=vlan30 vlan-id=\
    30
/interface wireless security-profiles
set [ find default=yes ] supplicant-identity=MikroTik
/ip pool
add name=dhcp_pool0 ranges=192.168.0.100-192.168.255.254
/ip dhcp-server
add address-pool=dhcp_pool0 interface=vlan20 name=dhcp1
/ip neighbor discovery-settings
set discover-interface-list=!dynamic
/ip address
add address=10.90.90.3/24 comment="OOB IP Address" interface=ether8_oob \
    network=10.90.90.0
add address=10.20.20.1/24 comment="VM Vlan IP Address" interface=vlan20 \
    network=10.20.20.0
add address=10.20.10.1/24 comment="Mgmt Vlan IP Address" interface=vlan10 \
    network=10.20.10.0
add address=192.168.0.1/16 comment="VM Vlan IP Address" interface=vlan20 \
    network=192.168.0.0
add address=38.186.49.184/28 comment="Public Ip Address" interface=vlan30 \
    network=38.186.49.176
add address=38.186.49.180/28 comment="k8s ip" interface=vlan30 network=\
    38.186.49.176
add address=172.16.0.1/24 comment="VM Vlan IP Address" interface=vlan20 \
    network=172.16.0.0
/ip dhcp-server network
add address=192.168.0.0/16 dns-server=192.168.0.1,1.1.1.1 gateway=192.168.0.1
/ip dns
set allow-remote-requests=yes servers=1.1.1.1,8.8.8.8
/ip dns static
add address=10.90.90.2 name=rb5009-1.oob.local type=A
add address=10.90.90.3 name=rb5009-2.oob.local type=A
add address=10.90.90.4 name=crs317-1.oob.local type=A
add address=10.90.90.5 name=crs317-2.oob.local type=A
add address=10.90.90.20 name=pve0.oob.local type=A
add address=10.90.90.21 name=pve1.oob.local type=A
add address=10.90.90.22 name=pve2.oob.local type=A
add address=10.90.90.23 name=nfs1.oob.local type=A
add address=10.90.90.24 name=nfs2.oob.local type=A
add address=10.90.90.25 name=backup1.oob.local type=A
add address=10.90.90.26 name=spare0.oob.local type=A
add address=10.90.90.27 name=spare1.oob.local type=A
add address=10.90.90.28 name=pve3.oob.local type=A
add address=10.90.90.29 name=tailscale3.oob.local type=A
add address=10.90.90.31 name=tailscale2.oob.local type=A
add address=10.20.10.20 name=pve0.mgmt.local type=A
add address=10.20.10.21 name=pve1.mgmt.local type=A
add address=10.20.10.22 name=pve2.mgmt.local type=A
add address=10.20.10.23 name=nfs1.mgmt.local type=A
add address=10.20.10.24 name=nfs2.mgmt.local type=A
add address=10.20.10.25 name=backup1.mgmt.local type=A
add address=10.20.10.26 name=spare0.mgmt.local type=A
add address=10.20.10.27 name=spare1.mgmt.local type=A
add address=10.20.10.28 name=pve3.mgmt.local type=A
add address=10.20.10.32 name=monitor1.mgmt.local type=A
add address=10.20.10.30 name=tailscale1.mgmt.local type=A
add address=10.20.10.31 name=tailscale2.mgmt.local type=A
add address=10.20.20.23 name=nfs1.vm.local type=A
add address=10.20.20.24 name=nfs2.vm.local type=A
add address=10.20.20.130 name=mongo1.vm.local type=A
add address=10.20.20.131 name=mongo2.vm.local type=A
add address=10.20.20.132 name=mongo3.vm.local type=A
add address=10.20.20.133 name=k0sapi.vm.local type=A
add address=10.20.20.134 name=dev1.vm.local type=A
add address=10.20.20.106 name=nodeport.vm.local type=A
add address=10.20.20.107 name=nodeport.vm.local type=A
add address=192.168.0.3 name=caddy1.vm.local type=A
add address=192.168.0.32 name=monitor1.vm.local type=A
add address=192.168.0.6 name=vmapi0.vm.local type=A
add address=192.168.0.7 name=vmapi1.vm.local type=A
add address=10.90.90.32 name=monitor1.oob.local type=A
/ip firewall address-list
add address=10.20.10.0/24 comment="Mgmt List" list="Mgmt List"
add address=10.20.20.0/24 comment="VM List 10.x.x.x" list="VM List"
add address=192.168.0.0/16 comment="VM List 192.168.x.x" list="VM List"
add address=38.186.49.160/29 comment="Public List" list="Public List"
add address=10.90.90.0/24 comment="OOB LIst" list="OOB List"
add address=38.186.49.176/28 list="Public List"
/ip firewall filter
add action=fasttrack-connection chain=forward hw-offload=yes
add action=accept chain=input comment="Allow Est, Related, & Untracked" \
    connection-state=established,related,untracked
add action=accept chain=input comment="Allow ICMP" protocol=icmp
add action=accept chain=input comment="Allow from OOB Subnet" in-interface=\
    ether8_oob src-address=10.90.90.0/24
add action=accept chain=input comment="Allow dhcp" dst-port=67 in-interface=\
    vlan20 protocol=udp
add action=accept chain=forward comment="Allow Est, Related & Untracked" \
    connection-state=established,related,untracked
add action=accept chain=forward dst-address=10.20.20.66 in-interface=vlan30 \
    out-interface=vlan20 protocol=tcp
add action=drop chain=forward comment="Mgmt Vlan" dst-address-list=\
    "Mgmt List" in-interface=!vlan10
add action=drop chain=forward comment="VM Vlan" dst-address-list="VM List" \
    in-interface=!vlan20
add action=accept chain=forward out-interface=vlan30 src-address-list=\
    "VM List"
add action=accept chain=forward out-interface=vlan30 src-address-list=\
    "Mgmt List"
add action=accept chain=forward out-interface=vlan30 src-address-list=\
    "OOB List"
add action=drop chain=forward comment="Drop All Remaining Traffic"
add action=accept chain=input comment="Allow udp dns vlan 10" dst-port=53 \
    protocol=udp src-address-list="Mgmt List"
add action=accept chain=input comment="Allow udp dns vlan 30" dst-port=53 \
    protocol=udp src-address-list="Public List"
add action=accept chain=input comment="Allow udp dns vlan 20" dst-port=53 \
    protocol=udp src-address-list="VM List"
add action=accept chain=input comment="Allow tcp dns vlan 10" dst-port=53 \
    protocol=tcp src-address-list="Mgmt List"
add action=accept chain=input comment="Allow tcp dns vlan 30" dst-port=53 \
    protocol=tcp src-address-list="Public List"
add action=accept chain=input comment="Allow tcp dns vlan 20" dst-port=53 \
    protocol=tcp src-address-list="VM List"
add action=accept chain=input comment="Allow tcp dns OOB" dst-port=53 \
    protocol=tcp src-address-list="OOB List"
add action=accept chain=input comment="Allow udp dns OOB" dst-port=53 \
    protocol=udp src-address-list="OOB List"
add action=drop chain=input comment="Drop All Remaining Traffic"
/ip firewall nat
add action=dst-nat chain=dstnat comment="k8s ip nat" dst-address=\
    38.186.49.180 log-prefix="METALLB -->" to-addresses=10.20.20.66
add action=src-nat chain=srcnat out-interface=vlan30 src-address=10.20.20.66 \
    to-addresses=38.186.49.180
add action=masquerade chain=srcnat comment=\
    "Allow Outbound Connections from Lan" out-interface=vlan30
/ip route
add disabled=no distance=1 dst-address=0.0.0.0/0 gateway=38.186.49.177 \
    routing-table=main scope=30 suppress-hw-offload=no target-scope=10
/ip service
set telnet disabled=yes
set ftp disabled=yes
set www disabled=yes
set ssh port=3637
set api disabled=yes
set winbox port=37891
set api-ssl disabled=yes
/system clock
set time-zone-autodetect=no time-zone-name=America/Vancouver
/system identity
set name=RB5009-2
/system note
set show-at-login=no
/system ntp client
set enabled=yes
/system ntp client servers
add address=time.google.com
/tool e-mail
set from="" port=443 server=mail.smtp2go.com tls=yes user=\
    admin@foundryserver.com
/tool romon
set enabled=yes
