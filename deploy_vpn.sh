#!/bin/bash
# Based on https://www.htpcguides.com/force-torrent-traffic-vpn-split-tunnel-debian-8-ubuntu-16-04/


setup_env()
{
    SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
    PIA_USER="piauser"
    PIA_PW="abc123"
    NET_IF=$(ip -o link show | sed -rn '/^[0-9]+: en/{s/.: ([^:]*):.*/\1/p}')
    LOCAL_IP=$(/sbin/ip -o -4 addr list $NET_IF | awk '{print $4}' | cut -d/ -f1)
	
    RED="\033[0;31m"
    GREEN="\033[0;32m"
    YELLOW="\033[1;33m"
    NC="\033[0m" # No Color

    if [ $SUDO_USER ]; then
        REAL_USER=$SUDO_USER
    else
        REAL_USER=$(whoami)
    fi

    cd $SCRIPT_DIR

    echo -e "
#################################################################
Script Directory:  $SCRIPT_DIR
Current User:      $REAL_USER
PIA User:          $PIA_USER
PIA Password:      $PIA_PW
Network Interface: $NET_IF
Local IP:          $LOCAL_IP
#################################################################
    ${NC}\n"
}

install_packages()
{
    # Install Packages
    echo -e "\n${YELLOW}$(date '+%Y-%m-%d %H:%M:%S') Install Packages${NC}\n"
    wget https://swupdate.openvpn.net/repos/repo-public.gpg -O - | apt-key add -
    echo "deb http://build.openvpn.net/debian/openvpn/stable xenial main" | tee -a /etc/apt/sources.list.d/openvpn.list
    apt update
    apt install openvpn unzip curl vim htop software-properties-common -y
    echo -e "\n${GREEN}$(date '+%Y-%m-%d %H:%M:%S') Done${NC}\n"
}

