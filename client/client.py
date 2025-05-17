import os
import json
import requests
from config import LOAD_BALANCER_URL, CACHE_FOLDER, PEERS_FILE
from cache_manager import enforce_cache_limit


def get_peers():
    if not os.path.exists(PEERS_FILE):
        return []
    with open(PEERS_FILE) as f:
        return json.load(f)


def find_video_in_peers(video_name):
    for peer in get_peers():
        try:
            url = f"http://{peer}:5000/video/{video_name}"
            r = requests.get(url, timeout=2)
            if r.status_code == 200:
                return url
        except:
            continue
    return None


def fetch_video(video_name):
    os.makedirs(CACHE_FOLDER, exist_ok=True)
    enforce_cache_limit()

    # Tenta encontrar nos peers
    peer_url = find_video_in_peers(video_name)
    if peer_url:
        print(f"[P2P] Fetching from peer: {peer_url}")
        video_data = requests.get(peer_url)
    else:
        # Vai buscar IP ao Load Balancer
        lb_res = requests.get(LOAD_BALANCER_URL).json()
        cdn_ip = lb_res["ip"]
        url = f"http://{cdn_ip}/hls/{video_name}"
        print(f"[CDN] Fetching from CDN: {url}")
        video_data = requests.get(url)

    path = os.path.join(CACHE_FOLDER, video_name)
    with open(path, "wb") as f:
        f.write(video_data.content)
    print(f"[OK] Guardado em cache: {video_name}")


if __name__ == "__main__":
    import sys
    from peer_server import start_server
    from threading import Thread

    # Arranca servidor P2P em background
    t = Thread(target=start_server, daemon=True)
    t.start()

    # Requisição via HLS (.m3u8)
    if len(sys.argv) != 2:
        print("Uso: python client.py <video.m3u8>")
        exit(1)

    video = sys.argv[1]
    fetch_video(video)
