#!/bin/bash
# Refernces:
#  https://www.htpcguides.com/configure-deluge-for-vpn-split-tunneling-ubuntu-16-04/
#  https://www.htpcguides.com/configure-auto-port-forward-pia-vpn-for-deluge/


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
    CURRENTDIR=$(pwd)
    NET_IF=$(ip -o link show | sed -rn '/^[0-9]+: en/{s/.: ([^:]*):.*/\1/p}')
    LOCAL_IP=$(/sbin/ip -o -4 addr list $NET_IF | awk '{print $4}' | cut -d/ -f1)
    DELUGE_USER="deluge"
    DELUGE_PW="deluge"

    declare -a pia_login
    readarray pia_login < /etc/openvpn/login.txt
    PIA_USER="${pia_login[0]}"
    PIA_PW="${pia_login[1]}"

    if [ $SUDO_USER ]; then
        REAL_USER=$SUDO_USER
    else
        REAL_USER=$(whoami)
    fi
}

deluge_setup()
{
    beautify "Install Deluge and Web UI on Ubuntu 16.04 LTS"
    apt update
    apt install software-properties-common -y
    add-apt-repository ppa:deluge-team/ppa
    apt update
    apt install deluged deluge-web -y
    echo -e "\nDone"
    
    beautify "Configure Deluge Logging"
    mkdir -p /var/log/deluge
    chown -R vpn:vpn /var/log/deluge
    chmod -R 770 /var/log/deluge
    cp src/deluge /etc/logrotate.d/
    echo -e "\nDone"

    beautify "Create the Systemd Unit for Deluge Daemon"
    cp src/deluged.service /etc/systemd/system/
    systemctl enable deluged.service
    systemctl start deluged.service
    echo -e "\nDone"
    
    beautify "Create the Systemd Unit for Deluge Web UI"
    cp src/deluge-web.service /etc/systemd/system/
    systemctl enable deluge-web.service
    systemctl start deluge-web.service
    echo -e "\nDone"
    
    beautify "Make Deluge Web UI Auto Connect to Deluge Daemon"
    systemctl stop deluged.service
    systemctl stop deluge-web.service
    sed -i 's/"default_daemon": ""/"default_daemon": "127.0.0.1:58846"/' /home/vpn/.config/deluge/web.conf
    beautify "Contents of /home/vpn/.config/deluge/web.conf" 2
    cat /home/vpn/.config/deluge/web.conf
    systemctl start deluged.service
    systemctl start deluge-web.service
    echo -e "\nDone"

    beautify "Configure Deluge Remote Access with nginx Reverse Proxy"
    apt update
    apt install nginx -y
    unlink /etc/nginx/sites-enabled/default
    cp src/reverse /etc/nginx/sites-available/
    sed -i "s/192.168.1.100/$LOCAL_IP/" /etc/nginx/sites-available/reverse
    beautify "Contents of /etc/nginx/sites-available/reverse" 2
    cat /etc/nginx/sites-available/reverse
    ln -s /etc/nginx/sites-available/reverse /etc/nginx/sites-enabled/reverse
    echo -e "\nDone"
    
    beautify "Test the nginx configuration is valid" 2
    nginx -t
    systemctl restart nginx.service
    systemctl start deluged.service
    echo -e "\nDone"
}

auto_portforward_setup()
{   
    beautify "Configure Auto Port Forward PIA VPN for Deluge"
    cp src/portforward.sh /etc/openvpn/
    chmod +x /etc/openvpn/portforward.sh
    sudo echo "$DELUGE_USER:$DELUGE_PW:10" >> /home/vpn/.config/deluge/auth
    sed -i "s\"piauser\"/\"$PIA_USER\"/" /etc/openvpn/portforward.sh
    sed -i "s\"piapw\"/\"$PIA_PW\"/" /etc/openvpn/portforward.sh
    sed -i "s\"delugeuser\"/\"$DELUGE_USER\"/" /etc/openvpn/portforward.sh
    sed -i "s\"delugepw\"/\"$DELUGE_PW\"/" /etc/openvpn/portforward.sh
    beautify "Showing first few lines of /etc/openvpn/portforward.sh" 2
    head -n 22 /etc/openvpn/portforward.sh
    prompt

    beautify "Install Deluge Console"
    apt install deluge-console
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
Current Directory: $CURRENTDIR
Current User:      $REAL_USER
Network Interface: $NET_IF
Local IP:          $LOCAL_IP
PIA User:          $PIA_USER
PIA Password:      $PIA_PW
#################################################################
\n"
prompt

deluge_setup
auto_portforward_setup
echo -e "\nCOMPLETE"
beautify "Below steps to be complted manually"
echo -e "  *Reboot system"
echo -e "  * Update Deluge setting. 
    Refer to: Recommended Deluge Settings for Maximum Security located here for GUI settings in Deluge
    https://www.htpcguides.com/configure-deluge-for-vpn-split-tunneling-ubuntu-16-04/"
echo -e "  * Test Port Forwarding Script
    use command sudo bash /etc/openvpn/portforward.sh"
echo -e "\n"
