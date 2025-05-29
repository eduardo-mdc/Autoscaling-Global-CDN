import os
import shutil
import subprocess
import tempfile
from datetime import datetime
from flask import Flask, request, redirect, url_for, render_template, flash, send_from_directory
from werkzeug.utils import secure_filename
from google.cloud import storage

# Configuration
MASTER_BUCKET_NAME = os.environ.get('GCS_BUCKET_NAME', 'your-bucket-name')
PROJECT_ID = os.environ.get('PROJECT_ID', 'your-project-id')
PROJECT_NAME = os.environ.get('PROJECT_NAME', 'your-project')
REGIONS = os.environ.get('REGIONS', 'europe-west2,us-south1,asia-southeast1').split(',')
LOCAL_VIDEOS_DIR = os.environ.get('VIDEOS_MOUNT_PATH', '/app/videos')
ALLOWED_EXTS = {'mp4', 'mov', 'avi', 'mkv', 'webm'}

app = Flask(__name__)
app.secret_key = os.environ.get('FLASK_SECRET', 'change-me-in-production')

# Initialize GCS client
storage_client = storage.Client()
master_bucket = storage_client.bucket(MASTER_BUCKET_NAME)

# Regional buckets
regional_buckets = {}
for region in REGIONS:
    bucket_name = f"{PROJECT_NAME}-content-{region}"
    regional_buckets[region] = storage_client.bucket(bucket_name)

def allowed_file(filename):
    return '.' in filename and filename.rsplit('.', 1)[1].lower() in ALLOWED_EXTS

def upload_to_gcs(local_path, gcs_path, target_bucket=None):
    """Upload file to Google Cloud Storage"""
    bucket_to_use = target_bucket or master_bucket
    blob = bucket_to_use.blob(gcs_path)
    blob.upload_from_filename(local_path)
    return blob.public_url

def list_gcs_files(prefix, target_bucket=None):
    """List files in GCS with given prefix"""
    bucket_to_use = target_bucket or master_bucket
    blobs = bucket_to_use.list_blobs(prefix=prefix)
    return [blob.name for blob in blobs if not blob.name.endswith('/')]

def delete_gcs_file(gcs_path, target_bucket=None):
    """Delete file from GCS"""
    bucket_to_use = target_bucket or master_bucket
    blob = bucket_to_use.blob(gcs_path)
    if blob.exists():
        blob.delete()

def sync_to_regional_buckets():
    """Sync master bucket content to all regional buckets"""
    sync_results = {}

    for region, regional_bucket in regional_buckets.items():
        try:
            # Get all files from master bucket
            master_blobs = list(master_bucket.list_blobs())
            master_files = {blob.name: blob for blob in master_blobs}

            # Get all files from regional bucket
            regional_blobs = list(regional_bucket.list_blobs())
            regional_files = {blob.name: blob for blob in regional_blobs}

            synced_files = 0
            deleted_files = 0

            # Copy new/updated files from master to regional
            for file_path, master_blob in master_files.items():
                regional_blob = regional_bucket.blob(file_path)

                # Check if file needs to be copied (doesn't exist or is different)
                should_copy = True
                if file_path in regional_files:
                    # Compare file sizes and timestamps
                    regional_existing = regional_files[file_path]
                    if (master_blob.size == regional_existing.size and
                            master_blob.updated == regional_existing.updated):
                        should_copy = False

                if should_copy:
                    # Copy blob from master to regional
                    regional_bucket.copy_blob(master_blob, regional_bucket, new_name=file_path)
                    synced_files += 1

            # Delete files in regional that don't exist in master (rsync -d behavior)
            for file_path in regional_files:
                if file_path not in master_files:
                    regional_files[file_path].delete()
                    deleted_files += 1

            sync_results[region] = {
                'status': 'success',
                'synced': synced_files,
                'deleted': deleted_files
            }

        except Exception as e:
            sync_results[region] = {
                'status': 'error',
                'error': str(e)
            }

    return sync_results

def make_hls(input_filepath, output_dir):
    """Convert video to HLS format"""
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

def upload_hls_folder(local_folder, gcs_prefix, target_bucket=None):
    """Upload entire HLS folder to GCS"""
    bucket_to_use = target_bucket or master_bucket
    uploaded_files = []

    for root, dirs, files in os.walk(local_folder):
        for file in files:
            local_file = os.path.join(root, file)
            relative_path = os.path.relpath(local_file, local_folder)
            gcs_path = f"{gcs_prefix}/{relative_path}"

            blob = bucket_to_use.blob(gcs_path)
            blob.upload_from_filename(local_file)
            uploaded_files.append(gcs_path)

    return uploaded_files

@app.route('/health')
def health():
    return 'OK', 200

