#!/bin/bash
/usr/sbin/useradd -s /bin/bash -m ritesh;
mkdir /home/ritesh/.ssh;
chmod -R 700 /home/ritesh;
echo "ssh-rsa XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX ritesh@DESKTOP-0XXXXXX" >> /home/ritesh/.ssh/authorized_keys;
chmod 600 /home/ritesh/.ssh/authorized_keys;
chown ritesh:ritesh /home/ritesh/.ssh -R;
echo "ritesh  ALL=(ALL)  NOPASSWD:ALL" > /etc/sudoers.d/ritesh;
chmod 440 /etc/sudoers.d/ritesh;

#################################### Loki ##############################################

#useradd --system loki
cd /opt && wget https://github.com/grafana/loki/releases/download/v3.2.1/loki-linux-amd64.zip
unzip loki-linux-amd64.zip
rm -f loki-linux-amd64.zip
cd /opt && wget https://raw.githubusercontent.com/grafana/loki/main/cmd/loki/loki-local-config.yaml

LOCAL_SERVER_PRIVATE_IP=`ip addr| grep "noprefixroute eth0" | cut -d ' ' -f 6 | sed s'/\/.*//g'`
sed -i "0,/instance_addr: 127.0.0.1/s//instance_addr: $LOCAL_SERVER_PRIVATE_IP/" /opt/loki-local-config.yaml
sed -i "0,/store: inmemory/s//store: memberlist/" /opt/loki-local-config.yaml
sed -i "0,/object_store: filesystem/s//object_store: azure/" /opt/loki-local-config.yaml
sed -i "0,/loki_address: localhost:3100/s//loki_address: $LOCAL_SERVER_PRIVATE_IP:3100/" /opt/loki-local-config.yaml
sed -i "s%alertmanager_url: http://localhost:9093%alertmanager_url: http://$LOCAL_SERVER_PRIVATE_IP:9093%" /opt/loki-local-config.yaml
sed -i "0,/replication_factor: 1/s//replication_factor: 3/" /opt/loki-local-config.yaml
sed -i "0,/filesystem:/s//azure:/" /opt/loki-local-config.yaml
sed -i "s%chunks_directory: /tmp/loki/chunks%account_name: blogapptachotacho%" /opt/loki-local-config.yaml
sed -i "s%rules_directory: /tmp/loki/rules%container_name: dexter%" /opt/loki-local-config.yaml

cat > /etc/systemd/system/loki.service <<EOF
[Unit]
Description=Loki service
After=network.target

[Service]
Type=simple
User=root
ExecStart=/opt/loki-linux-amd64 -config.file=/opt/loki-local-config.yaml

[Install]
WantedBy=multi-user.target
EOF

systemctl enable loki
systemctl start loki

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

###############################################################################################

mkdir /mederma;
mkfs.xfs /dev/sdc;
echo "/dev/sdc  /mederma  xfs  defaults 0 0" >> /etc/fstab;
mount -a;
