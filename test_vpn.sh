#!/bin/bash

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

setup_var()
{
    # variables
    if [ $SUDO_USER ]; then
        REAL_USER=$SUDO_USER
    else
        REAL_USER=$(whoami)
    fi

    VPN_USER="vpn"
    EXT_IP=$(sudo -u $REAL_USER -i -- wget http://ipinfo.io/ip -qO -)
    VPN_IP=$(sudo -u $VPN_USER -i -- wget http://ipinfo.io/ip -qO -)
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
setup_var

echo -e "
#################################################################
External IP Address for user $REAL_USER:    $EXT_IP
External IP Address for user $VPN_USER:     $VPN_IP
#################################################################
\n"

beautify "Querying ipinfo.io for user: $REAL_USER"
sudo -u $REAL_USER -i -- curl ipinfo.io
beautify "Querying ipinfo.io for user: $VPN_USER"
sudo -u $VPN_USER -i -- curl ipinfo.io
beautify "Displaying /etc/resolv.conf for user: $REAL_USER"
sudo -u $VPN_USER -i -- cat /etc/resolv.conf
