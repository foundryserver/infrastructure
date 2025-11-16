# 2025-11-15 14:55:02 by RouterOS 7.20.4
# software id = 12J7-W2PI
#
# model = CCR2116-12G-4S+
# serial number = HK10AH2B85W
/interface ethernet
set [ find default-name=ether13 ] comment="OOB Configuration Port" name=\
    ether13_oob
set [ find default-name=sfp-sfpplus3 ] comment=\
    "Downlink Trunk Port to crs317-1"
set [ find default-name=sfp-sfpplus1 ] comment=\
    "Downlink Trunk Port To Switch" name=sfpplus1_CRS317-1
/interface vlan
add comment="Mgmt Vlan" interface=sfpplus1_CRS317-1 name=vlan10 vlan-id=10
add comment="VM Vlan" interface=sfpplus1_CRS317-1 name=vlan20 vlan-id=20
add comment="Public IP Vlan - Beanfield" interface=sfpplus1_CRS317-1 name=\
    vlan40 vlan-id=40
add comment="Public IP v6 Vlan - Beanfield" interface=sfpplus1_CRS317-1 name=\
    vlan41 vlan-id=41
/interface bonding
add comment="Downlink to crs317-1" mode=802.3ad name=bond0 slaves=\
    sfp-sfpplus3 transmit-hash-policy=layer-2-and-3
/ip pool
add name=dhcp_pool0 ranges=192.168.1.1-192.168.255.254
/ip dhcp-server
add address-pool=dhcp_pool0 interface=vlan20 name=dhcp1
/port
set 0 name=serial0
/routing bgp instance
add as=64512 name=bgp-instance-1 router-id=10.20.20.1
/routing bgp template
set default as=65530
/ip firewall connection tracking
set tcp-established-timeout=1h
/ip neighbor discovery-settings
set discover-interface-list=!dynamic
/ipv6 settings
set accept-redirects=no accept-router-advertisements=no
/ip address
add address=10.90.90.2/24 comment="OOB IP Address" interface=ether13_oob \
    network=10.90.90.0
add address=10.20.20.1/24 comment="VM Vlan IP Address" interface=vlan20 \
    network=10.20.20.0
add address=10.20.10.1/24 comment="Mgmt Vlan IP Address" interface=vlan10 \
    network=10.20.10.0
add address=192.168.0.1/16 comment="VM Vlan IP Address" interface=vlan20 \
    network=192.168.0.0
add address=199.45.150.6/28 comment="Public Router Address" interface=vlan40 \
    network=199.45.150.0
add address=199.45.150.2/28 comment="K8S Ip Address #1" interface=vlan40 \
    network=199.45.150.0
add address=199.45.150.9/28 comment="Development K8S Ip Address" interface=\
    vlan40 network=199.45.150.0
/ip dhcp-server network
add address=192.168.0.0/16 dns-server=192.168.0.1,10.20.20.1,1.1.1.1,8.8.8.8 \
    domain=vm.lan gateway=192.168.0.1
