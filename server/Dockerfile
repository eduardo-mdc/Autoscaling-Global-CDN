FROM tiangolo/nginx-rtmp:latest

RUN apt-get update && apt-get install -y ffmpeg && apt-get clean && rm -rf /var/lib/apt/lists/*

# Copiar nginx.conf e certificados SSL direto para o local esperado
COPY nginx/conf/nginx.conf /etc/nginx/nginx.conf
COPY nginx/ssl /etc/nginx/ssl

# Copiar arquivos HTML e vídeos
COPY nginx/html /usr/share/nginx/html

# Permissões para diretório de HLS (NGINX grava aqui)
RUN mkdir -p /tmp/hls && chmod -R 777 /tmp/hls

COPY start_stream.sh /usr/local/bin/start_stream.sh
RUN chmod +x /usr/local/bin/start_stream.sh

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh
ENTRYPOINT ["/entrypoint.sh"]
