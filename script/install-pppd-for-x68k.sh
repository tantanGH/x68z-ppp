#!/bin/bash

RUNAS=`whoami`

if [ "$RUNAS" != "root" ]; then
  echo "Please run this script as root."
  exit 1
fi

# disable bluetooth
grep "dtoverlay=disable-bt" /boot/config.txt > /dev/null
if [ $? -ne 0 ]; then
  echo "dtoverlay=disable-bt" >> /boot/config.txt
fi

# enable IP forwarding
grep '^net.ipv4.ip_forward=1' /etc/sysctl.conf > /dev/null
if [ $? -ne 0 ]; then
  echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf
fi

# disable IPv6
grep '^net.ipv6.conf.all.disable_ipv6=1' /etc/sysctl.conf > /dev/null
if [ $? -ne 0 ]; then
  echo "net.ipv6.conf.all.disable_ipv6=1" >> /etc/sysctl.conf
fi

# update package list
apt-get update

# update packet routing
apt-get install -y iptables-persistent
iptables --table nat --append POSTROUTING --out-interface wlan0 -j MASQUERADE
iptables --append FORWARD --in-interface ppp0 -j ACCEPT
iptables -t nat -A PREROUTING -p tcp --dport 80 -j REDIRECT --to-port 6803
iptables -t nat -L -v -n
netfilter-persistent save

# install ppp
apt-get install -y ppp

# create pppd start script
mkdir /home/pi/bin
echo "sudo stty -F /dev/serial0 19200" > /home/pi/bin/pppd-z.sh
echo "/usr/sbin/pppd /dev/serial0 19200 local 192.168.31.101:192.168.31.121 noipv6 proxyarp local noauth debug nodetach dump nocrtscts passive persist maxfail 0 holdoff 1 noauth" >> /home/pi/bin/pppd-z.sh
chown pi.pi -R /home/pi/bin/
chmod +x /home/pi/bin/pppd-z.sh

# install vsftpd
apt-get install -y vsftpd ftp
mv /etc/vsftpd.conf /etc/vsftpd.conf.orig
cat /etc/vsftpd.conf.orig | grep -v '^listen=' | grep -v '^listen_ipv6=' | grep -v '^write_enable=' > /etc/vsftpd.conf
echo "listen=YES" >> /etc/vsftpd.conf
echo "listen_ipv6=NO" >> /etc/vsftpd.conf
echo "write_enable=YES" >> /etc/vsftpd.conf
service vsftpd start

# install webxpressd
apt-get install -y git pip libopenjp2-7 libxslt-dev libcairo2-dev
sudo -u pi pip install git+https://github.com/tantanGH/webxpressd.git

# auto start settings
mv /etc/rc.local /etc/rc.local.orig
echo '#!/bin/sh -e' > /etc/rc.local
echo '/home/pi/bin/pppd-z.sh > /home/pi/log-pppd-z &' >> /etc/rc.local
echo 'sudo -u pi /home/pi/.local/bin/webxpressd --image_quality 15 > /home/pi/log-webxpd &' >> /etc/rc.local
echo 'exit 0' >> /etc/rc.local
chmod +x /etc/rc.local

