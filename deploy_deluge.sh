#!/bin/bash
###
# Based on https://www.htpcguides.com/configure-deluge-for-vpn-split-tunneling-ubuntu-16-04/
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
    echo -e "\n############### $1 ###############\n"
}

setup_env()
{
    export CURRENTDIR=$(pwd)
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
    Network Interface  $NET_IF
    Local IP           $LOCAL_IP
    #################################################################
    \n"
    prompt
}

deluge_setup()
{
    beautify "Install Deluge and Web UI on Ubuntu 16.04 LTS"
    apt update
    apt install software-properties-common -y
    add-apt-repository ppa:deluge-team/ppa
    apt update
    apt install deluged deluge-web -y
    prompt

    beautify "Configure Deluge Logging"
    mkdir -p /var/log/deluge
    chown -R vpn:vpn /var/log/deluge
    chmod -R 770 /var/log/deluge
    cp src/deluge /etc/logrotate.d/

    beautify "Create the Systemd Unit for Deluge Daemon"
    cp src/deluged.service /etc/systemd/system/
    systemctl enable deluged.service
    systemctl start deluged.service
    prompt

    beautify "Create the Systemd Unit for Deluge Web UI"
    cp src/deluge-web.service /etc/systemd/system/
    systemctl enable deluge-web.service
    systemctl start deluge-web.service
    prompt

    beautify "Make Deluge Web UI Auto Connect to Deluge Daemon"
    systemctl stop deluged.service
    systemctl stop deluge-web.service
    sed -i 's/"default_daemon": ""/"default_daemon": "127.0.0.1:58846"/' /home/vpn/.config/deluge/web.conf
    echo -e "***\nContents of /home/vpn/.config/deluge/web.conf***\n"
    cat /home/vpn/.config/deluge/web.conf
    prompt
    systemctl start deluged.service
    systemctl start deluge-web.service

    beautify "Configure Deluge Remote Access with nginx Reverse Proxy"
    apt update
    apt install nginx -y
    unlink /etc/nginx/sites-enabled/default
    cp src/reverse /etc/nginx/sites-available/
    sed -i "s/192.168.1.100/$LOCAL_IP/" /etc/nginx/sites-available/reverse
    echo -e "***\nContents of /etc/nginx/sites-available/reverse***\n"
    cat /etc/nginx/sites-available/reverse
    prompt

    ln -s /etc/nginx/sites-available/reverse /etc/nginx/sites-enabled/reverse
    echo -e "***\nTest the nginx configuration is valid\n"
    nginx -t
    prompt
    systemctl restart nginx.service
    systemctl start deluged.service

    echo -e "\nDone\n\nRefer to: Recommended Deluge Settings for Maximum Security located here for GUI settings in Deluge
    https://www.htpcguides.com/configure-deluge-for-vpn-split-tunneling-ubuntu-16-04/
    \n"
    prompt
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
deluge_setup