# 2025-03-04 17:25:30 by RouterOS 7.16.2
# software id = T11Z-BLUY
#
# model = RB5009UG+S+
# serial number = HH00A5R8NXQ
/interface ethernet
set [ find default-name=ether1 ] comment="eStrux Wan Peer #1" name=ether1_wan
set [ find default-name=ether2 ] disabled=yes
set [ find default-name=ether3 ] disabled=yes
set [ find default-name=ether4 ] disabled=yes
set [ find default-name=ether5 ] disabled=yes
set [ find default-name=ether6 ] disabled=yes
set [ find default-name=ether7 ] disabled=yes
set [ find default-name=ether8 ] comment="OOB Configuration Port" name=\
    ether8_oob
set [ find default-name=sfp-sfpplus1 ] comment="Downlink Trunk Port" name=\
    sfpplus1_CRS317-1
/interface vlan
add interface=sfpplus1_CRS317-1 name=vlan10 vlan-id=10
add interface=sfpplus1_CRS317-1 name=vlan20 vlan-id=20
/ip neighbor discovery-settings
set discover-interface-list=!dynamic
/ip address
add address=38.186.49.164/29 comment="1st Public IP Address" interface=\
    ether1_wan network=38.186.49.160
add address=38.186.49.165/29 comment="2nd Public IP Address" interface=\
    ether1_wan network=38.186.49.160
add address=38.186.49.166/29 comment="3rd Public IP Address" interface=\
    ether1_wan network=38.186.49.160
add address=10.20.10.1/24 comment="Mgmt Gateway IP" interface=vlan10 network=\
    10.20.10.0
add address=10.90.90.1/24 comment="OOB Gateway IP" interface=ether8_oob \
    network=10.90.90.0
add address=10.20.20.1/24 comment="VM Gateway IP" interface=vlan20 network=\
    10.20.20.0
add address=172.16.10.254/24 comment="Metal LB" interface=vlan20 network=\
    172.16.10.0
add address=192.168.0.1/16 comment="New VM Gateway" interface=vlan20 network=\
    192.168.0.0
/ip dns
set allow-remote-requests=yes servers=1.1.1.1,8.8.8.8
/ip firewall address-list
add address=10.90.90.0/24 comment="OOB Subnet" list=Private
add address=10.20.10.0/24 comment="Mgmt Subnet" list=Private
add address=10.20.20.0/24 comment="VM Subnet" list=Public
/ip firewall filter
add action=drop chain=input comment="Block Port Scanner List" \
    src-address-list="Port Scanner Block List"
add action=add-src-to-address-list address-list="Port Scanner Block List" \
    address-list-timeout=1d chain=input comment="Port Scanner Detection" \
    protocol=tcp psd=21,3s,3,1
add action=accept chain=input comment="Allow Est, Related, & Untracked" \
    connection-state=established,related,untracked
add action=add-src-to-address-list address-list="PK Stage 1" \
    address-list-timeout=30s chain=input comment="Port Knocking Stage 1" \
    dst-port=36110 in-interface=ether1_wan protocol=tcp
add action=add-src-to-address-list address-list="PK Stage2" \
    address-list-timeout=30s chain=input comment="Port Knocking Stage 2" \
    dst-port=4321 in-interface=ether1_wan protocol=tcp src-address-list=\
    "PK Stage 1"
add action=add-src-to-address-list address-list="Trysted IP's" \
    address-list-timeout=1d chain=input comment="Port Knocking Complete" \
    dst-port=22330 in-interface=ether1_wan protocol=tcp src-address-list=\
    "PK Stage2"
add action=accept chain=input comment="Allow from Trusted IP's" in-interface=\
    ether1_wan src-address-list="Trysted IP's"
add action=accept chain=input comment="Allow ICMP" protocol=icmp
add action=accept chain=input comment="Allow from OOB Subnet" in-interface=\
    ether8_oob src-address=10.90.90.0/24
add action=drop chain=input comment="Drop All Remaining Traffic"
add action=accept chain=forward comment="Allow Est, Related & Untracked" \
    connection-state=established,related,untracked