openvpn_setup()
{
    # Create systemd Service for OpenVPN
    echo -e "\n${YELLOW}$(date '+%Y-%m-%d %H:%M:%S') Enabling openvpn@openvpn.service${NC}\n"
    cp src/openvpn@openvpn.service /etc/systemd/system/
    systemctl enable openvpn@openvpn.service
    echo -e "\n${GREEN}$(date '+%Y-%m-%d %H:%M:%S') Done${NC}\n"

    # Create PIA Configuration File for Split Tunneling
    echo -e "\n${YELLOW}$(date '+%Y-%m-%d %H:%M:%S') Get the Required Certificates for PIA${NC}\n"
    cd /tmp
    wget https://www.privateinternetaccess.com/openvpn/openvpn.zip
    unzip openvpn.zip
    cp crl.rsa.2048.pem ca.rsa.2048.crt /etc/openvpn/
    cd $SCRIPT_DIR
    echo -e "\n${GREEN}$(date '+%Y-%m-%d %H:%M:%S') Done${NC}\n"

    echo -e "\n${YELLOW}$(date '+%Y-%m-%d %H:%M:%S') Create Modified PIA Configuration File for Split Tunneling${NC}\n"
    cp src/openvpn.conf /etc/openvpn/
    echo -e "\n${GREEN}$(date '+%Y-%m-%d %H:%M:%S') Done${NC}\n"

    echo -e "\n${YELLOW}$(date '+%Y-%m-%d %H:%M:%S') Make OpenVPN Auto Login on Service Start${NC}\n"
    echo $PIA_USER | tee /etc/openvpn/login.txt
    echo $PIA_PW | tee -a /etc/openvpn/login.txt
    echo -e "\n${GREEN}$(date '+%Y-%m-%d %H:%M:%S') Done${NC}\n"

    echo -e "\n${YELLOW}$(date '+%Y-%m-%d %H:%M:%S') Configure VPN DNS Servers to Stop DNS Leaks${NC}\n"
    cp src/update-resolv-conf /etc/openvpn/
    echo -e "\n${GREEN}$(date '+%Y-%m-%d %H:%M:%S') Done${NC}\n"

    # Split Tunneling with iptables and Routing Tables
    echo -e "\n${YELLOW}$(date '+%Y-%m-%d %H:%M:%S') Create vpn User${NC}\n"
    adduser --disabled-login vpn
    usermod -aG vpn $REAL_USER
    usermod -aG $REAL_USER vpn
    echo -e "\n${GREEN}$(date '+%Y-%m-%d %H:%M:%S') Done${NC}\n"

    echo -e "\n${YELLOW}$(date '+%Y-%m-%d %H:%M:%S') Block vpn user access to internet${NC}\n"
    iptables -F
    iptables -A OUTPUT ! -o lo -m owner --uid-owner vpn -j DROP
    apt install iptables-persistent -y
    echo -e "\n${GREEN}$(date '+%Y-%m-%d %H:%M:%S') Done${NC}\n"

    echo -e "\n${YELLOW}$(date '+%Y-%m-%d %H:%M:%S') iptables Script for vpn User${NC}\n"
    cp src/iptables.sh /etc/openvpn/
    chmod +x /etc/openvpn/iptables.sh
    sed -i "s/192.168.1.100/$LOCAL_IP/" /etc/openvpn/iptables.sh
    sed -i "s/eth0/$NET_IF/" /etc/openvpn/iptables.sh
    # echo -e "showing first few lines of iptables.sh" 2
    # head -8 /etc/openvpn/iptables.sh
    echo -e "\n${GREEN}$(date '+%Y-%m-%d %H:%M:%S') Done${NC}\n"   
    
    echo -e "\n${YELLOW}$(date '+%Y-%m-%d %H:%M:%S') Routing Rules Script for the Marked Packets${NC}\n"
    cp src/routing.sh /etc/openvpn/
    chmod +x /etc/openvpn/routing.sh
    echo -e "\n${GREEN}$(date '+%Y-%m-%d %H:%M:%S') Done${NC}\n"

    echo -e "\n${YELLOW}$(date '+%Y-%m-%d %H:%M:%S') Configure Split Tunnel VPN Routing${NC}\n"
    echo "200     vpn" | tee -a /etc/iproute2/rt_tables
    # echo -e "showing last few lines of /etc/iproute2/rt_tables" 2
    # tail /etc/iproute2/rt_tables
    echo -e "\n${GREEN}$(date '+%Y-%m-%d %H:%M:%S') Done${NC}\n"  

    echo -e "\n${YELLOW}$(date '+%Y-%m-%d %H:%M:%S') Change Reverse Path Filtering${NC}\n"
    cp src/9999-vpn.conf /etc/sysctl.d/
    sed -i "s/eth0/$NET_IF/" /etc/sysctl.d/9999-vpn.conf
    # echo -e "showing first few lines of 9999-vpn.conf" 2
    # head /etc/sysctl.d/9999-vpn.conf   
    sysctl --system
    
    # Keep Alive Script
    echo -e "\n${YELLOW}$(date '+%Y-%m-%d %H:%M:%S') Setup Keep Alive Script${NC}\n"
    cp src/vpn_keepalive.sh /etc/openvpn/
    chmod +x /etc/openvpn/vpn_keepalive.sh
    sed -i "s|/PATH/TO|$SCRIPT_DIR|" /etc/openvpn/vpn_keepalive.sh
    # echo -e "showing last few lines of vpn_keepalive.sh" 2
    # tail /etc/openvpn/vpn_keepalive.sh
    echo -e "\n${GREEN}$(date '+%Y-%m-%d %H:%M:%S') Done${NC}\n"
}

prompt()
{
    echo ""
    read -rsp $'Press enter to continue...\n'
}

error() {
    echo -e "${RED}$(date '+%Y-%m-%d %H:%M:%S') Exiting due to Error${NC}\n"
}


### LET'S DO THIS!

if ! [ $(id -u) = 0 ]; then
   echo "The script need to be run as root." >&2
   exit 1
fi

set -e
trap error ERR
clear
setup_env
prompt
install_packages
openvpn_setup
echo -e "\n${GREEN}$(date '+%Y-%m-%d %H:%M:%S') COMPLETE...reboot system to take effect${NC}\n"
