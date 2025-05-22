# 📡 NGINX Streaming Server with HLS, RTMP, and HTTPS

Este projeto faz parte da fase de desenvolvimento de uma **CDN virtual descentralizada** com **offloading oportunista**. Ele disponibiliza uma infraestrutura de transmissão de vídeo contínua via **NGINX + RTMP + HLS + HTTPS (autoassinado)**, pronta para ser implementada em ambientes como Azure Container Instances ou localmente com Docker.

## 🚀 Imagem Docker
A imagem deste projeto está disponível em:
```
docker pull alfilipe/nginx-streaming
```

## 🗂 Estrutura do Projeto

```
server/
├── docker-compose.yml
├── data/
│   └── hls/                # Segmentos HLS gerados
└── nginx/
    ├── conf/
    │   └── nginx.conf      # Configuração do NGINX e RTMP
    ├── html/
    │   ├── index.html      # Página inicial
    │   ├── files/          # Arquivos estáticos (vídeos, imagens, textos)
    │   │   ├── *.mp4
    │   │   ├── *.txt
    │   │   └── *.jpeg
    │   └── live/           # Player HLS para o stream
    │       └── index.html
    └── ssl/
        ├── gen_cert.sh     # Script de geração de certificado autoassinado
        ├── nginx.crt       # Certificado
        └── nginx.key       # Chave privada
```

## ▶️ Executar Localmente com Docker Compose

```bash
git clone https://github.com/AFilipe-IT/server.git
cd server
docker-compose up --build
```

Acesse via navegador:

- Página inicial: [https://localhost:443](https://localhost:8181)
- Player de vídeo (stream HLS): [https://localhost/live](https://localhost/live)

⚠️ O certificado é autoassinado. Aceite o aviso de segurança no navegador.

## ☁️ Deploy no Azure Container Instances

```bash
az container create   --resource-group streaming-rg   --name nginx-streaming   --image alfilipe/nginx-streaming:latest   --dns-name-label nginxstreamingdemo   --ports 8181 1935 443 80   --protocol TCP   --os-type Linux   --cpu 1   --memory 1.5
```

Acesse: https://nginxstreamingdemo.westeurope.azurecontainer.io

## 📡 Sobre o Projeto Maior

Este projeto é uma fase do trabalho:  
**"Decentralized Virtual CDN With Opportunistic Offloading"**, que aborda:

- Conformidade com GDPR e soberania de dados
- Arquitetura distribuída de CDN utilizando dispositivos cliente
- Estratégia de caching de 100MB por cliente
- Proxy reverso no cliente com cache e SSL
- Disseminação de assets com REST/HTTPS
- Otimização de performance (latência e throughput)
- Previsão de carga com modelo de ML
- Estratégias de segurança (IDS, WAFs, TLS)