#!/bin/bash

# References
# https://www.htpcguides.com/force-torrent-traffic-vpn-split-tunnel-debian-8-ubuntu-16-04/
# https://www.htpcguides.com/configure-deluge-for-vpn-split-tunneling-ubuntu-16-04/
# https://www.htpcguides.com/configure-auto-port-forward-pia-vpn-for-deluge/

usage() {
    echo "Usage: ./setup.sh [OPTION]"
    echo ""
    echo "    -i  LOCAL_IP     Manually specify LOCAL_IP"
    echo "    -f  NET_IF       Manually specify network interface NET_IF"
    echo "    -n               Non-interactive Mode"
    echo "    -p  USER:PWD     PIA user and password in format USER:PWD"
    echo "                      If option not used, defaults to piauser:piapwd to be"
    echo "                      manually updated later"
    echo "    -d  USER:PWD     Override USER:PWD to use for deluge daemon in the"
    echo "                      auto portforward script. Default is deluge:deluge"
    echo "    -s  PIA_SERVER   VPN Server location to use with PIA. Refer to"
    echo "                      pia-servers.txt for list of valid servers. If option"
    echo "                      not used, defaults to swiss.privateinternetaccess.com"
    echo ""
}

setup_var()
{
    # variables to be used by this script
    SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
    LOG_FILE="$SCRIPT_DIR/vm_torrent_install.log"
    NET_IF=$(ip -o link show | sed -rn '/^[0-9]+: en/{s/.: ([^:]*):.*/\1/p}')
    LOCAL_IP=$(/sbin/ip -o -4 addr list $NET_IF | awk '{print $4}' | cut -d/ -f1)

    # https://misc.flogisoft.com/bash/tip_colors_and_formatting
    NC="\e[0m" # no color/remove formatting
    BOLD="\e[1m"
    RED="\e[31m"
    GREEN="\e[32m"
    YELLOW="\e[33m"
    BLUE="\e[34m"
    PURPLE="\e[35m"
    CYAN="\e[36m"
    LIGHT_GRAY="\e[37m"
    DARK_GRAY="\e[90m"
    LIGHT_RED="\e[91m"
    LIGHT_GREEN="\e[92m"
    LIGHT_YELLOW="\e[93m"
    LIGHT_BLUE="\e[94m"
    LIGHT_PURPLE="\e[95m"
    LIGHT_CYAN="\e[96m"
    WHITE="\e[97m"

    # get user
    if [ $SUDO_USER ]; then
        REAL_USER=$SUDO_USER
    else
        REAL_USER=$(whoami)
    fi
}

openvpn_setup()
{
    if [ -n "$(grep 'openvpn_setup: completed' $LOG_FILE)" ]; then
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
    grep "remote.*1198" ~/openvpn/*.ovpn | cut -d ":" -f 2 | cut -d " " -f 2 > $SCRIPT_DIR/pia-servers.txt
    cd $SCRIPT_DIR
    echo -e "\n${GREEN}$(date '+%Y-%m-%d %H:%M:%S') Done${NC}\n"

    echo -e "\n${YELLOW}$(date '+%Y-%m-%d %H:%M:%S') Create Modified PIA Configuration File for Split Tunneling${NC}\n"
    cp src/openvpn.conf /etc/openvpn/
    if [ -n $PIA_SERVER ]; then
        sed -i "s/^remote.*1198/remote $PIA_SERVER 1198/" /etc/openvpn/openvpn.conf
    fi
    echo -e "\n${GREEN}$(date '+%Y-%m-%d %H:%M:%S') Done${NC}\n"

    echo -e "\n${YELLOW}$(date '+%Y-%m-%d %H:%M:%S') Make OpenVPN Auto Login on Service Start${NC}\n"
    if [ -n "$PIA_LOGIN" ]; then
        echo $PIA_LOGIN | sed "s/:/\n/" | tee /etc/openvpn/login.txt
    else
        echo "piauser" | tee /etc/openvpn/login.txt
        echo "piapwd" | tee -a /etc/openvpn/login.txt
    fi
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
    sed -i 's/^export LOCALIP=".*/export LOCALIP="$LOCAL_IP"/' /etc/openvpn/iptables.sh
    sed -i 's/^export NETIF=".*/export NETIF="$NET_IF"/' /etc/openvpn/iptables.sh
    echo -e "\n${GREEN}$(date '+%Y-%m-%d %H:%M:%S') Done${NC}\n"

    echo -e "\n${YELLOW}$(date '+%Y-%m-%d %H:%M:%S') Routing Rules Script for the Marked Packets${NC}\n"
    cp src/routing.sh /etc/openvpn/
    chmod +x /etc/openvpn/routing.sh
    echo -e "\n${GREEN}$(date '+%Y-%m-%d %H:%M:%S') Done${NC}\n"

    echo -e "\n${YELLOW}$(date '+%Y-%m-%d %H:%M:%S') Configure Split Tunnel VPN Routing${NC}\n"
    echo "200     vpn" | tee -a /etc/iproute2/rt_tables
    echo -e "\n${GREEN}$(date '+%Y-%m-%d %H:%M:%S') Done${NC}\n"

    echo -e "\n${YELLOW}$(date '+%Y-%m-%d %H:%M:%S') Change Reverse Path Filtering${NC}\n"
    cp src/9999-vpn.conf /etc/sysctl.d/
    sed -i "s/eth0/$NET_IF/" /etc/sysctl.d/9999-vpn.conf
    sysctl --system

    # Keep Alive Script
    echo -e "\n${YELLOW}$(date '+%Y-%m-%d %H:%M:%S') Setup Keep Alive Script${NC}\n"
    cp src/vpn_keepalive.sh /etc/openvpn/
    chmod +x /etc/openvpn/vpn_keepalive.sh
    sed -i "s|^LOGFILE=.*|LOGFILE=$SCRIPT_DIR/vpn_keepalive.log|" /etc/openvpn/vpn_keepalive.sh

    echo "$(date '+%Y-%m-%d %H:%M:%S') openvpn_setup: completed" >> $LOG_FILE
    echo -e "\n${GREEN}$(date '+%Y-%m-%d %H:%M:%S') Done${NC}\n"
}

