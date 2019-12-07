## Install Steps

### deploy_vpn.sh
1. Execute deploy_vpn.sh 
    ```
    sudo ./deploy_vpn.sh
    ````
2. Reboot system
3. Test vpn working: 
    ```
    sudo ./test_vpn.sh
    ```
4. Output should show different ip address for user vpn to the main user

### deploy_delug.sh
1. Execute deploy_deluge.sh 
    ```
    sudo ./deploy_deluge.sh
    ```
2. Reboot system
3. Test port forwarding script
    ```
    sudo /etc/openvpn/portforward.sh
    ```
4. Output should be vpn ip and port number
5. Add below to crontab `sudo crontab -e` to schedule port forwarding script
    ```
    @reboot sleep 60 && /etc/openvpn/portforward.sh | while IFS= read -r line; do echo "$(date) $line"; done >> /var/log/pia_portforward.log 2>&1 #PIA Port Forward
    0 */2 * * * /etc/openvpn/portforward.sh | while IFS= read -r line; do echo "$(date) $line"; done >> /var/log/pia_portforward.log 2>&1 #PIA Port Forward
    ```

## Setup any windows shares
1. Run below steps
    ```
    sudo mkdir /media/Downloads
    sudo chown -R nobody:nogroup /media/Downloads
    sudo chmod -R 0777 /media/Downloads
    echo -e "\n//192.168.1.2/Downloads /media/Downloads cifs username=****,password=****,uid=nobody,iocharset=utf8,vers=3.0,noperm 0 0" | sudo tee -a /etc/fstab
    mount /media/Downloads
    ```

## Configure Deluge settings in Web GUI

1. Refer to **Recommended Deluge Settings for Maximum Security** [here](https://www.htpcguides.com/configure-deluge-for-vpn-split-tunneling-ubuntu-16-04/)
2. [Make Deluge Automatically Stop Seeding When Download Complete](https://www.htpcguides.com/make-deluge-automatically-stop-seeding-download-complete/)
3. [Additional settings](https://github.com/so3n/VM_Torrent/tree/master/doc/img)

## Setup Keep Alive script as cron job

1. Add below to crontab `sudo crontab -e` to schedule keep alive script on the 15th and 45th minute every hour:
    ```
    15,45 * * * * /PATH/TO/VM_Torrent/src/vpn_keepalive.sh
    ```


