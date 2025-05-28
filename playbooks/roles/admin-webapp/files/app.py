import os
import shutil
import uuid
import subprocess
from flask import (
    Flask, request, redirect, url_for,
    render_template, flash, send_from_directory
)
from werkzeug.utils import secure_filename

# -----------------------------------------------------------------------------
# Configuration
# -----------------------------------------------------------------------------
MOUNT_PATH = "/mnt/videos"
TMP_PATH   = os.environ.get('TMP_PATH', '/tmp')
ALLOWED_EXTS = {'mp4', 'mov', 'avi', 'mkv'}

app = Flask(__name__, template_folder='templates')
app.secret_key = os.environ.get('FLASK_SECRET', 'change-me')

# -----------------------------------------------------------------------------
# Helpers
# -----------------------------------------------------------------------------

def allowed_file(filename):
    return '.' in filename and filename.rsplit('.', 1)[1].lower() in ALLOWED_EXTS


def make_hls(input_filepath, output_dir):
    os.makedirs(output_dir, exist_ok=True)
    playlist = os.path.join(output_dir, 'playlist.m3u8')
    cmd = [
        'ffmpeg', '-i', input_filepath,
        '-profile:v', 'baseline', '-level', '3.0',
        '-start_number', '0',
        '-hls_time', '10',
        '-hls_list_size', '0',
        '-f', 'hls',
        playlist
    ]
    subprocess.check_call(cmd)
    return playlist

# -----------------------------------------------------------------------------
# Routes
# -----------------------------------------------------------------------------

@app.route('/')
def index():
    videos_dir = os.path.join(MOUNT_PATH, 'videos')
    hls_dir = os.path.join(MOUNT_PATH, 'hls')

    # Create directories if they don't exist yet
    os.makedirs(videos_dir, exist_ok=True)
    os.makedirs(hls_dir, exist_ok=True)

    videos = sorted(os.listdir(videos_dir)) if os.path.exists(videos_dir) else []
    hls_streams = sorted(os.listdir(hls_dir)) if os.path.exists(hls_dir) else []

    return render_template('index.html', videos=videos, hls_streams=hls_streams)

@app.route('/upload', methods=('GET','POST'))
def upload():
    if request.method == 'POST':
        file = request.files.get('file')
        if not file or not allowed_file(file.filename):
            flash('No valid video selected', 'danger')
            return redirect(request.url)

        # Create required directory structure if not exists
        videos_dir = os.path.join(MOUNT_PATH, 'videos')
        hls_dir = os.path.join(MOUNT_PATH, 'hls')
        os.makedirs(videos_dir, exist_ok=True)
        os.makedirs(hls_dir, exist_ok=True)

        # Secure the filename for storage
        original_filename = secure_filename(file.filename)

        # Save original file to videos directory
        original_path = os.path.join(videos_dir, original_filename)
        file.save(original_path)

        # Create temporary folder for HLS conversion
        folder_id = uuid.uuid4().hex
        hls_output_dir = os.path.join(hls_dir, folder_id)

        try:
            # Convert to HLS format
            make_hls(original_path, hls_output_dir)
            flash(f'Uploaded & converted: {original_filename}', 'success')

            # Run sync-to-regions script
            app.logger.info("Running sync-to-regions script")
            sync_result = subprocess.run(['/opt/content/scripts/sync-to-regions.sh'],
                                         capture_output=True, text=True)
            app.logger.info(f"Script output: {sync_result.stdout}")
            if sync_result.returncode != 0:
                app.logger.error(f"Script error: {sync_result.stderr}")

        except Exception as e:
            flash(f'Error transcoding: {e}', 'danger')
            if os.path.exists(hls_output_dir):
                shutil.rmtree(hls_output_dir)
            # Keep the original file even if conversion fails

        return redirect(url_for('index'))

    return render_template('upload.html')

@app.route('/delete/video/<filename>', methods=('POST',))
def delete_video(filename):
    target = os.path.join(MOUNT_PATH, 'videos', filename)
    if os.path.isfile(target):
        os.remove(target)
        flash(f'Deleted video: {filename}', 'warning')
    else:
        flash('Video not found', 'danger')
    return redirect(url_for('index'))

@app.route('/delete/hls/<folder>', methods=('POST',))
def delete_hls(folder):
    target = os.path.join(MOUNT_PATH, 'hls', folder)
    if os.path.isdir(target):
        shutil.rmtree(target)
        flash(f'Deleted HLS stream: {folder}', 'warning')
    else:
        flash('HLS stream not found', 'danger')
    return redirect(url_for('index'))

@app.route('/videos/<path:filename>')
def serve_video(filename):
    return send_from_directory(os.path.join(MOUNT_PATH, 'videos'), filename)

@app.route('/hls/<folder>/<path:filename>')
def serve_hls(folder, filename):
    return send_from_directory(os.path.join(MOUNT_PATH, 'hls', folder), filename)

if __name__ == '__main__':
    port = int(os.environ.get('PORT', 80))
    app.run(host='0.0.0.0', port=port, debug=True)