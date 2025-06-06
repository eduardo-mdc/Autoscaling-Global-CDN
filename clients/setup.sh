#!/bin/bash
set -e

echo "🔧 Atualizando sistema..."
sudo apt update && sudo apt install -y nginx openssl python3 python3-pip curl

echo "🔐 Gerando certificado autoassinado..."
sudo mkdir -p /etc/nginx/ssl
sudo openssl req -x509 -nodes -days 365 \
  -newkey rsa:2048 \
  -keyout /etc/nginx/ssl/selfsigned.key \
  -out /etc/nginx/ssl/selfsigned.crt \
  -subj "/C=XX/ST=XX/L=XX/O=CDNClient/OU=EdgeClient/CN=localhost"

echo "⚙️ Configurando NGINX com cache reverso..."
sudo tee /etc/nginx/sites-available/default > /dev/null <<EOF
proxy_cache_path /var/cache/nginx levels=1:2 keys_zone=cdn_cache:10m max_size=100m inactive=60m use_temp_path=off;

server {
    listen 443 ssl;
    server_name localhost;

    ssl_certificate     /etc/nginx/ssl/selfsigned.crt;
    ssl_certificate_key /etc/nginx/ssl/selfsigned.key;

    location / {
        proxy_pass https://nginxstreamingdemo.westeurope.azurecontainer.io:8181;
        proxy_ssl_verify off;

        proxy_cache cdn_cache;
        proxy_cache_valid 200 302 10m;
        proxy_cache_valid 404      1m;
        proxy_cache_use_stale error timeout updating;

        proxy_set_header Host \$host;
        add_header X-Cache-Status \$upstream_cache_status;
    }
}
EOF

sudo nginx -t && sudo systemctl restart nginx

echo "📂 Criando diretório de cache compartilhado..."
mkdir -p /home/client/shared-cache

echo "🐍 Instalando dependências Python..."
pip3 install requests

echo "📄 Baixando script P2P..."
curl -o /home/client/cdn_peer_client.py https://raw.githubusercontent.com/SEU_REPOSITORIO/cdn_peer_client/main/cdn_peer_client.py

echo "✅ Pronto! Para executar:"
echo "python3 /home/client/cdn_peer_client.py"
