#!/bin/sh

# Ping Google DNS via vpn user to check if vpn is connected to internet
if (sudo -u vpn -i -- ping -c 5 8.8.8.8 | grep -q '0 received') then
    echo "$(date +"%F %T") Ping to 8.8.8.8 failed" >> /home/killscr33n/vpnfix.log

    # restart openvpn service
    sudo systemctl restart openvpn@openvpn.service
    echo "$(date +"%F %T") VPN Restarted" >> /home/killscr33n/vpnfix.log

    # wait for 20 seconds before getting IP for log
    sleep 20
    IP1="$(wget http://ipinfo.io/ip -qO -)"
    IP2="$(sudo -u vpn -i -- wget http://ipinfo.io/ip -qO -)"
    echo "$(date +"%F %T") Ping to 8.8.8.8 successful (IP: $IP1 VPN IP: $IP2)" >> /home/killscr33n/vpnfix.log

else
    IP1="$(wget http://ipinfo.io/ip -qO -)"
    IP2="$(sudo -u vpn -i -- wget http://ipinfo.io/ip -qO -)"
    echo "$(date +"%F %T") Ping to 8.8.8.8 successful (IP: $IP1 VPN IP: $IP2)" >> /home/killscr33n/vpnfix.log

fi