/ip dns
set allow-remote-requests=yes servers=1.1.1.1,8.8.8.8
/ip dns static
add address=10.90.90.2 name=ccr2116-1.oob.local type=A
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
add address=192.168.0.32 name=monitor1.vm.local type=A
add address=10.90.90.32 name=monitor1.oob.local type=A
add address=10.20.20.133 name=haproxy1.vm.local type=A
add address=10.90.90.2 name=ccr2116-1.oob.lan type=A
add address=10.90.90.4 name=crs317-1.oob.lan type=A
add address=10.90.90.5 name=crs317-2.oob.lan type=A
add address=10.90.90.20 name=pve0.oob.lan type=A
add address=10.90.90.21 name=pve1.oob.lan type=A
add address=10.90.90.22 name=pve2.oob.lan type=A
add address=10.90.90.23 name=nfs1.oob.lan type=A
add address=10.90.90.24 name=nfs2.oob.lan type=A
add address=10.90.90.25 name=backup1.oob.lan type=A
add address=10.90.90.26 name=spare0.oob.lan type=A
add address=10.90.90.27 name=spare1.oob.lan type=A
add address=10.90.90.28 name=pve3.oob.lan type=A
add address=10.90.90.29 name=tailscale3.oob.lan type=A
add address=10.90.90.31 name=tailscale2.oob.lan type=A
add address=10.20.10.20 name=pve0.mgmt.lan type=A
add address=10.20.10.21 name=pve1.mgmt.lan type=A
add address=10.20.10.22 name=pve2.mgmt.lan type=A
add address=10.20.10.23 name=nfs1.mgmt.lan type=A
add address=10.20.10.24 name=nfs2.mgmt.lan type=A
add address=10.20.10.25 name=backup1.mgmt.lan type=A
add address=10.20.10.26 name=spare0.mgmt.lan type=A
add address=10.20.10.27 name=spare1.mgmt.lan type=A
add address=10.20.10.28 name=pve3.mgmt.lan type=A
add address=10.20.10.32 name=monitor1.mgmt.lan type=A
add address=10.20.10.30 name=tailscale1.mgmt.lan type=A
add address=10.20.10.31 name=tailscale2.mgmt.lan type=A
add address=10.20.20.23 name=nfs1.vm.lan type=A
add address=10.20.20.24 name=nfs2.vm.lan type=A
add address=10.20.20.136 name=mongo1.vm.lan type=A
add address=10.20.20.134 name=mongo2.vm.lan type=A
add address=10.20.20.135 name=mongo3.vm.lan type=A
add address=10.20.20.134 name=dev1.vm.lan type=A
add address=10.20.20.107 name=nodeport.vm.lan type=A
add address=192.168.0.3 name=caddy1.vm.lan type=A
add address=192.168.0.32 name=monitor1.vm.lan type=A
add address=10.90.90.32 name=monitor1.oob.lan type=A
add address=192.168.0.2 name=caddy0.vm.lan type=A
add address=10.20.20.199 comment="LXC Nodeport IPs" name=nodeport1.vm.lan \
    type=A
add address=10.20.10.199 comment="Proxmox API LB" name=pve.mgmt.lan type=A
add address=192.168.0.199 comment="vm nodeport dns" name=nodeport2.vm.lan \
    type=A
/ip firewall address-list
add address=10.20.10.0/24 comment="Mgmt List" list="Mgmt List"
add address=10.20.20.0/24 comment="VM List 10.x.x.x" list="VM List"
add address=192.168.0.0/16 comment="VM List 192.168.x.x" list="VM List"
add address=10.90.90.0/24 comment="OOB LIst" list="OOB List"
add address=199.45.150.0/28 comment="Public List" list="Public List"
/ip firewall filter
add action=fasttrack-connection chain=forward hw-offload=yes
add action=accept chain=input comment="Allow Est, Related, & Untracked" \
    connection-state=established,related,untracked
add action=accept chain=input comment="Allow ICMP" protocol=icmp
add action=accept chain=input comment="Allow from OOB Subnet" in-interface=\
    ether13_oob src-address=10.90.90.0/24
add action=accept chain=input comment="Allow dhcp" dst-port=67 in-interface=\
    vlan20 protocol=udp
add action=accept chain=input comment="BGP Rule" dst-port=179 in-interface=\
    vlan20 protocol=tcp
add action=accept chain=forward comment="Allow Est, Related & Untracked" \
    connection-state=established,related,untracked
add action=accept chain=forward dst-address=10.20.20.66 in-interface=vlan40 \
    log-prefix=NATTED--> out-interface=vlan20 protocol=tcp
add action=accept chain=forward dst-address=10.20.20.61 in-interface=vlan40 \
    log-prefix=NATTED--> out-interface=vlan20 protocol=tcp
add action=drop chain=forward comment="Mgmt Vlan" dst-address-list=\
    "Mgmt List" in-interface=!vlan10