add action=accept chain=forward comment="Allow Private to Public" disabled=\
    yes dst-address-list=Public src-address-list=Private
add action=accept chain=forward comment="Allow Private to Internet" disabled=\
    yes out-interface=ether1_wan src-address-list=Private
add action=accept chain=forward comment="Allow Public to Internet" disabled=\
    yes out-interface=ether1_wan src-address-list=Public
add action=accept chain=forward comment="Forward http - VM" disabled=yes \
    dst-address=192.168.0.3 dst-port=80 protocol=tcp src-address=70.66.209.81
add action=accept chain=forward comment="Forward https - VM" disabled=yes \
    dst-address=192.168.0.3 dst-port=443 protocol=tcp src-address=\
    70.66.209.81
add action=accept chain=forward comment="Forward http" dst-address=\
    172.16.10.0 dst-port=80 protocol=tcp
add action=accept chain=forward comment="Forward https" dst-address=\
    172.16.10.0 dst-port=443 protocol=tcp
add action=accept chain=forward comment="sftp1 forward" dst-address=\
    10.20.10.23 dst-port=2222 protocol=tcp
add action=accept chain=forward comment="sftp2 forward" dst-address=\
    10.20.10.24 dst-port=2222 protocol=tcp
add action=accept chain=forward comment="Forward http hotel 19" dst-address=\
    10.20.20.221 dst-port=80 protocol=tcp
add action=accept chain=forward comment="Forward https hotel 19" dst-address=\
    10.20.20.221 dst-port=443 protocol=tcp
add action=drop chain=forward comment="Drop All Remaining Traffic" disabled=\
    yes
/ip firewall nat
add action=masquerade chain=srcnat comment=\
    "Allow Outbound Connections from Lan" out-interface=ether1_wan
add action=dst-nat chain=dstnat comment="Forward Public Port 80" dst-address=\
    38.186.49.164 dst-port=80 in-interface=ether1_wan protocol=tcp \
    to-addresses=172.16.10.1 to-ports=80
add action=dst-nat chain=dstnat comment="Forward Public Port 443" \
    dst-address=38.186.49.164 dst-port=443 in-interface=ether1_wan protocol=\
    tcp to-addresses=172.16.10.1 to-ports=443
add action=dst-nat chain=dstnat comment="Forward Public Port 2211 (sftp1)" \
    dst-address=38.186.49.164 dst-port=2211 in-interface=ether1_wan protocol=\
    tcp to-addresses=10.20.10.23 to-ports=2222
add action=dst-nat chain=dstnat comment="Forward Public Port 2222 (sftp2)" \
    dst-address=38.186.49.164 dst-port=2222 in-interface=ether1_wan protocol=\
    tcp to-addresses=10.20.10.24 to-ports=2222
add action=dst-nat chain=dstnat comment="Forward Public Port 80 - Hotel 19" \
    dst-address=38.186.49.165 dst-port=80 in-interface=ether1_wan protocol=\
    tcp to-addresses=10.20.20.221 to-ports=80
add action=dst-nat chain=dstnat comment="Forward Public Port 443 - Hotel 19" \
    dst-address=38.186.49.165 dst-port=443 in-interface=ether1_wan protocol=\
    tcp to-addresses=10.20.20.221 to-ports=443
add action=dst-nat chain=dstnat comment="Forward Public Port 80 - VM" \
    disabled=yes dst-address=38.186.49.166 dst-port=80 in-interface=\
    ether1_wan protocol=tcp to-addresses=192.168.0.3 to-ports=8080
add action=dst-nat chain=dstnat comment="Forward Public Port 443 - VM" \
    disabled=yes dst-address=38.186.49.166 dst-port=443 in-interface=\
    ether1_wan protocol=tcp to-addresses=192.168.0.3 to-ports=8443
/ip route
add disabled=no distance=1 dst-address=0.0.0.0/0 gateway=38.186.49.161 \
    routing-table=main scope=30 suppress-hw-offload=no target-scope=10
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
set time-zone-autodetect=no time-zone-name=America/Vancouver
/system identity
set name=RB5009-1
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
