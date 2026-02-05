#!/bin/bash

if [ -f /tmp/.env ]; then
    source /tmp/.env
else
    echo "Файл .env не найден"
    exit 1
fi

which prometheus-node-exporter || apt install -y prometheus-node-exporter
which mysql || (apt update && apt install -y mysql-server)

mysql <<EOF
ALTER USER 'root'@'localhost' IDENTIFIED WITH 'caching_sha2_password' BY '1234567890';
EOF
sudo tee /etc/mysql/mysql.conf.d/mysqld.cnf <<EOF
[mysqld]
bind-address = 127.0.0.1
server-id = 2
relay-log = relay-log-server
read-only = ON
gtid-mode=ON
enforce-gtid-consistency
log-replica-updates
EOF
systemctl restart mysql
mysql -u root -p'1234567890' <<EOF
STOP REPLICA;
CHANGE REPLICATION SOURCE TO SOURCE_HOST='${DB_SOURCE}', SOURCE_USER='repl', SOURCE_PASSWORD='1234567890', SOURCE_AUTO_POSITION = 1, GET_SOURCE_PUBLIC_KEY = 1;
START REPLICA;
EOF

