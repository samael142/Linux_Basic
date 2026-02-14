which prometheus-node-exporter || (apt update && apt install -y prometheus-node-exporter)
which prometheus || (apt update && apt install -y prometheus)
which grafana-cli || (apt install -y adduser libfontconfig1 musl  && sudo dpkg -i /tmp/grafana_11.2.2_amd64.deb)

if [ -f /tmp/.env ]; then
    source /tmp/.env
else
    echo "Файл .env не найден"
    exit 1
fi

cat >> /etc/prometheus/prometheus.yml <<EOF
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
systemctl enable --now grafana-server

which java || (apt update && apt install -y default-jdk)
dpkg -l | grep elasticsearch || dpkg -i /tmp/elasticsearch_8.17.1_amd64.deb
cp /tmp/jvm.options /etc/elasticsearch/jvm.options.d/
cp /tmp/elasticsearch.yml /etc/elasticsearch/
sed -i "s/ELK1/$(hostname)/g" /etc/elasticsearch/elasticsearch.yml
systemctl daemon-reload
systemctl enable --now elasticsearch.service
dpkg -l | grep kibana || dpkg -i /tmp/kibana_8.17.1_amd64.deb
cp /tmp/kibana.yml /etc/kibana/
systemctl daemon-reload
systemctl enable --now kibana.service
dpkg -l | grep logstash || dpkg -i /tmp/logstash_8.17.1_amd64.deb
echo "path.config: /etc/logstash/conf.d" | tee -a /etc/logstash/logstash.yml
cp /tmp/logstash-nginx-es.conf /etc/logstash/conf.d/
systemctl restart logstash.service
