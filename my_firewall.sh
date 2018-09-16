#!/bin/bash

sudo ufw reset

# block ALL incoming AND outgoing traffic from the server
sudo ufw default deny incoming
sudo ufw default deny outgoing

# allow ALL outgoing traffic over tun0 interface (that is, any trafic will be allowed, but only over VPN connection):
sudo ufw allow out on tun0 from any to any
# allow incoming connection too on VPN, needed for seeding
sudo ufw allow in on tun0 from any to any

# allow eth0 access to a specific IP address (eg. PIA Netherlands), otherwise you will not be able to establish the VPN connection
sudo ufw allow out from any to 212.92.122.136
# OR use below for range instead
# sudo ufw allow out from any to 123.123.123.0/24

# make sure SSH access is allowed, otherwise you will not be able to remote access your server. In this example we will allow SSH (port 22) access only from the local network
#sudo ufw allow from 192.168.0.0/24 to any port 22
#sudo ufw allow out from 192.168.0.0/24 to any port 22

# other internal access
sudo ufw allow from 192.168.0.0/24 to any 
sudo ufw allow out from 192.168.0.0/24 to any 
sudo ufw allow from 10.8.0.0/24 to any 
sudo ufw allow out from 10.8.0.0/24 to any 

# enable UFW
sudo ufw enable

# Check the UFW rules
sudo ufw status verbose
