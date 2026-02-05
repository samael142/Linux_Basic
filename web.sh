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
su - $SUDO_USER -c "ssh -o ConnectTimeout=2 ${REMOTE_USER}@${DB_SOURCE} exit" || { echo "❌ DB_SOURCE недоступен"; exit 1; }
su - $SUDO_USER -c "ssh -o ConnectTimeout=2 ${REMOTE_USER}@${DB_REPLICA} exit" || { echo "❌ DB_REPLICA недоступен"; exit 1; }
su - $SUDO_USER -c "ssh -o ConnectTimeout=2 ${REMOTE_USER}@${ELK} exit" || { echo "❌ ELK недоступен"; exit 1; }

echo "✅ Все серверы доступны"
sleep 3

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CURRENT_IP=$(hostname -I | awk '{print $1}')

if [ "$CURRENT_IP" = "$WEB" ]; then
    echo "Это web сервер, начинаем выполнение"
    for i in {5..1}
    do
    	echo -ne "\r$i...   "  # \r возвращает каретку в начало строки
    	sleep 1
    done
    which prometheus-node-exporter || apt install -y prometheus-node-exporter
    which docker || (apt update && apt install -y docker.io docker-compose-v2)
    which nginx || (apt update && apt install nginx -y)
    cp ./data/docker-proxy.conf /etc/nginx/sites-available/
    ln -s /etc/nginx/sites-available/docker-proxy.conf /etc/nginx/sites-enabled/
    rm -f /etc/nginx/sites-enabled/default
    systemctl reload nginx
    docker compose up -d

    su - $SUDO_USER -c "scp ${SCRIPT_DIR}/mysql_source.sh ${REMOTE_USER}@${DB_SOURCE}:/tmp/"
    su - $SUDO_USER -c "scp ${SCRIPT_DIR}/data/sak.sql ${REMOTE_USER}@${DB_SOURCE}:/tmp/"
    su - $SUDO_USER -c "ssh ${REMOTE_USER}@${DB_SOURCE} 'sudo bash /tmp/mysql_source.sh'"

    su - $SUDO_USER -c "scp ${SCRIPT_DIR}/mysql_replica.sh ${REMOTE_USER}@${DB_REPLICA}:/tmp/"
    su - $SUDO_USER -c "scp ${SCRIPT_DIR}/.env ${REMOTE_USER}@${DB_REPLICA}:/tmp/"
    su - $SUDO_USER -c "ssh ${REMOTE_USER}@${DB_REPLICA} 'sudo bash /tmp/mysql_replica.sh'"

    su - $SUDO_USER -c "scp ${SCRIPT_DIR}/prometheus_elk.sh ${REMOTE_USER}@${ELK}:/tmp/"
    su - $SUDO_USER -c "scp ${SCRIPT_DIR}/.env ${REMOTE_USER}@${ELK}:/tmp/"
    su - $SUDO_USER -c "scp ${SCRIPT_DIR}/soft/grafana_11.2.2_amd64.deb ${REMOTE_USER}@${ELK}:/tmp/"
    su - $SUDO_USER -c "ssh ${REMOTE_USER}@${ELK} 'sudo bash /tmp/prometheus_elk.sh'"
	
    exit 0	
fi

echo "Это НЕ web сервер, скрипт надо запускать на web сервере!!!"
exit 1
