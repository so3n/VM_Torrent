#!/bin/bash
# Based on https://www.htpcguides.com/force-torrent-traffic-vpn-split-tunnel-debian-8-ubuntu-16-04/


setup_env()
{
    SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
    LOG_FILE="$SCRIPT_DIR/vm_torrent_install.log"
    PIA_USER="piauser"
    PIA_PW="abc123"
    NET_IF=$(ip -o link show | sed -rn '/^[0-9]+: en/{s/.: ([^:]*):.*/\1/p}')
    LOCAL_IP=$(/sbin/ip -o -4 addr list $NET_IF | awk '{print $4}' | cut -d/ -f1)
    DELUGE_USER="deluge"
    DELUGE_PW="deluge"
    RED="\e[31m"
    GREEN="\e[32m"
    YELLOW="\e[93m"
    NC="\e[0m" # No Color

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

openvpn_setup()
{
    if grep -q "openvpn_setup: completed" $LOG_FILE; then
        echo -e "\n${RED}This script has already installed openvpn previously${NC}\n"
        return 0
    fi

    echo "$(date '+%Y-%m-%d %H:%M:%S') openvpn_setup: start" >> $LOG_FILE

    # Install Packages
    echo -e "\n${YELLOW}$(date '+%Y-%m-%d %H:%M:%S') Install Packages${NC}\n"
    wget https://swupdate.openvpn.net/repos/repo-public.gpg -O - | apt-key add -
    echo "deb http://build.openvpn.net/debian/openvpn/stable xenial main" | tee -a /etc/apt/sources.list.d/openvpn.list
    apt-get update
    apt-get install openvpn unzip curl vim htop software-properties-common -y
    echo -e "\n${GREEN}$(date '+%Y-%m-%d %H:%M:%S') Done${NC}\n"

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
    adduser --disabled-login --gecos "" vpn
    usermod -aG vpn $REAL_USER
    usermod -aG $REAL_USER vpn
    echo -e "\n${GREEN}$(date '+%Y-%m-%d %H:%M:%S') Done${NC}\n"

    echo -e "\n${YELLOW}$(date '+%Y-%m-%d %H:%M:%S') Block vpn user access to internet${NC}\n"
    iptables -F
    iptables -A OUTPUT ! -o lo -m owner --uid-owner vpn -j DROP
    echo iptables-persistent iptables-persistent/autosave_v4 boolean true | debconf-set-selections
    echo iptables-persistent iptables-persistent/autosave_v6 boolean true | debconf-set-selections
    apt-get install iptables-persistent -y
    echo -e "\n${GREEN}$(date '+%Y-%m-%d %H:%M:%S') Done${NC}\n"

    echo -e "\n${YELLOW}$(date '+%Y-%m-%d %H:%M:%S') iptables Script for vpn User${NC}\n"
    cp src/iptables.sh /etc/openvpn/
    chmod +x /etc/openvpn/iptables.sh
    sed -i "s/192.168.1.100/$LOCAL_IP/" /etc/openvpn/iptables.sh
    sed -i "s/eth0/$NET_IF/" /etc/openvpn/iptables.sh
    # echo -e "showing first few lines of iptables.sh${NC}\n"
    # head -8 /etc/openvpn/iptables.sh
    echo -e "\n${GREEN}$(date '+%Y-%m-%d %H:%M:%S') Done${NC}\n"

    echo -e "\n${YELLOW}$(date '+%Y-%m-%d %H:%M:%S') Routing Rules Script for the Marked Packets${NC}\n"
    cp src/routing.sh /etc/openvpn/
    chmod +x /etc/openvpn/routing.sh
    echo -e "\n${GREEN}$(date '+%Y-%m-%d %H:%M:%S') Done${NC}\n"

    echo -e "\n${YELLOW}$(date '+%Y-%m-%d %H:%M:%S') Configure Split Tunnel VPN Routing${NC}\n"
    echo "200     vpn" | tee -a /etc/iproute2/rt_tables
    # echo -e "showing last few lines of /etc/iproute2/rt_tables${NC}\n"
    # tail /etc/iproute2/rt_tables
    echo -e "\n${GREEN}$(date '+%Y-%m-%d %H:%M:%S') Done${NC}\n"

    echo -e "\n${YELLOW}$(date '+%Y-%m-%d %H:%M:%S') Change Reverse Path Filtering${NC}\n"
    cp src/9999-vpn.conf /etc/sysctl.d/
    sed -i "s/eth0/$NET_IF/" /etc/sysctl.d/9999-vpn.conf
    # echo -e "showing first few lines of 9999-vpn.conf${NC}\n"
    # head /etc/sysctl.d/9999-vpn.conf
    sysctl --system

    # Keep Alive Script
    echo -e "\n${YELLOW}$(date '+%Y-%m-%d %H:%M:%S') Setup Keep Alive Script${NC}\n"
    cp src/vpn_keepalive.sh /etc/openvpn/
    chmod +x /etc/openvpn/vpn_keepalive.sh
    sed -i "s|/PATH/TO|$SCRIPT_DIR|" /etc/openvpn/vpn_keepalive.sh
    # echo -e "showing last few lines of vpn_keepalive.sh${NC}\n"
    # tail /etc/openvpn/vpn_keepalive.sh

    echo "$(date '+%Y-%m-%d %H:%M:%S') openvpn_setup: completed" >> $LOG_FILE
    echo -e "\n${GREEN}$(date '+%Y-%m-%d %H:%M:%S') Done${NC}\n"
}

deluge_setup()
{

    if grep -q "deluge_setup: completed" $LOG_FILE; then
        echo -e "\n${RED}This script has already installed Deluge previously${NC}\n"
        return 0
    fi

    echo "$(date '+%Y-%m-%d %H:%M:%S') deluge_setup: start" >> $LOG_FILE

    echo -e "\n${YELLOW}$(date '+%Y-%m-%d %H:%M:%S') Install Deluge and Web UI on Ubuntu 16.04 LTS${NC}\n"
    add-apt-repository ppa:deluge-team/ppa -y
    apt-get update
    apt-get install deluged deluge-web -y
    echo -e "\n${GREEN}$(date '+%Y-%m-%d %H:%M:%S') Done${NC}\n"

    echo -e "\n${YELLOW}$(date '+%Y-%m-%d %H:%M:%S') Configure Deluge Logging${NC}\n"
    mkdir -p /var/log/deluge
    chown -R vpn:vpn /var/log/deluge
    chmod -R 770 /var/log/deluge
    cp src/deluge /etc/logrotate.d/
    echo -e "\n${GREEN}$(date '+%Y-%m-%d %H:%M:%S') Done${NC}\n"

    echo -e "\n${YELLOW}$(date '+%Y-%m-%d %H:%M:%S') Create the Systemd Unit for Deluge Daemon${NC}\n"
    cp src/deluged.service /etc/systemd/system/
    systemctl enable deluged.service
    systemctl start deluged.service
    echo -e "\n${GREEN}$(date '+%Y-%m-%d %H:%M:%S') Done${NC}\n"

    echo -e "\n${YELLOW}$(date '+%Y-%m-%d %H:%M:%S') Create the Systemd Unit for Deluge Web UI${NC}\n"
    cp src/deluge-web.service /etc/systemd/system/
    systemctl enable deluge-web.service
    systemctl start deluge-web.service
    echo -e "\n${GREEN}$(date '+%Y-%m-%d %H:%M:%S') Done${NC}\n"

    echo -e "\n${YELLOW}$(date '+%Y-%m-%d %H:%M:%S') Make Deluge Web UI Auto Connect to Deluge Daemon${NC}\n"
    sleep 20
    systemctl stop deluged.service
    systemctl stop deluge-web.service
    sed -i 's/"default_daemon": ""/"default_daemon": "127.0.0.1:58846"/' /home/vpn/.config/deluge/web.conf
    # echo -e "\n${YELLOW}$(date '+%Y-%m-%d %H:%M:%S') Contents of /home/vpn/.config/deluge/web.conf${NC}\n"
    # cat /home/vpn/.config/deluge/web.conf
    systemctl start deluged.service
    systemctl start deluge-web.service
    echo -e "\n${GREEN}$(date '+%Y-%m-%d %H:%M:%S') Done${NC}\n"

    echo -e "\n${YELLOW}$(date '+%Y-%m-%d %H:%M:%S') Configure Deluge Remote Access with nginx Reverse Proxy${NC}\n"
    apt-get update
    apt-get install nginx -y
    unlink /etc/nginx/sites-enabled/default
    cp src/reverse /etc/nginx/sites-available/
    sed -i "s/192.168.1.100/$LOCAL_IP/" /etc/nginx/sites-available/reverse
    # echo -e "\n${YELLOW}$(date '+%Y-%m-%d %H:%M:%S') Contents of /etc/nginx/sites-available/reverse${NC}\n"
    # cat /etc/nginx/sites-available/reverse
    ln -s /etc/nginx/sites-available/reverse /etc/nginx/sites-enabled/reverse
    echo -e "\n${GREEN}$(date '+%Y-%m-%d %H:%M:%S') Done${NC}\n"

    echo -e "\n${YELLOW}$(date '+%Y-%m-%d %H:%M:%S') Test the nginx configuration is valid${NC}\n"
    nginx -t
    systemctl restart nginx.service
    systemctl start deluged.service
    echo -e "\n${GREEN}$(date '+%Y-%m-%d %H:%M:%S') Done${NC}\n"

    # Configure Auto Port Forward PIA VPN for Deluge
    echo -e "\n${YELLOW}$(date '+%Y-%m-%d %H:%M:%S') Configure Auto Port Forward PIA VPN for Deluge${NC}\n"
    cp src/portforward.sh /etc/openvpn/
    chmod +x /etc/openvpn/portforward.sh
    sudo echo "$DELUGE_USER:$DELUGE_PW:10" >> /home/vpn/.config/deluge/auth
    sed -i -r "s/USERNAME=\*{6}/USERNAME=$PIA_USER/" /etc/openvpn/portforward.sh
    sed -i -r "s/PASSWORD=\*{6}/PASSWORD=$PIA_PW/" /etc/openvpn/portforward.sh
    sed -i -r "s/DELUGEUSER=\*{6}/DELUGEUSER=$DELUGE_USER/" /etc/openvpn/portforward.sh
    sed -i -r "s/DELUGEPASS=\*{6}/DELUGEPASS=$DELUGE_PW/" /etc/openvpn/portforward.sh
    # echo -e "\n${YELLOW}$(date '+%Y-%m-%d %H:%M:%S') Showing first few lines of /etc/openvpn/portforward.sh${NC}\n"
    # head -n 22 /etc/openvpn/portforward.sh
    echo -e "\n${GREEN}$(date '+%Y-%m-%d %H:%M:%S') Done${NC}\n"

    echo -e "\n${YELLOW}$(date '+%Y-%m-%d %H:%M:%S') Install Deluge Console${NC}\n"
    apt-get update
    apt-get install deluge-console -y
    echo -e "\n${GREEN}$(date '+%Y-%m-%d %H:%M:%S') Done${NC}\n"

    echo "$(date '+%Y-%m-%d %H:%M:%S') deluge_setup: completed" >> $LOG_FILE
}

error() {
    echo -e "${RED}$(date '+%Y-%m-%d %H:%M:%S') Exiting due to Error${NC}\n"
}

menu() {
    options=("OpenVPN" "Deluge" "All" "Quit")
    PS3=$'\n\e[36mWhat do we want to install? \e[0m'

    while true; do
        select opt in "${options[@]}"; do
            case $opt in
                "OpenVPN") openvpn_setup; break ;;
                "Deluge") deluge_setup; break;;
                "All") openvpn_setup; deluge_setup; break ;;
                "Quit") break 2 ;;
                *) echo "Oh No! That's not a valid option" >&2
            esac
            echo "Press Enter to display menu again" >&2
        done
    done
}



### LET'S DO THIS!

if ! [ $(id -u) = 0 ]; then
   echo "The script needs to be run as root." >&2
   exit 1
fi

set -e
trap error ERR

setup_env
touch $LOG_FILE
menu
# openvpn_setup
# deluge_setup
# auto_portforward_setup
echo 'Bye!'