@app.route('/')
def index():
    try:
        videos = [f.replace('videos/', '') for f in list_gcs_files('videos/')]
        hls_streams = list(set([f.split('/')[1] for f in list_gcs_files('hls/') if '/' in f]))
        return render_template('index.html', videos=videos, hls_streams=hls_streams, current_year=datetime.now().year)
    except Exception as e:
        flash(f'Error loading content: {str(e)}', 'danger')
        return render_template('index.html', videos=[], hls_streams=[], current_year=datetime.now().year)

@app.route('/upload', methods=['GET', 'POST'])
def upload():
    if request.method == 'POST':
        file = request.files.get('file')
        if not file or not allowed_file(file.filename):
            flash('No valid video selected', 'danger')
            return redirect(request.url)

        try:
            # Create temporary files
            with tempfile.TemporaryDirectory() as temp_dir:
                # Save uploaded file
                original_filename = secure_filename(file.filename)
                name_only, extension = os.path.splitext(original_filename)
                timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
                video_filename = f"{name_only}_{timestamp}{extension}"
                temp_video_path = os.path.join(temp_dir, video_filename)
                file.save(temp_video_path)

                # Upload original video to GCS
                video_gcs_path = f"videos/{video_filename}"
                upload_to_gcs(temp_video_path, video_gcs_path)

                # Create HLS version
                hls_folder_name = f"{name_only}_{timestamp}"
                hls_temp_dir = os.path.join(temp_dir, 'hls')
                make_hls(temp_video_path, hls_temp_dir)

                # Upload HLS files to GCS
                hls_gcs_prefix = f"hls/{hls_folder_name}"
                upload_hls_folder(hls_temp_dir, hls_gcs_prefix)

                # Sync to regional buckets
                sync_results = sync_to_regional_buckets()

                # Report sync results
                successful_syncs = sum(1 for r in sync_results.values() if r['status'] == 'success')
                total_regions = len(REGIONS)

                flash(f'Successfully uploaded and converted: {video_filename}', 'success')
                flash(f'Synced to {successful_syncs}/{total_regions} regional buckets', 'success')

                # Show any sync errors
                for region, result in sync_results.items():
                    if result['status'] == 'error':
                        flash(f'Sync error for {region}: {result["error"]}', 'warning')

        except Exception as e:
            flash(f'Error processing video: {str(e)}', 'danger')

        return redirect(url_for('index'))

    return render_template('upload.html')

@app.route('/delete/video/<filename>', methods=['POST'])
def delete_video(filename):
    try:
        gcs_path = f"videos/{filename}"

        # Delete from master bucket
        delete_gcs_file(gcs_path)

        # Delete from all regional buckets
        deleted_regions = []
        for region, regional_bucket in regional_buckets.items():
            try:
                delete_gcs_file(gcs_path, regional_bucket)
                deleted_regions.append(region)
            except Exception as e:
                flash(f'Error deleting from {region}: {str(e)}', 'warning')

        flash(f'Deleted video: {filename}', 'warning')
        flash(f'Removed from {len(deleted_regions)}/{len(REGIONS)} regional buckets', 'info')

    except Exception as e:
        flash(f'Error deleting video: {str(e)}', 'danger')
    return redirect(url_for('index'))

@app.route('/delete/hls/<folder>', methods=['POST'])
def delete_hls(folder):
    try:
        # Delete from master bucket
        blobs = master_bucket.list_blobs(prefix=f"hls/{folder}/")
        deleted_count = 0
        for blob in blobs:
            blob.delete()
            deleted_count += 1

        # Delete from all regional buckets
        deleted_regions = []
        for region, regional_bucket in regional_buckets.items():
            try:
                regional_blobs = regional_bucket.list_blobs(prefix=f"hls/{folder}/")
                for blob in regional_blobs:
                    blob.delete()
                deleted_regions.append(region)
            except Exception as e:
                flash(f'Error deleting HLS from {region}: {str(e)}', 'warning')

        flash(f'Deleted HLS stream: {folder} ({deleted_count} files)', 'warning')
        flash(f'Removed from {len(deleted_regions)}/{len(REGIONS)} regional buckets', 'info')

    except Exception as e:
        flash(f'Error deleting HLS stream: {str(e)}', 'danger')
    return redirect(url_for('index'))

@app.route('/sync', methods=['POST'])
def manual_sync():
    """Manual sync trigger"""
    try:
        sync_results = sync_to_regional_buckets()

        successful_syncs = 0
        total_synced = 0
        total_deleted = 0

        for region, result in sync_results.items():
            if result['status'] == 'success':
                successful_syncs += 1
                total_synced += result['synced']
                total_deleted += result['deleted']
            else:
                flash(f'Sync error for {region}: {result["error"]}', 'danger')

        flash(f'Sync completed: {successful_syncs}/{len(REGIONS)} regions', 'success')
        flash(f'Files synced: {total_synced}, Files deleted: {total_deleted}', 'info')

    except Exception as e:
        flash(f'Sync error: {str(e)}', 'danger')

    return redirect(url_for('index'))

if __name__ == '__main__':
    port = int(os.environ.get('PORT', 80))
    app.run(host='0.0.0.0', port=port, debug=False)