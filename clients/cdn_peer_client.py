import os
import threading
from modules.http_server import start_http_server
from modules.udp_discovery import udp_listener, query_peers
from modules.file_handler import (
    listar_arquivos,
    baixar_de_peer,
    baixar_do_proxy,
    abrir_arquivo,
    get_shared_path,
    arquivo_em_cache,
)


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

        if arquivo_em_cache(arquivo):
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