deluge_setup()
{
    if [ -z "$(grep 'openvpn_setup: completed' $LOG_FILE)" ]; then
        echo -e "\n${RED}Install OpenVPN first${NC}\n"
        return 0
    fi

    if [ -n "$(grep 'deluge_setup: completed' $LOG_FILE)" ]; then
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
    systemctl start deluged.service
    systemctl start deluge-web.service
    echo -e "\n${GREEN}$(date '+%Y-%m-%d %H:%M:%S') Done${NC}\n"

    echo -e "\n${YELLOW}$(date '+%Y-%m-%d %H:%M:%S') Configure Deluge Remote Access with nginx Reverse Proxy${NC}\n"
    apt-get update
    apt-get install nginx -y
    unlink /etc/nginx/sites-enabled/default
    cp src/reverse /etc/nginx/sites-available/
    sed -i "s/^server_name .*/server_name $LOCAL_IP\;/" /etc/nginx/sites-available/reverse
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
    if [ -n "$DELUGE_LOGIN" ]; then
        DELUGE_USER=$(echo "$DELUGE_LOGIN" | cut -d ":" -f 1)
        DELUGE_PW=$(echo "$DELUGE_LOGIN" | cut -d ":" -f 2)
        echo "$DELUGE_LOGIN:10" >> /home/vpn/.config/deluge/auth
        sed -i "s/^DELUGEUSER=.*/DELUGEUSER=$DELUGE_USER/" /etc/openvpn/portforward.sh
        sed -i "s/^DELUGEPASS=.*/DELUGEPASS=$DELUGE_PW/" /etc/openvpn/portforward.sh
    else
        echo "deluge:deluge:10" >> /home/vpn/.config/deluge/auth
    fi
    if [ -n "$PIA_LOGIN" ]; then
        PIA_USER=$(echo "$PIA_LOGIN" | cut -d ":" -f 1)
        PIA_PW=$(echo "$PIA_LOGIN" | cut -d ":" -f 2)
        sed -i "s/^USERNAME=.*/USERNAME=$PIA_USER/" /etc/openvpn/portforward.sh
        sed -i "s/^PASSWORD=.*/PASSWORD=$PIA_PW/" /etc/openvpn/portforward.sh
    fi
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
    echo ""
    options=("Install OpenVPN" "Install Deluge" "Install All" "Quit")
    PS3=$'\n\e[36mChoose an option (1-4): \e[0m'

    while true; do
        select opt in "${options[@]}"; do
            case $opt in
                "Install OpenVPN") openvpn_setup; break ;;
                "Install Deluge") deluge_setup; break;;
                "Install All") openvpn_setup; deluge_setup; break ;;
                "Quit") break 2 ;;
                *) echo "Oh No! That's not a valid option" >&2
            esac
            echo "Press Enter to display menu again" >&2
        done
    done
}


### LET'S RUN THIS!

if ! [ $(id -u) = 0 ]; then
   echo "The script needs to be run as root." >&2
   exit 1
fi

set -e
trap error ERR
setup_var

# grab optional arguments
while getopts ":hi:f:np:d:s:" opt; do
    case ${opt} in
        i)  LOCAL_IP=$OPTARG
            ;;
        f)  NET_IF=$OPTARG
            ;;
        n)  NON_INTERACTIVE=true
            ;;
        p)  PIA_LOGIN=$OPTARG
            ;;
        d)  DELUGE_LOGIN=$OPTARG
            ;;
        s)  PIA_SERVER=$OPTARG
            if [ -z "$(grep "^$PIA_SERVER\$" pia-servers.txt)" ]; then
                echo "Invalid PIA server: $OPTARG" 1>&2
                exit 1
            fi
            ;;
        h)
            usage
            exit 1
            ;;
        \? )
            echo "Invalid option: $OPTARG" 1>&2
            usage
            exit 1
            ;;
        : )
            echo "Invalid option: $OPTARG requires an argument" 1>&2
            usage
            exit 1
            ;;
    esac
done
shift $((OPTIND -1))

# print variables
echo -e "${LIGHT_PURPLE}"
echo "    ____       __               _    ______  _   __"
echo "   / __ \___  / /_  ______  ___| |  / / __ \/ | / /"
echo "  / / / / _ \/ / / / / __ \/ _ \ | / / /_/ /  |/ / "
echo " / /_/ /  __/ / /_/ / /_/ /  __/ |/ / ____/ /|  /  "
echo "/_____/\___/_/\__,_/\__, /\___/|___/_/   /_/ |_/   "
echo "                   /____/                          "
echo -e "${NC}"
echo -e "${BOLD}${BLUE}Script Directory:      ${NC}${LIGHT_BLUE}$SCRIPT_DIR"
echo -e "${BOLD}${BLUE}Current User:          ${NC}${LIGHT_BLUE}$REAL_USER"
echo -e "${BOLD}${BLUE}Local IP:              ${NC}${LIGHT_BLUE}$LOCAL_IP"
echo -e "${BOLD}${BLUE}Network Interface:     ${NC}${LIGHT_BLUE}$NET_IF"
echo -e "${NC}"

cd $SCRIPT_DIR
touch $LOG_FILE

if [ -n "$NON_INTERACTIVE" ]; then
    openvpn_setup
    deluge_setup
else
    menu
    echo 'Bye!'
fi
