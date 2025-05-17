from flask import Flask, send_from_directory
from config import CACHE_FOLDER

app = Flask(__name__)


@app.route("/video/<path:filename>")
def serve_video(filename):
    return send_from_directory(CACHE_FOLDER, filename)


def start_server(port=5000):
    app.run(host="0.0.0.0", port=port)
