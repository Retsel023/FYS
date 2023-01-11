#!/bin/bash
#updates
echo "Preparing Updates..."
apt update && apt upgrade -y
apt autoremove -y
echo "Done Updating!"

#installs
echo "Preparing Installation items..."
apt install git python3 python3-pip apache2 apache2-dev libapache2-mod-wsgi-py3 hostapd dnsmasq mariadb-server mariadb-client libmariadb-dev -y
pip3 install Flask mod-wsgi mariadb 
#pip3 install mod-wsgi-httpd
#curl -LsS https://r.mariadb.com/downloads/mariadb_repo_setup | sudo bash
apt update && apt upgrade -y
echo "Installation items complete!"
#git
git clone https://github.com/Retsel023/FYS.git
mv -r /FYS /home/pi/FYS 
cd /home/pi/FYS

#fys.conf and apache config
echo "Setting up the Apache configuration..."
yes | cp -rf fys.conf /etc/apache2/sites-available/fys.conf
chmod 644 /etc/apache2/sites-available/fys.conf
a2dissite 000-default
a2ensite fys
a2enmod ssl
mkdir /var/www/fys
cd /var/www/fys
apt install python3-virtualenv
virtualenv venv
source venv/bin/activate
#chmod 777 venv/lib/python3.10/site-packages/
#chmod 777 venv/bin
#pip install flask
#pip install mariadb
deactivate
cd /home/pi/FYS
yes | cp -rf FYS_website/website/* /var/www/fys

#https certificate
echo "creating the certificate..."
openssl req -x509 -nodes -days 36500 -newkey rsa:2048 -keyout /var/www/server.key -out /var/www/server.crt -subj "/C=NL/ST=North-Holland/L=Amsterdam/CN=127.0.1.1"
systemctl restart apache2

#Destroy systemd-resolved
echo "Deactivating systemd-resolved"
systemctl disable systemd-resolved
systemctl stop systemd-resolved
systemctl mask systemd-resolved


#hostapd.conf
echo "Hostapd configuration preparation..."
yes | cp -rf hostapd.conf /etc/hostapd/hostapd.conf
systemctl unmask hostapd
systemctl enable hostapd
systemctl start hostapd

#dnsmasq.conf
echo "Dnsmasq configuration preparation..."
yes | cp -rf dnsmasq.conf /etc/dnsmasq.conf
systemctl restart dnsmasq
yes | cp -rf dnsmasq.service /lib/systemd/system/dnsmasq.service

echo "Netlpan configuration preparation..."
#netplan
yes | cp -rf 50-cloud-init.yaml /etc/netplan/50-cloud-init.yaml
#netplan apply

#ipv4 forwarding
yes | cp -rf sysctl.conf /etc/sysctl.conf
sudo sh -c "echo 1 > /proc/sys/net/ipv4/ip_forward"

#iptables
echo "Setting up the iptable rules..."
iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
iptables -A FORWARD -i eth0 -o wlan0 -m state --state RELATED,ESTABLISHED -j ACCEPT
iptables -A FORWARD -i wlan0 -o eth0 -j ACCEPT

sh -c "iptables-save > /etc/iptables.ipv4.nat"

#rc.local
echo "Creating the rc.local config..."
touch /etc/rc.local
touch /etc/systemd/system/rc-local.service
printf '%s\n' '[Unit]' 'Description=/etc/rc.local Compatibillity' 'ConditionPathExists=/etc/rc.local' '' '[Service]' 'Type=forking' 'ExecStart=/etc/rc.local start' 'TimeoutSec=0' 'StandardOutput=tty' 'RemainAfterExit=yes' 'SysVStartPriority=99' '' '[Install]' 'WantedBy=multi-user.target' | sudo tee /etc/systemd/system/rc-local.service
printf '%s\n' '#!/bin/bash' 'iptables-restore < /etc/iptables.ipv4.nat' 'netplan apply' 'sudo sh -c "echo 1 > /proc/sys/net/ipv4/ip_forward"' 'exit 0' | sudo tee /etc/rc.local
chmod +x /etc/rc.local
systemctl unmask rc-local
systemctl enable rc-local
systemctl start rc-local

#Database
echo "Setting up the database..."
mariadb -u root -p"nopass" -e "CREATE DATABASE FYS;"
mariadb -u root -p"nopass" -e "CREATE USER 'Flightmanager'@'%' IDENTIFIED BY 'SecretKey##11WXX';"
mariadb -u root -p"nopass" -e "GRANT SELECT ON FYS.* TO 'Flightmanager'@'%';"
mariadb -u root -p"nopass" -e "FLUSH PRIVILEGES;"
mariadb -u root -p"nopass" -e "CREATE TABLE FYS.Persoon(Naam VARCHAR(45), Ticketnummer VARCHAR(12), Vluchtnummer VARCHAR(10));"

echo "Done!"
echo "Rebooting"
netplan apply && reboot
