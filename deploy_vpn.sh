#!/bin/bash
###
# Based on https://www.htpcguides.com/force-torrent-traffic-vpn-split-tunnel-debian-8-ubuntu-16-04/
###

###
# Functions
###
prompt()
{
read -rsp $'Press enter to continue...\n'
}

setup_env()
{
export CURRENTDIR=$(pwd)
export PIA_USER="piauser"
export PIA_PW="abc123"
export NET_IF=$(ip -o link show | sed -rn '/^[0-9]+: en/{s/.: ([^:]*):.*/\1/p}')
export LOCAL_IP=$(/sbin/ip -o -4 addr list $NET_IF | awk '{print $4}' | cut -d/ -f1)

if [ $SUDO_USER ]; then
    REAL_USER=$SUDO_USER
else
    REAL_USER=$(whoami)
fi

echo -e "
#################################################################
Current Directory: $CURRENTDIR
Current User:      $REAL_USER
PIA User:          $PIA_USER
PIA Password:      $PIA_PW
Network Interface  $NET_IF
Local IP           $LOCAL_IP
#################################################################
\n"
prompt
}

install_packages()
{
echo -e "\n############### Install OpenVPN ###############\n"
wget https://swupdate.openvpn.net/repos/repo-public.gpg -O - | apt-key add -
echo "deb http://build.openvpn.net/debian/openvpn/stable xenial main" | tee -a /etc/apt/sources.list.d/openvpn.list
apt update
apt install openvpn -y
echo -e "\nDone"

echo -e "\n+++install other packages\n"
apt install unzip curl -y
echo -e "\nDone"
prompt
}

openvpn_setup()
{
echo -e "\n############### Create systemd Service for OpenVPN ###############\n"
cp src/openvpn@openvpn.service /etc/systemd/system/
echo "Enabling openvpn@openvpn.service....."
systemctl enable openvpn@openvpn.service
echo -e "\nDone"
prompt

echo -e "\n###############  Create PIA Configuration File for Split Tunneling ###############\n"

echo -e "\n+++Get the Required Certificates for PIA"
cd /tmp
wget https://www.privateinternetaccess.com/openvpn/openvpn.zip
unzip openvpn.zip
cp crl.rsa.2048.pem ca.rsa.2048.crt /etc/openvpn/
cd $CURRENTDIR
echo -e "\nDone"

echo -e "\n+++Create Modified PIA Configuration File for Split Tunneling\n"
cp src/openvpn.conf /etc/openvpn/
echo -e "\nDone"

echo -e "\n+++Make OpenVPN Auto Login on Service Start\n"
echo $PIA_USER | tee /etc/openvpn/login.txt
echo $PIA_PW | tee -a /etc/openvpn/login.txt
echo -e "\nDone"

echo -e "\n+++Configure VPN DNS Servers to Stop DNS Leaks\n"
cp src/update-resolv-conf /etc/openvpn/
echo -e "\nDone"
prompt


echo -e "\n############### Split Tunneling with iptables and Routing Tables ###############\n"

echo -e "\n+++Create vpn User\n"
adduser --disabled-login vpn
usermod -aG vpn $REAL_USER
usermod -aG $REAL_USER vpn
echo -e "\nDone"

echo -e "\n+++Block vpn user access to internet\n"
iptables -F
iptables -A OUTPUT ! -o lo -m owner --uid-owner vpn -j DROP
apt install iptables-persistent -y
echo -e "\nDone"

echo -e "\n+++iptables Script for vpn User\n"
cp src/iptables.sh /etc/openvpn/
chmod +x /etc/openvpn/iptables.sh
sed -i "s/192.168.1.100/$LOCAL_IP/" /etc/openvpn/iptables.sh
sed -i "s/eth0/$NET_IF/" /etc/openvpn/iptables.sh
echo "***showing first few lines of iptables.sh***"
head -8 /etc/openvpn/iptables.sh
prompt

echo -e "\n+++Routing Rules Script for the Marked Packets\n"
cp src/routing.sh /etc/openvpn/
chmod +x /etc/openvpn/routing.sh
echo -e "\nDone"

echo -e "\n+++Configure Split Tunnel VPN Routing\n"
echo "200     vpn" | tee -a /etc/iproute2/rt_tables
echo "***showing last few lines of /etc/iproute2/rt_tables***"
tail /etc/iproute2/rt_tables
prompt

echo -e "\n+++Change Reverse Path Filtering\n"
cp src/9999-vpn.conf /etc/sysctl.d/
sed -i "s/eth0/$NET_IF/" src/9999-vpn.conf
echo "***showing first few lines of iptables.sh***"
head src/9999-vpn.conf
prompt
sysctl --system

echo -e "\n
COMPLETE...reboot and then run the following to test:
    * Test OpenVPN service:             sudo systemctl status openvpn@openvpn.service
    * Check IP address:                 curl ipinfo.io
    * Check IP address of VPN user:     sudo -u vpn -i -- curl ipinfo.io
    * Check DNS Server:                 sudo -u vpn -i -- cat /etc/resolv.conf
\n"
}

###
# Main body of script starts here
###
if ! [ $(id -u) = 0 ]; then
   echo "The script need to be run as root." >&2
   exit 1
fi

set -e
clear
setup_env
install_packages
openvpn_setup