add action=drop chain=forward comment="VM Vlan" dst-address-list="VM List" \
    in-interface=!vlan20
add action=accept chain=forward out-interface=vlan40 src-address-list=\
    "VM List"
add action=accept chain=forward out-interface=vlan40 src-address-list=\
    "Mgmt List"
add action=accept chain=forward out-interface=vlan40 src-address-list=\
    "OOB List"
add action=drop chain=forward comment="Drop All Remaining Traffic" \
    log-prefix="FORWARD DROP -->>"
add action=accept chain=input comment="Allow udp dns vlan 10" dst-port=53 \
    protocol=udp src-address-list="Mgmt List"
add action=accept chain=input comment="Allow udp dns vlan 40" dst-port=53 \
    protocol=udp src-address-list="Public List"
add action=accept chain=input comment="Allow udp dns vlan 20" dst-port=53 \
    protocol=udp src-address-list="VM List"
add action=accept chain=input comment="Allow tcp dns vlan 10" dst-port=53 \
    protocol=tcp src-address-list="Mgmt List"
add action=accept chain=input comment="Allow tcp dns vlan 40" dst-port=53 \
    protocol=tcp src-address-list="Public List"
add action=accept chain=input comment="Allow tcp dns vlan 20" dst-port=53 \
    protocol=tcp src-address-list="VM List"
add action=accept chain=input comment="Allow tcp dns OOB" dst-port=53 \
    protocol=tcp src-address-list="OOB List"
add action=accept chain=input comment="Allow udp dns OOB" dst-port=53 \
    protocol=udp src-address-list="OOB List"
add action=drop chain=input comment="Drop All Remaining Traffic"
/ip firewall nat
add action=dst-nat chain=dstnat comment="k8s ip nat" dst-address=199.45.150.2 \
    log-prefix="METALLB/Beanfield -->" to-addresses=10.20.20.66
add action=dst-nat chain=dstnat comment="development k8s ip nat" dst-address=\
    199.45.150.9 log-prefix=METALLB---Dev--> to-addresses=10.20.20.61
add action=src-nat chain=srcnat out-interface=vlan40 src-address=10.20.20.66 \
    to-addresses=199.45.150.2
add action=src-nat chain=srcnat out-interface=vlan40 src-address=10.20.20.61 \
    to-addresses=199.45.150.9
add action=masquerade chain=srcnat comment=\
    "Allow Outbound Connections from Lan" out-interface=vlan40
/ip route
add disabled=no distance=1 dst-address=0.0.0.0/0 gateway=199.45.150.1 \
    routing-table=main scope=30 suppress-hw-offload=no target-scope=10
/ipv6 route
add comment="Beanfield Default Route" disabled=no dst-address=::/0 gateway=\
    2606:880::10 routing-table=main suppress-hw-offload=no
/ip service
set ftp disabled=yes
set telnet disabled=yes
set www disabled=yes
set ssh port=3637
set api disabled=yes
set api-ssl disabled=yes
set winbox port=37891
/ipv6 address
add address=2606:880::11/127 advertise=no comment="BF PtP Address" interface=\
    vlan40
add address=2606:880:0:1::1/72 advertise=no comment="Foundry Gateway Address" \
    interface=vlan41
/ipv6 firewall address-list
add address=fe80::/10 comment="RFC6890 Linked-Scoped Unicast" list=\
    no_forward_ipv6
add address=ff00::/8 comment=multicast list=no_forward_ipv6
add address=::1/128 comment="defconf: RFC6890 lo" list=bad_ipv6
add address=::ffff:0.0.0.0/96 comment="defconf: RFC6890 IPv4 mapped" list=\
    bad_ipv6
add address=2001::/23 comment="defconf: RFC6890" list=bad_ipv6
add address=2001:db8::/32 comment="defconf: RFC6890 documentation" list=\
    bad_ipv6
