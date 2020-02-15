#!/bin/bash

# check root
if ! [ $(id -u) = 0 ]; then
   echo "The script need to be run as root." >&2
   exit 1
fi

# get user
if [ $SUDO_USER ]; then
    REAL_USER=$SUDO_USER
else
    REAL_USER=$(whoami)
fi

# set variables
VPN_USER="vpn"
EXT_IP=$(sudo -u $REAL_USER -i -- wget http://ipinfo.io/ip -qO -)
VPN_IP=$(sudo -u $VPN_USER -i -- wget http://ipinfo.io/ip -qO -)

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


### Lets do this!

echo -e "${BOLD}${BLUE}IP for user $REAL_USER:      ${NC}${LIGHT_BLUE}$EXT_IP"
echo -e "${BOLD}${BLUE}IP for user $VPN_USER:       ${NC}${LIGHT_BLUE}$VPN_IP"
echo -e "${NC}"

echo -e "${GREEN}Querying ipinfo.io for user: $REAL_USER${NC}"
sudo -u $REAL_USER -i -- curl ipinfo.io

echo -e "${GREEN}Querying ipinfo.io for user: $VPN_USER${NC}"
sudo -u $VPN_USER -i -- curl ipinfo.io

echo -e "${GREEN}Displaying /etc/resolv.conf for user: $REAL_USER${NC}"
sudo -u $VPN_USER -i -- cat /etc/resolv.conf
