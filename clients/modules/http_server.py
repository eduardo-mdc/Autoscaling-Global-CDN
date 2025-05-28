import os
import http.server
import socketserver
import threading

SHARED_DIR = "/home/azureuser/shared-cache"
HTTP_PORT = 8080

def start_http_server():
    os.makedirs(SHARED_DIR, exist_ok=True)
    os.chdir(SHARED_DIR)
    handler = http.server.SimpleHTTPRequestHandler
    httpd = socketserver.TCPServer(("", HTTP_PORT), handler)
    threading.Thread(target=httpd.serve_forever, daemon=True).start()
    print(f"🚀 Servindo cache em http://0.0.0.0:{HTTP_PORT}")