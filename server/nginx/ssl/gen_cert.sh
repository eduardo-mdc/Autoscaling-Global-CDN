
#!/bin/bash
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
-keyout /home/alfilipe/nginx_streaming_project/nginx/ssl/nginx.key \
-out /home/alfilipe/nginx_streaming_project/nginx/ssl/nginx.crt \
-subj "/C=US/ST=Local/L=Local/O=Local/OU=Dev/CN=localhost"
