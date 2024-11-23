#!/bin/bash
/usr/sbin/useradd -s /bin/bash -m ritesh;
mkdir /home/ritesh/.ssh;
chmod -R 700 /home/ritesh;
echo "ssh-rsa XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX ritesh@DESKTOP-0XXXXXX" >> /home/ritesh/.ssh/authorized_keys;
chmod 600 /home/ritesh/.ssh/authorized_keys;
chown ritesh:ritesh /home/ritesh/.ssh -R;
echo "ritesh  ALL=(ALL)  NOPASSWD:ALL" > /etc/sudoers.d/ritesh;
chmod 440 /etc/sudoers.d/ritesh;

#################################### Installing Promtail #####################################

#useradd --system promtail
cd /opt && wget https://github.com/grafana/loki/releases/download/v3.2.1/promtail-linux-amd64.zip
unzip promtail-linux-amd64.zip
rm -f promtail-linux-amd64.zip
cd /opt && wget https://raw.githubusercontent.com/grafana/loki/main/clients/cmd/promtail/promtail-local-config.yaml

cat > /etc/systemd/system/promtail.service <<EOT
[Unit]
Description=Promtail service
After=network.target

[Service]
Type=simple
User=root
ExecStart=/opt/promtail-linux-amd64 -config.file=/opt/promtail-local-config.yaml

[Install]
WantedBy=multi-user.target
EOT

systemctl enable promtail
systemctl start promtail

############################################################### Installation of PostgreSQL #############################################################

yum install -y https://download.postgresql.org/pub/repos/yum/reporpms/EL-8-x86_64/pgdg-redhat-repo-latest.noarch.rpm
yum -qy module disable postgresql
yum install -y postgresql14-server

/usr/pgsql-14/bin/postgresql-14-setup initdb

systemctl enable postgresql-14
systemctl start postgresql-14
systemctl status postgresql-14

cat > /opt/sonarqube.sql <<EODF
create database sonarqubedb;
create user sonarqube with encrypted password 'Cloud#436';
grant all privileges on database sonarqubedb to sonarqube;
EODF

sudo -u postgres psql -f /opt/sonarqube.sql

############################################################### Installation of SonarQube ##############################################################

yum install -y zip unzip vim wget
useradd -s /bin/bash -m sonar;
echo "Password@#795" | passwd sonar --stdin;
echo "sonar  ALL=(ALL)  NOPASSWD:ALL" >> /etc/sudoers

cat >> /etc/sysctl.conf <<EOT
vm.max_map_count = 262144
fs.file-max = 65536
EOT

cat >> /etc/security/limits.conf <<EOF
sonar   -   nofile   65536

#Nofile is the maximum number of open files
EOF

sysctl -p
yum install -y java-17* git
cd /opt/ && wget https://binaries.sonarsource.com/Distribution/sonarqube/sonarqube-9.9.5.90363.zip
unzip sonarqube-9.9.5.90363.zip
mv /opt/sonarqube-9.9.5.90363 /opt/sonarqube
chown -R sonar:sonar /opt/sonarqube

cat > /etc/systemd/system/sonarqube.service <<END_OF_SCRIPT
[Unit]
Description=SonarQube service
After=syslog.target network.target

[Service]
Type=forking
User=sonar
Group=sonar
ExecStart=/opt/sonarqube/bin/linux-x86-64/sonar.sh start
ExecStop=/opt/sonarqube/bin/linux-x86-64/sonar.sh stop
Restart=always

[Install]
WantedBy=multi-user.target
END_OF_SCRIPT

sed -i '/#sonar.jdbc.username=/s//sonar.jdbc.username=sonarqube/' /opt/sonarqube/conf/sonar.properties;
sed -i '/#sonar.jdbc.password=/s//sonar.jdbc.password=Cloud#436/' /opt/sonarqube/conf/sonar.properties;
sed -i 's%#sonar.jdbc.url=jdbc:postgresql://localhost/sonarqube?currentSchema=my_schema%sonar.jdbc.url=jdbc:postgresql://localhost/sonarqubedb%g' /opt/sonarqube/conf/sonar.properties;

systemctl enable sonarqube
systemctl start sonarqube
systemctl status sonarqube

#################################### Installing Node Exporter #####################################

useradd --system --no-create-home --shell /bin/false node_exporter
cd /opt/ && wget https://github.com/prometheus/node_exporter/releases/download/v1.6.1/node_exporter-1.6.1.linux-amd64.tar.gz
tar -xvf node_exporter-1.6.1.linux-amd64.tar.gz
sudo mv node_exporter-1.6.1.linux-amd64/node_exporter /usr/local/bin/
rm -rf node_exporter*

cat > /etc/systemd/system/node_exporter.service <<END_FOR_SCRIPT
[Unit]
Description=Node Exporter
Wants=network-online.target
After=network-online.target

StartLimitIntervalSec=500
StartLimitBurst=5

[Service]
User=node_exporter
Group=node_exporter
Type=simple
Restart=on-failure
RestartSec=5s
ExecStart=/usr/local/bin/node_exporter --collector.logind

[Install]
WantedBy=multi-user.target
END_FOR_SCRIPT

systemctl enable node_exporter
systemctl start node_exporter

####################################################################

mkdir /mederma;
mkfs.xfs /dev/sdc;
echo "/dev/sdc  /mederma  xfs  defaults 0 0" >> /etc/fstab;
mount -a;
