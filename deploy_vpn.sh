#!/bin/bash
###
# Based on https://www.htpcguides.com/force-torrent-traffic-vpn-split-tunnel-debian-8-ubuntu-16-04/
###

###
# Functions
###
prompt()
{
    echo ""
    read -rsp $'Press enter to continue...\n'
}

beautify(){
    case $2 in
        1)
            echo -e "\n############### $1 ###############\n"
            ;;
        2)
            echo -e "\n***$1***\n"
            ;;
        3)
            echo -e "\n+++$1+++\n"
            ;;
        *)
            echo -e "\n############### $1 ###############\n"
            ;;
    esac
}

setup_var()
{
    # variables
    SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
    PIA_USER="piauser"
    PIA_PW="abc123"
    NET_IF=$(ip -o link show | sed -rn '/^[0-9]+: en/{s/.: ([^:]*):.*/\1/p}')
    LOCAL_IP=$(/sbin/ip -o -4 addr list $NET_IF | awk '{print $4}' | cut -d/ -f1)

    if [ $SUDO_USER ]; then
        REAL_USER=$SUDO_USER
    else
        REAL_USER=$(whoami)
    fi
}

install_packages()
{
    beautify "Install OpenVPN"
    wget https://swupdate.openvpn.net/repos/repo-public.gpg -O - | apt-key add -
    echo "deb http://build.openvpn.net/debian/openvpn/stable xenial main" | tee -a /etc/apt/sources.list.d/openvpn.list
    apt update
    apt install openvpn -y
    echo -e "\nDone"

    beautify "install other packages" 3
    apt install unzip curl vim htop software-properties-common -y
    echo -e "\nDone"
}

openvpn_setup()
    {
    beautify "Create systemd Service for OpenVPN"
    cp src/openvpn@openvpn.service /etc/systemd/system/
    echo "Enabling openvpn@openvpn.service....."
    systemctl enable openvpn@openvpn.service
    echo -e "\nDone"

    beautify "Create PIA Configuration File for Split Tunneling"
    beautify "Get the Required Certificates for PIA" 3
    cd /tmp
    wget https://www.privateinternetaccess.com/openvpn/openvpn.zip
    unzip openvpn.zip
    cp crl.rsa.2048.pem ca.rsa.2048.crt /etc/openvpn/
    cd $SCRIPT_DIR
    echo -e "\nDone"

    beautify "Create Modified PIA Configuration File for Split Tunneling" 3
    cp src/openvpn.conf /etc/openvpn/
    echo -e "\nDone"

    beautify "Make OpenVPN Auto Login on Service Start" 3
    echo $PIA_USER | tee /etc/openvpn/login.txt
    echo $PIA_PW | tee -a /etc/openvpn/login.txt
    echo -e "\nDone"

    beautify "Configure VPN DNS Servers to Stop DNS Leaks" 3
    cp src/update-resolv-conf /etc/openvpn/
    echo -e "\nDone"


    beautify "Split Tunneling with iptables and Routing Tables"
    beautify "Create vpn User" 3
    adduser --disabled-login vpn
    usermod -aG vpn $REAL_USER
    usermod -aG $REAL_USER vpn
    echo -e "\nDone"

    beautify "Block vpn user access to internet" 3
    iptables -F
    iptables -A OUTPUT ! -o lo -m owner --uid-owner vpn -j DROP
    apt install iptables-persistent -y
    echo -e "\nDone"

    beautify "iptables Script for vpn User" 3
    cp src/iptables.sh /etc/openvpn/
    chmod +x /etc/openvpn/iptables.sh
    sed -i "s/192.168.1.100/$LOCAL_IP/" /etc/openvpn/iptables.sh
    sed -i "s/eth0/$NET_IF/" /etc/openvpn/iptables.sh
    beautify "showing first few lines of iptables.sh" 2
    head -8 /etc/openvpn/iptables.sh
    echo -e "\n*************************************************\n" 
    echo -e "\nDone"   
    
    beautify "Routing Rules Script for the Marked Packets" 3
    cp src/routing.sh /etc/openvpn/
    chmod +x /etc/openvpn/routing.sh
    echo -e "\nDone"

    beautify "Configure Split Tunnel VPN Routing" 3
    echo "200     vpn" | tee -a /etc/iproute2/rt_tables
    beautify "showing last few lines of /etc/iproute2/rt_tables" 2
    tail /etc/iproute2/rt_tables
    echo -e "\n*************************************************\n"  
    echo -e "\nDone"  

    beautify "Change Reverse Path Filtering" 3
    cp src/9999-vpn.conf /etc/sysctl.d/
    sed -i "s/eth0/$NET_IF/" /etc/sysctl.d/9999-vpn.conf
    beautify "showing first few lines of 9999-vpn.conf" 2
    head /etc/sysctl.d/9999-vpn.conf
    echo -e "\n*************************************************\n"    
    sysctl --system
    
    beautify "Keep Alive Script"
    cp src/vpn_keepalive.sh /etc/openvpn/
    chmod +x /etc/openvpn/vpn_keepalive.sh
    sed -i "s|/PATH/TO/|$SCRIPT_DIR|" /etc/openvpn/vpn_keepalive.sh

    echo -e "\nDone"


}

###
# Main body of script starts here
###
if ! [ $(id -u) = 0 ]; then
   echo "The script need to be run as root." >&2
   exit 1
fi

set -e
cd $SCRIPT_DIR
clear
setup_var

echo -e "
#################################################################
Script Directory:  $SCRIPT_DIR
Current User:      $REAL_USER
PIA User:          $PIA_USER
PIA Password:      $PIA_PW
Network Interface: $NET_IF
Local IP:          $LOCAL_IP
#################################################################
\n"
prompt

install_packages
openvpn_setup

echo -e "\nCOMPLETE...reboot system to take effect\n"
