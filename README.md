# xenial-delugevpn

Configures VPN split tunnel setup for Ubuntu 16.04 and installs and configures deluge.

This script was built based on the following guides:
* https://www.htpcguides.com/force-torrent-traffic-vpn-split-tunnel-debian-8-ubuntu-16-04/
* https://www.htpcguides.com/configure-deluge-for-vpn-split-tunneling-ubuntu-16-04/
* https://www.htpcguides.com/configure-auto-port-forward-pia-vpn-for-deluge/

## Requirements

**Operating System:** Ubuntu 16.04 LTS 64-bit

Note: This has been developed on VM running 64-bit Ubuntu 16.04 installed with [minimal iso image](https://help.ubuntu.com/community/Installation/MinimalCD).

## Install steps

1. Download or clone this repository and run `setup.sh` on a machine with Ubuntu 16.04.
   
   Example: `./setup.sh -i 192.168.1.100 -f eth0 -n -p piauser:abc123 -d deluge:deluge`

    ```
    Usage: ./setup.sh [OPTION]

        -i  LOCAL_IP     Manually specify LOCAL_IP
        -f  NET_IF       Manually specify network interface NET_IF
        -n               Non-interactive Mode
        -p  USER:PWD     PIA user and password in format USER:PWD
                            If option not used, defaults to piauser:abc123 to be 
                            manually updated later
        -d  USER:PWD     Override USER:PWD to use for deluge daemon in the
                            auto portforward script. Default is deluge:deluge

    ```

2. Reboot system

3. Test vpn working:
    ```bash
    sudo ./test_vpn.sh
    ```

4. Output should show different ip address for user vpn to the main user

5. Test port forwarding script
    ```bash
    sudo /etc/openvpn/portforward.sh
    ```

6. Output should be vpn ip and port number

7. Add below to crontab `sudo crontab -e` to schedule port forwarding and keep alive scripts
    ```bash
    @reboot sleep 60 && /etc/openvpn/portforward.sh | while IFS= read -r line; do echo "$(date) $line"; done >> /var/log/pia_portforward.log 2>&1 #PIA Port Forward
    0 */2 * * * /etc/openvpn/portforward.sh | while IFS= read -r line; do echo "$(date) $line"; done >> /var/log/pia_portforward.log 2>&1 #PIA Port Forward
    15,45 * * * * /etc/openvpn/vpn_keepalive.sh #PIA Keep Alive script
    ```

## Setup any windows shares

Follow this if you need to create a windows share to use as download folder for deluge.

```bash
sudo mkdir /media/Downloads
sudo chown -R nobody:nogroup /media/Downloads
sudo chmod -R 0777 /media/Downloads
echo -e "\n//192.168.1.2/Downloads /media/Downloads cifs username=****,password=****,uid=nobody,iocharset=utf8,vers=3.0,noperm 0 0" | sudo tee -a /etc/fstab
sudo mount /media/Downloads
```

## Configure Deluge settings in Web GUI

Refer [here](doc/deluge_settings.md)
