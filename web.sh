#!/bin/bash

if [[ $EUID -ne 0 ]]; then
   echo "Этот скрипт нужно запускать от sudo" 
   exit 1
fi

if [ -f .env ]; then
    source .env
else
    echo "Файл .env не найден"
    exit 1
fi

echo "Проверка доступности серверов..."

# Проверяем каждый сервер
su - $SUDO_USER -c "ssh -o ConnectTimeout=2 ${REMOTE_USER}@${DB_SOURCE} exit" || { echo "DB_SOURCE недоступен"; exit 1; }
su - $SUDO_USER -c "ssh -o ConnectTimeout=2 ${REMOTE_USER}@${DB_REPLICA} exit" || { echo "DB_REPLICA недоступен"; exit 1; }
su - $SUDO_USER -c "ssh -o ConnectTimeout=2 ${REMOTE_USER}@${ELK} exit" || { echo "ELK недоступен"; exit 1; }

echo "Все серверы доступны"
sleep 3

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CURRENT_IP=$(hostname -I | awk '{print $1}')


if [ "$CURRENT_IP" != "$WEB" ]; then
    echo "Скрипт надо запускать на WEB сервере"
    exit 1
fi

echo "Это web сервер, начинаем выполнение"
for i in {5..1}
do
    echo -ne "\r$i...   "
    sleep 1
done

which prometheus-node-exporter || apt install -y prometheus-node-exporter
which docker || (apt update && apt install -y docker.io docker-compose-v2)
which nginx || (apt update && apt install nginx -y)
which filebeat || dpkg -i ./soft/filebeat_8.17.1_amd64.deb
cp ./data/docker-proxy.conf /etc/nginx/sites-available/
ln -s /etc/nginx/sites-available/docker-proxy.conf /etc/nginx/sites-enabled/
rm -f /etc/nginx/sites-enabled/default
systemctl reload nginx
docker compose up -d
cp ./data/filebeat.yml /etc/filebeat
sed -i "s/localhost:5400/${ELK}:5400/" /etc/filebeat/filebeat.yml
systemctl restart filebeat.service



#su - $SUDO_USER -c "scp ${SCRIPT_DIR}/mysql_source.sh ${REMOTE_USER}@${DB_SOURCE}:/tmp/"
#su - $SUDO_USER -c "scp ${SCRIPT_DIR}/data/sak.sql ${REMOTE_USER}@${DB_SOURCE}:/tmp/"
#su - $SUDO_USER -c "ssh ${REMOTE_USER}@${DB_SOURCE} 'sudo bash /tmp/mysql_source.sh'"

#su - $SUDO_USER -c "scp ${SCRIPT_DIR}/mysql_replica.sh ${REMOTE_USER}@${DB_REPLICA}:/tmp/"
#su - $SUDO_USER -c "scp ${SCRIPT_DIR}/.env ${REMOTE_USER}@${DB_REPLICA}:/tmp/"
#su - $SUDO_USER -c "ssh ${REMOTE_USER}@${DB_REPLICA} 'sudo bash /tmp/mysql_replica.sh'"

su - $SUDO_USER -c "scp ${SCRIPT_DIR}/prometheus_elk.sh ${REMOTE_USER}@${ELK}:/tmp/"
su - $SUDO_USER -c "scp ${SCRIPT_DIR}/.env ${REMOTE_USER}@${ELK}:/tmp/"
su - $SUDO_USER -c "scp ${SCRIPT_DIR}/soft/grafana_11.2.2_amd64.deb ${REMOTE_USER}@${ELK}:/tmp/"
su - $SUDO_USER -c "scp ${SCRIPT_DIR}/soft/elasticsearch_8.17.1_amd64.deb ${REMOTE_USER}@${ELK}:/tmp/"
su - $SUDO_USER -c "scp ${SCRIPT_DIR}/soft/kibana_8.17.1_amd64.deb ${REMOTE_USER}@${ELK}:/tmp/"
su - $SUDO_USER -c "scp ${SCRIPT_DIR}/soft/logstash_8.17.1_amd64.deb ${REMOTE_USER}@${ELK}:/tmp/"
su - $SUDO_USER -c "scp ${SCRIPT_DIR}/data/elasticsearch.yml ${REMOTE_USER}@${ELK}:/tmp/"
su - $SUDO_USER -c "scp ${SCRIPT_DIR}/data/jvm.options ${REMOTE_USER}@${ELK}:/tmp/"
su - $SUDO_USER -c "scp ${SCRIPT_DIR}/data/logstash-nginx-es.conf ${REMOTE_USER}@${ELK}:/tmp/"
su - $SUDO_USER -c "scp ${SCRIPT_DIR}/data/kibana.yml ${REMOTE_USER}@${ELK}:/tmp/"
su - $SUDO_USER -c "ssh ${REMOTE_USER}@${ELK} 'sudo bash /tmp/prometheus_elk.sh'"
