#!/bin/bash
#updates
apt update && apt upgrade -y

#installs
apt install git python3 python3-pip python-dev apache2 apache2-dev libapache2-mod-wsgi-py3 hostapd dnsmasq mariadb-server -y

#git
git clone https://github.com/Retsel023/FYS.git
mv -r /FYS /home/FYS 
cd /home/FYS

#fys.conf and apache config
yes | cp -rf fys.conf /etc/apache2/sites-available/fys.conf
chmod 644 /etc/apache2/sites-available/fys.conf
a2dissite 000-default
a2ensite fys
mkdir /var/www/fys
cd /var/www/fys
apt install python3-virtualenv
virtualenv venv
source venv/bin/activate
deactivate
pip install Flask
cd /home/FYS
yes | cp -rf FYS_website/website/* /var/www/fys
systemctl restart apache2

#hostapd.conf
yes | cp -rf hostapd.conf /etc/hostapd/hostapd.conf
systemctl unmask hostapd
systemctl enable hostapd
systemctl start hostapd

#dnsmasq.conf
yes | cp -rf dnsmasq.conf /etc/dnsmasq.conf
systemctl restart dnsmasq
yes | cp -rf dnsmasq.service /lib/systemd/system/dnsmasq.service

#netplan
yes | cp -rf 50-cloud-init.yaml /etc/netplan/50-cloud-init.yaml
netplan apply

#ipv4 forwarding
yes | cp -rf sysctl.conf /etc/sysctl.conf
sudo sh -c "echo 1 > /proc/sys/net/ipv4/ip_forward"

#iptables
iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
iptables -A FORWARD -i eth0 -o wlan0 -m state --state RELATED,ESTABLISHED -j ACCEPT
iptables -A FORWARD -i wlan0 -o eth0 -j ACCEPT

sh -c "iptables-save > /etc/iptables.ipv4.nat"

#rc.local
touch /etc/rc.local
touch /etc/systemd/system/rc-local.service
printf '%s\n' '[Unit]' 'Description=/etc/rc.local Compatibillity' 'ConditionPathExists=/etc/rc.local' '' '[Service]' 'Type=forking' 'ExecStart=/etc/rc.local start' 'TimeoutSec=0' 'StandardOutput=tty' 'RemainAfterExit=yes' 'SysVStartPriority=99' '' '[Install]' 'WantedBy=multi-user.target' | sudo tee /etc/systemd/system/rc-local.service
printf '%s\n' '#!/bin/bash' 'iptables-restore < /etc/iptables.ipv4.nat' 'netplan apply' 'sudo sh -c "echo 1 > /proc/sys/net/ipv4/ip_forward"' 'exit 0' | sudo tee /etc/rc.local
chmod +x /etc/rc.local
systemctl unmask rc-local
systemctl enable rc-local
systemctl start rc-local

#Database
mariadb -u root -p"nopass" -e "CREATE DATABASE FYS;"
mariadb -u root -p"nopass" -e "CREATE USER 'Flightmanager'@localhost IDENTIFIED BY 'SecretKey##11WXX';"
mariadb -u root -p"nopass" -e "GRANT ALL PRIVILEGES ON *.* TO 'Flightmanager'@localhost IDENTIFIED BY 'SecretKey##11WXX';"
mariadb -u root -p"nopass" -e "GRANT ALL PRIVILEGES ON FYS.* TO 'Flightmanager'@localhost;"
mariadb -u root -p"nopass" -e "FLUSH PRIVILEGES;"
mariadb -u root -p"nopass" -e "CREATE TABLE FYS.Persoon(Naam VARCHAR(45), Ticketnummer VARCHAR(12), Vluchtnummer VARCHAR(10));"
