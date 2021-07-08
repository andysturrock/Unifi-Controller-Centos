#!/bin/bash -x

# Some credit here: https://community.spiceworks.com/how_to/128121-installing-unifi-controller-on-centos
# especially the firewall stuff

VERSION=5.10.24-11676
VERSION=5.12.35-12979
VERSION=5.12.66-13102
VERSION=5.13.32-13646
VERSION=6.0.45-14358
VERSION=6.1.71-15061

alien -r unifi_sysvinit_all.deb --target=x86_64 --generate --scripts --verbose

yum -y install apache-commons-daemon-jsvc
yum -y install redhat-lsb
yum -y install java-1.8.0-openjdk
yum -y install java-1.8.0-openjdk
yum -y install apache-commons-daemon
yum -y install mongodb-server

useradd -r unifi

mkdir -p /opt/unifi/usr/lib
mkdir -p /opt/unifi/usr/share/doc

cp -r unifi-${VERSION}/usr/lib/unifi /opt/unifi/usr/lib/
cp -r unifi-${VERSION}/usr/share/doc/unifi /opt/unifi/usr/share/doc/unifi

TMPFILE=`mktemp`
sed -e "s#^BASEDIR=\"/usr/lib/unifi\"#BASEDIR=\"/opt/unifi/usr/lib/unifi\"#g" unifi-${VERSION}/usr/lib/unifi/bin/unifi.init > $TMPFILE
cp $TMPFILE /opt/unifi/usr/lib/unifi/bin/unifi.init

head -1 /opt/unifi/usr/lib/unifi/bin/unifi.init > $TMPFILE
echo "mkdir -p /var/run/unifi" >> $TMPFILE
echo "chown -R unifi:unifi /var/run/unifi" >> $TMPFILE
tail -n +2 /opt/unifi/usr/lib/unifi/bin/unifi.init >> $TMPFILE
cp $TMPFILE /opt/unifi/usr/lib/unifi/bin/unifi.init

sed -e "s#^\. /lib/lsb/init-functions#\. /etc/init.d/functions#g" /opt/unifi/usr/lib/unifi/bin/unifi.init > $TMPFILE
cp $TMPFILE /opt/unifi/usr/lib/unifi/bin/unifi.init

sed -e "s#log_daemon_msg#echo#g" /opt/unifi/usr/lib/unifi/bin/unifi.init > $TMPFILE
cp $TMPFILE /opt/unifi/usr/lib/unifi/bin/unifi.init

sed -e "s#log_end_msg#success#g" /opt/unifi/usr/lib/unifi/bin/unifi.init > $TMPFILE
cp $TMPFILE /opt/unifi/usr/lib/unifi/bin/unifi.init

sed -e "s#JAVA_HOME=/usr/lib/jvm/java-8-openjdk-\${arch}#JAVA_HOME=/usr/lib/jvm/jre-1.8.0#g" /opt/unifi/usr/lib/unifi/bin/unifi.init > $TMPFILE
cp $TMPFILE /opt/unifi/usr/lib/unifi/bin/unifi.init

sed -e "s#PIDFILE=\"/var/run/\${NAME}.pid\"#PIDFILE=\"/var/run/\${NAME}/\${NAME}.pid\"#g" /opt/unifi/usr/lib/unifi/bin/unifi.init > $TMPFILE
cp $TMPFILE /opt/unifi/usr/lib/unifi/bin/unifi.init

sed -e "s#-outfile SYSLOG#-outfile /var/log/unifi/unifi.out#g" /opt/unifi/usr/lib/unifi/bin/unifi.init > $TMPFILE
cp $TMPFILE /opt/unifi/usr/lib/unifi/bin/unifi.init

sed -e "s#-errfile SYSLOG#-errfile /var/log/unifi/unifi.err#g" /opt/unifi/usr/lib/unifi/bin/unifi.init > $TMPFILE
cp $TMPFILE /opt/unifi/usr/lib/unifi/bin/unifi.init

rm $TMPFILE

chown -R unifi:unifi /opt/unifi

mkdir -p /var/lib/unifi /var/log/unifi /var/run/unifi
chown -R unifi:unifi /var/lib/unifi /var/log/unifi /var/run/unifi

mkdir -p /var/run/unifi
chown unifi:unifi /var/run/unifi

cp unifi-${VERSION}/etc/pam.d/unifi /etc/pam.d/unifi

#Unifi wants to run mongod itself, so symlink that...
ln -s /bin/mongod /opt/unifi/usr/lib/unifi/bin/mongod

cat <<EOF > /lib/systemd/system/unifi.service
[Unit]
Description=unifi
Requires=network.target
After=network.target

[Service]
Type=simple
User=unifi
WorkingDirectory=/opt/unifi
Restart=always
Type=forking
TimeoutSec=5min
KillMode=process
NotifyAccess=all
ExecStart=/opt/unifi/usr/lib/unifi/bin/unifi.init start
ExecStop=/opt/unifi/usr/lib/unifi/bin/unifi.init stop
ExecReload=/opt/unifi/usr/lib/unifi/bin/unifi.init reload

[Install]
WantedBy=multi-user.target
EOF

systemctl enable unifi

cat <<EOF > /etc/firewalld/services/unifi.xml
<?xml version="1.0" encoding="utf-8"?>
<service version="1.0">
<short>unifi</short>
<description>UniFi Controller</description>
<port port="8081" protocol="tcp"/>
<port port="8080" protocol="tcp"/>
<port port="8443" protocol="tcp"/>
<port port="8880" protocol="tcp"/>
<port port="8843" protocol="tcp"/>
<port port="10001" protocol="udp"/>
<port port="3478" protocol="udp"/>
</service>
EOF

# This may differ on your system
systemctl restart firewalld.service
firewall-cmd --set-default-zone=public
firewall-cmd --permanent --zone=public --change-interface=eth0
firewall-cmd --permanent --zone=public --add-service=unifi 
