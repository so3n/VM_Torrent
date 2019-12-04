#!/bin/bash

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

echo "
#################################################################
Current Directory: $CURRENTDIR
Current User:      $USER
PIA User:          $PIA_USER
PIA Password:      $PIA_PW  
Network Interface  $NET_IF
Local IP           $LOCAL_IP
#################################################################

"
prompt
}

openvpn_setup()
{
echo "### Install OpenVPN ###"
prompt
wget https://swupdate.openvpn.net/repos/repo-public.gpg -O - | sudo apt-key add -
echo "deb http://build.openvpn.net/debian/openvpn/stable xenial main" | sudo tee -a /etc/apt/sources.list.d/openvpn.list
sudo apt-get update
sudo apt-get install openvpn -y

echo "### Create systemd Service for OpenVPN ###"
prompt
sudo cp src/openvpn@openvpn.service /etc/systemd/system/
echo "Enabling openvpn@openvpn.service....."
sudo systemctl enable openvpn@openvpn.service

echo "### Create PIA Configuration File for Split Tunneling ###"
prompt
sudo apt-get install unzip -y
cd /tmp
sudo wget https://www.privateinternetaccess.com/openvpn/openvpn.zip
sudo unzip openvpn.zip
sudo cp crl.rsa.2048.pem ca.rsa.2048.crt /etc/openvpn/
cd $CURRENTDIR
sudo cp src/openvpn.conf /etc/openvpn/
sudo echo $PIA_USER > /etc/openvpn/login.txt
sudo echo $PIA_PW >> /etc/openvpn/login.txt
sudo cp src/update-resolv-conf /etc/openvpn/

echo "### Split Tunneling with iptables and Routing Tables ###"
prompt
sudo adduser --disabled-login vpn
sudo usermod -aG vpn $USER
sudo usermod -aG $USER vpn
sudo iptables -F
sudo iptables -A OUTPUT ! -o lo -m owner --uid-owner vpn -j DROP
sudo apt-get install iptables-persistent -y
sudo cp /src/iptables.sh /etc/openvpn/
sudo chmod +x /etc/openvpn/iptables.sh
sudo cp /src/routing.sh /etc/openvpn/
sudo chmod +x /etc/openvpn/routing.sh
sudo echo "200     vpn" >> /etc/iproute2/rt_tables
sudo cp /src/9999-vpn.conf /etc/sysctl.d/
sudo sysctl --system

echo "COMPLETE...run the following to test:
    * Test OpenVPN service:             sudo systemctl status openvpn@openvpn.service
    * Check IP address:                 curl ipinfo.io
    * Check IP address of VPN user:     sudo -u vpn -i -- curl ipinfo.io
    * Check DNS Server:                 sudo -u vpn -i -- cat /etc/resolv.conf
"
}

###
# Main body of script starts here
###
#set -e
setup_env
openvpn_setup
