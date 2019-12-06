### Install Steps

Execute deploy_vpn.sh `sudo ./deploy_vpn.sh`

Reboot system

Test vpn working: `sudo ./test_vpn`

Output should be different ip address for user vpn

Execute deploy_deluge.sh `sudo ./deploy_deluge.sh`

Reboot system

Test port forwarding script `sudo \etc\openvpn\portforward.sh`

Output should be vpn ip and port number

Edit crontab `sudo crontab -e` to schedule port forwarding script

Add below to crontab:
```
@reboot sleep 60 && /etc/openvpn/portforward.sh | while IFS= read -r line; do echo "$(date) $line"; done >> /var/log/pia_portforward.log 2>&1 #PIA Port Forward
0 */2 * * * /etc/openvpn/portforward.sh | while IFS= read -r line; do echo "$(date) $line"; done >> /var/log/pia_portforward.log 2>&1 #PIA Port Forward
```

### Setup any windows shares

```
mkdir /media/Downloads
sudo chown -R nobody:nogroup /media/Downloads
sudo chmod -R 0777 /media/Downloads
echo -e "\n//192.168.1.2/Downloads /media/Downloads cifs username=****,password=****,uid=nobody,iocharset=utf8,vers=3.0,noperm 0 0" | sudo tee -a /etc/fstab
mount /media/Downloads
```

### Configure Deluge settings in Web GUI

Refer to *Recommended Deluge Settings for Maximum Security* [here](https://www.htpcguides.com/configure-deluge-for-vpn-split-tunneling-ubuntu-16-04/)

### Setup Keep Alive script as cron job

Add below to crontab:
```
15,45 * * * * /PATH/TO/VM_Torrent/src/vpn_keepalive.sh
```


