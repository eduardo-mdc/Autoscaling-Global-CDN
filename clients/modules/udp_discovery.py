import socket
import os

UDP_PORT = 9000
BUFFER_SIZE = 1024
SHARED_DIR = "/home/azureuser/shared-cache"

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
    # Lista de peers manual ou predefinida
    peers = ["10.0.0.4", "10.0.0.5"]
    local_ip = get_local_ip()
    peers = [ip for ip in peers if ip != local_ip]

    s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    s.settimeout(timeout)
    msg = f"QUERY {filename}".encode()

    for ip in peers:
        try:
            s.sendto(msg, (ip, UDP_PORT))
        except Exception as e:
            print(f"❌ Erro ao contactar {ip}: {e}")

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