add address=2001:10::/28 comment="defconf: RFC6890 orchid" list=bad_ipv6
add address=::/96 comment="defconf: ipv4 compat" list=bad_ipv6
add address=100::/64 comment="defconf: RFC6890 Discard-only" list=\
    not_global_ipv6
add address=2001::/32 comment="defconf: RFC6890 TEREDO" list=not_global_ipv6
add address=2001:2::/48 comment="defconf: RFC6890 Benchmark" list=\
    not_global_ipv6
add address=fc00::/7 comment="defconf: RFC6890 Unique-Local" list=\
    not_global_ipv6
add address=::/128 comment="defconf: unspecified" list=bad_dst_ipv6
add address=::/128 comment="defconf: unspecified" list=bad_src_ipv6
add address=ff00::/8 comment="defconf: multicast" list=bad_src_ipv6
/ipv6 firewall filter
add action=accept chain=input comment="Accept ICMPv6 after RAW" protocol=\
    icmpv6
add action=accept chain=input comment="Accept established,related,untracked" \
    connection-state=established,related,untracked
add action=accept chain=input comment="Accept UDP traceroute" dst-port=\
    33434-33534 protocol=udp
add action=drop chain=input comment="Drop all not coming from LAN" \
    in-interface=!vlan10
add action=accept chain=forward comment=\
    "Accept established,related,untracked" connection-state=\
    established,related,untracked
add action=drop chain=forward comment="Drop invalid" connection-state=invalid
add action=drop chain=forward comment="Drop bad forward IPs" \
    src-address-list=no_forward_ipv6
add action=drop chain=forward comment="Drop bad forward IPs" \
    dst-address-list=no_forward_ipv6
add action=drop chain=forward comment="RFC4890 drop hop-limit=1" hop-limit=\
    equal:1 protocol=icmpv6
add action=accept chain=forward comment="Accept ICMPv6 after RAW" protocol=\
    icmpv6
/ipv6 firewall raw
add action=accept chain=prerouting comment=\
    "defconf: enable for transparent firewall" disabled=yes
add action=accept chain=prerouting comment="defconf: RFC4291, section 2.7.1" \
    dst-address=ff02::1:ff00:0/104 icmp-options=135 protocol=icmpv6 \
    src-address=::/128
add action=drop chain=prerouting comment="defconf: drop bogon IP's" \
    src-address-list=bad_ipv6
add action=drop chain=prerouting comment="defconf: drop bogon IP's" \
    dst-address-list=bad_ipv6
add action=drop chain=prerouting comment=\
    "defconf: drop packets with bad SRC ipv6" src-address-list=bad_src_ipv6
add action=drop chain=prerouting comment=\
    "defconf: drop packets with bad dst ipv6" dst-address-list=bad_dst_ipv6
add action=drop chain=prerouting comment="Drop non global from WAN" \
    in-interface=vlan40 src-address-list=not_global_ipv6
add action=drop chain=prerouting comment="Drop non global from WAN" \
    in-interface=vlan41 src-address-list=not_global_ipv6
add action=accept chain=prerouting comment=\
    "defconf: accept local multicast scope" dst-address=ff02::/16
add action=drop chain=prerouting comment=\
    "defconf: drop other multicast destinations" dst-address=ff00::/8
/routing bgp connection
add connect=yes disabled=no instance=bgp-instance-1 listen=yes local.address=\
    10.20.20.1 .role=ibgp name=k8s-node-px2 remote.address=10.20.20.104/32 \
    .as=64512 routing-table=main
/system clock
set time-zone-autodetect=no time-zone-name=America/Vancouver
/system identity
set name=CCR2116-1
/system note
set show-at-login=no
/system ntp client
set enabled=yes
/system ntp client servers
add address=time.google.com
/system routerboard settings
set enter-setup-on=delete-key
/tool e-mail
set from="" port=443 server=mail.smtp2go.com tls=yes user=\
    admin@foundryserver.com
/tool romon
set enabled=yes
