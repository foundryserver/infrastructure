# 2025-03-04 17:25:33 by RouterOS 7.17
# software id = B81L-RYRR
#
# model = CRS317-1G-16S+
# serial number = HG309HZFKNC
/interface bridge
add admin-mac=D4:01:C3:1D:92:F1 auto-mac=no name=bridge port-cost-mode=short \
    protocol-mode=none vlan-filtering=yes
/interface ethernet
set [ find default-name=ether1 ] comment="OOB Mgmt" name=ether1_oob
set [ find default-name=sfp-sfpplus10 ] disabled=yes
set [ find default-name=sfp-sfpplus11 ] disabled=yes
set [ find default-name=sfp-sfpplus12 ] disabled=yes
set [ find default-name=sfp-sfpplus13 ] disabled=yes
set [ find default-name=sfp-sfpplus14 ] comment="Uplink RB5009-1"
set [ find default-name=sfp-sfpplus15 ] comment="Switch Bonding 1" disabled=\
    yes
set [ find default-name=sfp-sfpplus16 ] comment="Switch Bonding 2" disabled=\
    yes
/ip smb users
set [ find default=yes ] disabled=yes
/port
set 0 name=serial0
/interface bridge mlag
set priority=127
/interface bridge port
add bridge=bridge interface=sfp-sfpplus1
add bridge=bridge interface=sfp-sfpplus2
add bridge=bridge interface=sfp-sfpplus3
add bridge=bridge interface=sfp-sfpplus4
add bridge=bridge interface=sfp-sfpplus5
add bridge=bridge interface=sfp-sfpplus6
add bridge=bridge interface=sfp-sfpplus7
add bridge=bridge interface=sfp-sfpplus8
add bridge=bridge interface=sfp-sfpplus9
add bridge=bridge interface=sfp-sfpplus14
/ip firewall connection tracking
set udp-timeout=10s
/interface bridge vlan
add bridge=bridge tagged="sfp-sfpplus1,sfp-sfpplus2,sfp-sfpplus3,sfp-sfpplus4,\
    sfp-sfpplus5,sfp-sfpplus14,sfp-sfpplus6,sfp-sfpplus7,sfp-sfpplus8,sfp-sfpp\
    lus9" vlan-ids=10
add bridge=bridge tagged="sfp-sfpplus1,sfp-sfpplus2,sfp-sfpplus3,sfp-sfpplus4,\
    sfp-sfpplus5,sfp-sfpplus14,sfp-sfpplus6,sfp-sfpplus7,sfp-sfpplus8,sfp-sfpp\
    lus9" vlan-ids=20
/interface ovpn-server server
add mac-address=FE:3B:75:A9:F2:7E name=ovpn-server1
/ip address
add address=10.90.90.4/24 comment="OOB IP Address" interface=ether1_oob \
    network=10.90.90.0
/ip dns
set servers=1.1.1.1,8.8.8.8
/ip firewall filter
add action=accept chain=input connection-state=established,related,untracked \
    in-interface=ether1_oob src-address=10.90.90.0/24
add action=accept chain=input in-interface=ether1_oob src-address=\
    10.90.90.0/24
add action=drop chain=input
/ip firewall nat
add action=masquerade chain=srcnat out-interface=ether1_oob
/ip hotspot profile
set [ find default=yes ] html-directory=hotspot
/ip ipsec profile
set [ find default=yes ] dpd-interval=2m dpd-maximum-failures=5
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
/ip smb shares
set [ find default=yes ] directory=/flash/pub
/snmp
set enabled=yes
/system clock
set time-zone-name=America/Vancouver
/system identity
set name=CRS317-1
/system note
set show-at-login=no
/system ntp client
set enabled=yes
/system ntp client servers
add address=time.google.com
/system routerboard settings
set enter-setup-on=delete-key
