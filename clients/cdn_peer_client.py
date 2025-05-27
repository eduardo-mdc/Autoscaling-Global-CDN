import re
import socket
import threading
import os
import requests
import http.server
import socketserver
import urllib3
import webbrowser
import time

# === CONFIGURACOES ===
SHARED_DIR = "/home/client/shared-cache"
PROXY_BASE = "https://127.0.0.1/files/"
UDP_PORT = 9000
HTTP_PORT = 8080
BUFFER_SIZE = 1024

urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)


def get_local_ip():
    s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    try:
        s.connect(("10.255.255.255", 1))
        IP = s.getsockname()[0]
    except:
        IP = "127.0.0.1"
    finally:
        s.close()
    return IP


def start_http_server():
    os.makedirs(SHARED_DIR, exist_ok=True)
    os.chdir(SHARED_DIR)
    handler = http.server.SimpleHTTPRequestHandler
    httpd = socketserver.TCPServer(("", HTTP_PORT), handler)
    threading.Thread(target=httpd.serve_forever, daemon=True).start()
    print(f"🚀 Servindo cache em http://0.0.0.0:{HTTP_PORT}")


def udp_listener():
    s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    s.bind(("", UDP_PORT))
    while True:
        data, addr = s.recvfrom(BUFFER_SIZE)
        msg = data.decode()
        if msg.startswith("QUERY"):
            _, filename = msg.split(" ", 1)
            path = os.path.join(SHARED_DIR, filename)
            if os.path.exists(path):
                response = f"HAVE {filename} {get_local_ip()}"
                s.sendto(response.encode(), addr)


def query_peers(filename, timeout=2):
    s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    s.setsockopt(socket.SOL_SOCKET, socket.SO_BROADCAST, 1)
    s.settimeout(timeout)
    msg = f"QUERY {filename}".encode()
    s.sendto(msg, ("<broadcast>", UDP_PORT))

    try:
        while True:
            data, addr = s.recvfrom(BUFFER_SIZE)
            msg = data.decode()
            if msg.startswith("HAVE"):
                _, fname, ip = msg.split(" ")
                if fname == filename:
                    return ip
    except socket.timeout:
        return None


def baixar_de_peer(ip, arquivo):
    url = f"http://{ip}:{HTTP_PORT}/{arquivo}"
    destino = os.path.join(SHARED_DIR, arquivo)
    try:
        r = requests.get(url, stream=True)
        r.raise_for_status()
        with open(destino, "wb") as f:
            for chunk in r.iter_content(1024 * 1024):
                f.write(chunk)
        print(f"✅ Baixado de peer {ip}")
        return True
    except Exception as e:
        print(f"❌ Erro ao baixar de peer {ip}: {e}")
        return False


def baixar_do_proxy(arquivo):
    url = f"{PROXY_BASE}{arquivo}"
    destino = os.path.join(SHARED_DIR, arquivo)
    try:
        r = requests.get(url, verify=False)
        r.raise_for_status()
        with open(destino, "wb") as f:
            f.write(r.content)
        print(f"✅ Baixado do servidor de origem (via proxy)")
        return True
    except Exception as e:
        print(f"❌ Erro ao baixar do proxy: {e}")
        return False


def abrir_arquivo(arquivo):
    caminho = os.path.join(SHARED_DIR, arquivo)
    if os.path.exists(caminho):
        print(f"📂 Arquivo salvo em: {caminho}")
        # webbrowser.open(f"file://{caminho}")
    else:
        print("❌ Arquivo inexistente.")


def listar_arquivos():
    try:
        r = requests.get(PROXY_BASE, verify=False)
        matches = re.findall(r'href="([^\"]+)"', r.text)
        return [m for m in matches if not m.startswith("../") and "Zone.Identifier" not in m]
    except:
        return []


def menu():
    import re
    while True:
        arquivos = listar_arquivos()
        if not arquivos:
            print("❌ Falha ao listar arquivos.")
            break

        print("\n📂 Arquivos disponíveis:")
        for i, a in enumerate(arquivos):
            print(f"{i+1}. {a}")
        print("0. Sair")

        try:
            op = int(input("\nEscolha um arquivo: "))
            if op == 0:
                break
            arquivo = arquivos[op - 1]
        except:
            print("❌ Entrada inválida")
            continue

        caminho = os.path.join(SHARED_DIR, arquivo)
        if os.path.exists(caminho):
            print("✅ Arquivo já está no cache local.")
            abrir_arquivo(arquivo)
            continue

        print("🔎 Procurando peers...")
        peer_ip = query_peers(arquivo)
        if peer_ip:
            if baixar_de_peer(peer_ip, arquivo):
                abrir_arquivo(arquivo)
                continue

        print("🌐 Nenhum peer respondeu. Baixando do proxy...")
        if baixar_do_proxy(arquivo):
            abrir_arquivo(arquivo)


if __name__ == "__main__":
    threading.Thread(target=udp_listener, daemon=True).start()
    start_http_server()
    menu()
