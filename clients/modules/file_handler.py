import os
import requests
import re
import urllib3

SHARED_DIR = "/home/azureuser/shared-cache"
PROXY_BASE = "https://127.0.0.1/files/"
HTTP_PORT = 8080

urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)

def listar_arquivos():
    try:
        r = requests.get(PROXY_BASE, verify=False)
        matches = re.findall(r'href="([^\"]+)"', r.text)
        return [m for m in matches if not m.startswith("../") and "Zone.Identifier" not in m]
    except:
        return []

def arquivo_em_cache(arquivo):
    return os.path.exists(os.path.join(SHARED_DIR, arquivo))

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

def get_shared_path(arquivo):
    return os.path.join(SHARED_DIR, arquivo)