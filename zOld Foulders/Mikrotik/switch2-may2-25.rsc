# 2025-03-16 13:35:01 by RouterOS 7.17
# software id = N84H-273W
#
# model = CRS317-1G-16S+
# serial number = HF0097N3V5R
/interface bridge
add admin-mac=D4:01:C3:1D:92:F1 auto-mac=no name=bridge protocol-mode=mstp \
    vlan-filtering=yes
/interface ethernet
set [ find default-name=ether1 ] comment="OOB Mgmt"
set [ find default-name=sfp-sfpplus1 ] l2mtu=9000 mtu=9000
set [ find default-name=sfp-sfpplus2 ] l2mtu=9000 mtu=9000
set [ find default-name=sfp-sfpplus3 ] l2mtu=9000 mtu=9000
set [ find default-name=sfp-sfpplus4 ] l2mtu=9000 mtu=9000
set [ find default-name=sfp-sfpplus5 ] l2mtu=9000 mtu=9000
set [ find default-name=sfp-sfpplus6 ] l2mtu=9000 mtu=9000
set [ find default-name=sfp-sfpplus7 ] l2mtu=9000 mtu=9000
set [ find default-name=sfp-sfpplus8 ] l2mtu=9000 mtu=9000
set [ find default-name=sfp-sfpplus9 ] l2mtu=9000 mtu=9000
set [ find default-name=sfp-sfpplus10 ] l2mtu=9000 mtu=9000
set [ find default-name=sfp-sfpplus11 ] l2mtu=9000 mtu=9000
set [ find default-name=sfp-sfpplus12 ] l2mtu=9000 mtu=9000
set [ find default-name=sfp-sfpplus13 ] disabled=yes
set [ find default-name=sfp-sfpplus14 ] disabled=yes
set [ find default-name=sfp-sfpplus15 ] disabled=yes
set [ find default-name=sfp-sfpplus16 ] disabled=yes
/interface bonding
add comment=bond0 mode=802.3ad mtu=9000 name=bond0 slaves=\
    sfp-sfpplus1,sfp-sfpplus2,sfp-sfpplus3 transmit-hash-policy=layer-2-and-3
add comment=bond1 mode=802.3ad mtu=9000 name=bond1 slaves=\
    sfp-sfpplus4,sfp-sfpplus5,sfp-sfpplus6 transmit-hash-policy=layer-2-and-3
add comment=bond2 mode=802.3ad mtu=9000 name=bond2 slaves=\
    sfp-sfpplus7,sfp-sfpplus8,sfp-sfpplus9 transmit-hash-policy=layer-2-and-3
add comment=bond3 forced-mac-address=00:00:00:00:00:00 mode=802.3ad mtu=9000 \
    name=bond3 slaves=sfp-sfpplus10,sfp-sfpplus11,sfp-sfpplus12 \
    transmit-hash-policy=layer-2-and-3
/port
set 0 name=serial0
/interface bridge port
add bridge=bridge interface=bond0
add bridge=bridge interface=bond1
add bridge=bridge interface=bond2
add bridge=bridge interface=bond3
/ip address
add address=10.90.90.5/24 comment="OOB IP Address" interface=ether1 network=\
    10.90.90.0
/ip dns
set servers=1.1.1.1,8.8.8.8
/ip firewall filter
add action=accept chain=input connection-state=established,related,untracked \
    in-interface=ether1 src-address=10.90.90.0/24
add action=accept chain=input in-interface=ether1 src-address=10.90.90.0/24
add action=drop chain=input
/ip firewall nat
add action=masquerade chain=srcnat out-interface=ether1
/ip route
add disabled=no dst-address=0.0.0.0/0 gateway=10.90.90.1 routing-table=main \
    suppress-hw-offload=no
/ip service
set telnet disabled=yes
set ftp disabled=yes
set www disabled=yes
set ssh port=3637
set api disabled=yes
set winbox port=37891
set api-ssl disabled=yes
/snmp
set enabled=yes
/system clock
set time-zone-name=America/Vancouver
/system identity
set name=CRS317-2
/system note
set show-at-login=no
/system ntp client
set enabled=yes
/system ntp client servers
add address=time.google.com
/system routerboard settings
set enter-setup-on=delete-key
/system swos
set address-acquisition-mode=static identity=MikroTik static-ip-address=\
    10.5.32.88
