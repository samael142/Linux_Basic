#!/bin/bash

which prometheus-node-exporter || apt install -y prometheus-node-exporter
which mysql || (apt update && apt install -y mysql-server)

mysql <<EOF
ALTER USER 'root'@'localhost' IDENTIFIED WITH 'caching_sha2_password' BY '1234567890';
CREATE USER repl@'%' IDENTIFIED WITH 'caching_sha2_password' BY '1234567890';
GRANT REPLICATION SLAVE ON *.* TO repl@'%';
CREATE USER 'remote'@'%' IDENTIFIED BY '1234567890';
GRANT ALL PRIVILEGES ON *.* TO 'remote'@'%' WITH GRANT OPTION;
EOF
sudo tee /etc/mysql/mysql.conf.d/mysqld.cnf <<EOF
[mysqld]
bind-address = 0.0.0.0
server-id = 1
log_bin = /var/log/mysql/mysql-bin.log
log-bin = mysql-bin
binlog_format = row
gtid-mode=ON
enforce-gtid-consistency
log-replica-updates
EOF
systemctl restart mysql

mysql -u root -p'1234567890' <<EOF
CREATE DATABASE IF NOT EXISTS sakila;
EOF
mysql -u root -p'1234567890' sakila < /tmp/sak.sql
