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
mkdir /homne/FYS
mv -r /FYS/* /home/FYS 
cd /home/FYS

#ssh
yes | cp -rf sshd_config /etc/ssh/sshd_config

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
cd /home/FYS
yes | cp -rf FYS_website/website/* /var/www/fys
rm -r /var/www/html

#https certificate
echo "creating the certificate..."
openssl req -x509 -nodes -days 36500 -newkey rsa:2048 -keyout /var/www/server.key -out /var/www/server.crt -subj "/C=NL/ST=North-Holland/L=Amsterdam/CN=127.0.1.1"

#unbinding systemd-resolved from port 53
printf '%s\n' '[Resolve]' 'DNSStubListener=no' | sudo tee /etc/systemd/resolved.conf

#Destroy systemd-resolved
#echo "Deactivating systemd-resolved"
#systemctl stop systemd-resolved
#systemctl mask systemd-resolved


#hostapd.conf
echo "Hostapd configuration preparation..."
yes | cp -rf hostapd.conf /etc/hostapd/hostapd.conf
systemctl unmask hostapd
systemctl enable hostapd
systemctl start hostapd

#dnsmasq.conf
echo "Dnsmasq configuration preparation..."
yes | cp -rf dnsmasq.conf /etc/dnsmasq.conf
yes | cp -rf dnsmasq.service /lib/systemd/system/dnsmasq.service

echo "Netlpan configuration preparation..."
#netplan
yes | cp -rf 50-cloud-init.yaml /etc/netplan/50-cloud-init.yaml
#netplan apply

#ipv4 forwarding
yes | cp -rf sysctl.conf /etc/sysctl.conf
sudo sh -c "echo 1 > /proc/sys/net/ipv4/ip_forward"

################
### iptables ###
################
echo "Setting up the iptable rules..."
# Redirect traffic to our webpage on port 80 so HTTP
iptables -t nat -A PREROUTING -i wlan0 -p tcp --dport 80 -j DNAT --to-destination 192.168.4.1:80
# Redirect traffic to our webpage on port 443 so HTTPS
iptables -t nat -A PREROUTING -i wlan0 -p tcp --dport 443 -j DNAT --to-destination 192.168.4.1:443
# Leaves the traffic intact when it leaves the system
iptables -t nat -A POSTROUTING -j MASQUERADE
#Rules without the -t will be placed in the FILTER table
# Drops all forward requests
iptables --policy FORWARD DROP
# Make an exception for the eth0 port “managing device”
iptables -A FORWARD -p tcp -i eth0 -j ACCEPT
# Make exception for the raspberry IP
iptables -A FORWARD -p tcp -s 192.168.4.1 -j ACCEPT
# Allows all the protocols mentioned below. The users can only use these port numbers on the internet
iptables -A FORWARD -p tcp -s 192.168.4.0/24 --match multiport --dports 80,443,25,587,2525,465,143,993,110,995,68,53,21,20,113 -j ACCEPT
# Grants acces to the raspberry to use all INPUT ports
iptables -A INPUT -s 192.168.4.1 -j ACCEPT
# Block all request to the SSH and SQL ports from the subnet
iptables -A INPUT -s 192.168.4.0/24 -p tcp --match multiport --dports 8612,3306 -j DROP


sh -c "iptables-save > /etc/iptables.ipv4.nat"

#rc.local
echo "Creating the rc.local config..."
touch /etc/rc.local
touch /etc/systemd/system/rc-local.service
printf '%s\n' '[Unit]' 'Description=/etc/rc.local Compatibillity' 'ConditionPathExists=/etc/rc.local' '' '[Service]' 'Type=forking' 'ExecStart=/etc/rc.local start' 'TimeoutSec=0' 'StandardOutput=tty' 'RemainAfterExit=yes' 'SysVStartPriority=99' '' '[Install]' 'WantedBy=multi-user.target' | sudo tee /etc/systemd/system/rc-local.service
printf '%s\n' '#!/bin/bash' 'iptables-restore < /etc/iptables.ipv4.nat' 'sudo sh -c "echo 1 > /proc/sys/net/ipv4/ip_forward"' 'exit 0' | sudo tee /etc/rc.local
chmod +x /etc/rc.local
systemctl unmask rc-local
systemctl enable rc-local
systemctl start rc-local

#ip-tables executeble for www-data user
#create dirs
mkdir /home/www-data
mkdir /home/www-data/bin
#copy iptables executeble
cp /usr/sbin/iptables /home/www-data/bin/iptables
#reset permissions on the copy
chmod 000 /home/www-data/bin/iptables
id www-data
#change ownership and permissions
chown -R www-data.www-data /home/www-data/bin/iptables
chmod -R 500 /home/www-data/bin/iptables
#set file cpabilities
setcap CAP_NET_RAW,CAP_NET_ADMIN+ep /home/www-data/bin/iptables

#Database
echo "Setting up the database..."
mariadb -u root -p"nopass" -e "CREATE DATABASE FYS;"
mariadb -u root -p"nopass" -e "CREATE USER 'Flightmanager'@'%' IDENTIFIED BY 'SecretKey##11WXX';"
mariadb -u root -p"nopass" -e "GRANT SELECT ON FYS.* TO 'Flightmanager'@'%';"
mariadb -u root -p"nopass" -e "FLUSH PRIVILEGES;"
mariadb -u root -p"nopass" -e "CREATE TABLE FYS.Persoon(Naam VARCHAR(45), Ticketnummer VARCHAR(12), Vluchtnummer VARCHAR(10), Bestemming VARCHAR(30), Vertrekpunt VARCHAR(30));"

echo "Done!"
echo "Rebooting"
netplan apply && reboot
