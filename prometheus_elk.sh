which prometheus-node-exporter || apt install -y prometheus-node-exporter
which pormetheus || apt install -y prometheus
which grafana-cli || (apt install -y adduser libfontconfig1 musl  && sudo dpkg -i /tmp/grafana_11.2.2_amd64.deb)
CONFIG_FILE="/etc/prometheus/prometheus.yml"

if [ -f /tmp/.env ]; then
    source /tmp/.env
else
    echo "Файл .env не найден"
    exit 1
fi

cat >> "$CONFIG_FILE" <<EOF
  - job_name: project
    static_configs:
      - targets: ['${WEB}:9100']
        labels:
          name: 'WEB'
      - targets: ['${DB_SOURCE}:9100']
        labels:
          name: 'SQL_SOURCE'
      - targets: ['${DB_REPLICA}:9100']
        labels:
          name: 'SQL_REPLICA'
      - targets: ['${ELK}:9100']
        labels:
          name: 'ELK'
EOF
systemctl restart prometheus.service
systemctl daemon-reload
systemctl start grafana-server
systemctl status grafana-server
