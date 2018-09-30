#!/bin/sh
echo "===== Current User ====="
#wget http://ipinfo.io/ip -qO -
curl ipinfo.io
echo "\n===== vpn user ====="
#sudo -u vpn -i -- wget http://ipinfo.io/ip -qO -
sudo -u vpn -i -- curl ipinfo.io

