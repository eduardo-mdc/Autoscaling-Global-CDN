import os
import shutil
import uuid
import subprocess
from flask import (
    Flask, request, redirect, url_for,
    render_template, flash, send_from_directory, jsonify
)
from werkzeug.utils import secure_filename
import subprocess
import json
from datetime import datetime, timedelta, timezone
import geoip2.database
import struct
import socket
from pathlib import Path
import threading
import time
import atexit

# Import the cold autoscaler module
import cold_autoscaler

# -----------------------------------------------------------------------------
# Configuration
# -----------------------------------------------------------------------------
MOUNT_PATH = os.environ.get('VIDEOS_MOUNT_PATH', '/mnt/videos')
TMP_PATH   = os.environ.get('TMP_PATH', '/tmp')
ALLOWED_EXTS = {'mp4', 'mov', 'avi', 'mkv'}

app = Flask(__name__, template_folder='templates/')
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


# Add this global variable after the Flask app initialization
background_scheduler = None
autoscaler_enabled = True

# Add these functions before the routes section

def background_autoscaler_check():
    """Background function that runs autoscaler checks every 5 minutes"""
    global autoscaler_enabled

    while autoscaler_enabled:
        try:
            app.logger.info("🤖 Running automatic autoscaler check...")

            # Get traffic and latency data
            traffic_data = cold_autoscaler.get_mock_traffic_data()
            latency_data = cold_autoscaler.get_mock_latency_data()
            geographic_analysis = cold_autoscaler.analyze_geographic_traffic(traffic_data)
            scale_decision = cold_autoscaler.should_scale_based_on_traffic(geographic_analysis, latency_data)

            current_time = datetime.now().strftime('%Y-%m-%d %H:%M:%S')

            if scale_decision['should_scale']:
                app.logger.info(f"📈 Autoscaler decision: {scale_decision['reason']}")

                # Execute scaling
                for region in scale_decision['target_regions']:
                    app.logger.info(f"🔄 Auto-scaling {region} to {scale_decision['target_nodes']} nodes")
                    result = cold_autoscaler.scale_cluster_nodes(region, scale_decision['target_nodes'])

                    if result['status'] == 'error':
                        app.logger.error(f"❌ Failed to scale {region}: {result.get('error', 'Unknown error')}")
                    elif result['status'] == 'no_change':
                        app.logger.info(f"ℹ️  {region}: {result.get('message', 'No change needed')}")
                    else:
                        app.logger.info(f"✅ {region}: {result.get('message', 'Scaling completed')}")

            else:
                app.logger.info(f"📊 No scaling needed: {scale_decision['reason']}")

                # Check if cold regions need to be scaled to zero
                for region in cold_autoscaler.COLD_REGIONS:
                    cluster_info = cold_autoscaler.get_cluster_info(region)
                    if cluster_info and cluster_info['status'] == 'RUNNING':
                        # Check if cluster has nodes that could be scaled down
                        for pool in cluster_info.get('node_pools', []):
                            autoscaling = pool.get('autoscaling', {})
                            current_max = autoscaling.get('maxNodeCount', 0)

                            if current_max > 0:
                                app.logger.info(f"🔄 Setting {region} to scale-to-zero (current max: {current_max})")
                                result = cold_autoscaler.scale_cluster_nodes(region, 0)

                                if result['status'] == 'no_change':
                                    app.logger.info(f"ℹ️  {region}: Already at scale-to-zero")
                                elif result['status'] != 'error':
                                    app.logger.info(f"✅ {region}: Set to scale-to-zero")
                                else:
                                    app.logger.error(f"❌ Failed to scale down {region}")

                                break  # Only need to check first pool

            # Log summary
            app.logger.info(f"📋 Autoscaler check completed at {current_time}")
            app.logger.info(f"📊 Traffic: Asia {geographic_analysis['regional_percentages']['asia']:.1f}% ({geographic_analysis['regional_traffic']['asia']}), Total {geographic_analysis['total_requests']}")
            app.logger.info(f"⏱️  Latency: {latency_data['hot_regions_avg_latency']}ms avg")

        except Exception as e:
            app.logger.error(f"💥 Background autoscaler error: {str(e)}")

        # Wait 5 minutes (300 seconds) before next check
        time.sleep(300)

def start_background_autoscaler():
    """Start the background autoscaler thread"""
    global background_scheduler

    if background_scheduler is None or not background_scheduler.is_alive():
        background_scheduler = threading.Thread(target=background_autoscaler_check, daemon=True)
        background_scheduler.start()
        app.logger.info("🚀 Background autoscaler started (checks every 5 minutes)")

def stop_background_autoscaler():
    """Stop the background autoscaler"""
    global autoscaler_enabled, background_scheduler

    autoscaler_enabled = False
    if background_scheduler and background_scheduler.is_alive():
        app.logger.info("🛑 Stopping background autoscaler...")
        background_scheduler.join(timeout=5)

# -----------------------------------------------------------------------------
# Routes
# -----------------------------------------------------------------------------

@app.route('/health')
def health():
    """Health check endpoint for load balancer (bypasses IAP)"""
    return 'OK', 200

@app.route('/user-info')
def user_info():
    """Get IAP user information from headers"""
    user_email = request.headers.get('X-Goog-Authenticated-User-Email', '').replace('accounts.google.com:', '')
    user_id = request.headers.get('X-Goog-Authenticated-User-ID', '')

    return {
        'email': user_email,
        'id': user_id,
        'authenticated': bool(user_email),
        'iap_enabled': True
    }

# Optional: Add user context to your templates
@app.context_processor
def inject_user():
    """Make user info available in all templates"""
    user_email = request.headers.get('X-Goog-Authenticated-User-Email', '').replace('accounts.google.com:', '')
    return {
        'current_user': {
            'email': user_email,
            'authenticated': bool(user_email)
        }
    }

@app.route('/')
def index():
    videos_dir = os.path.join(MOUNT_PATH, 'videos')
    hls_dir = os.path.join(MOUNT_PATH, 'hls')
    os.makedirs(videos_dir, exist_ok=True)
    os.makedirs(hls_dir, exist_ok=True)
    videos = sorted(os.listdir(videos_dir)) if os.path.exists(videos_dir) else []
    hls_streams = sorted(os.listdir(hls_dir)) if os.path.exists(hls_dir) else []
    return render_template('index.html', videos=videos, hls_streams=hls_streams)

@app.route('/upload', methods=['GET', 'POST'])
def upload():
    if request.method == 'POST':
        file = request.files.get('file')
        if not file or not allowed_file(file.filename):
            flash('No valid video selected', 'danger')
            return redirect(request.url)

        videos_dir = os.path.join(MOUNT_PATH, 'videos')
        hls_dir = os.path.join(MOUNT_PATH, 'hls')
        os.makedirs(videos_dir, exist_ok=True)
        os.makedirs(hls_dir, exist_ok=True)

        original_filename = secure_filename(file.filename)
        name_only, extension = os.path.splitext(original_filename)
        timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
        original_filename = f"{name_only}_{timestamp}.{extension}"
        video_path = os.path.join(videos_dir, original_filename)
        file.save(video_path)

        stream_folder = f"{name_only}_{timestamp}"
        hls_output_dir = os.path.join(hls_dir, stream_folder)

        if os.path.isdir(hls_output_dir):
            shutil.rmtree(hls_output_dir)

        try:
            make_hls(video_path, hls_output_dir)

            try:
                result = subprocess.run(['/opt/content/scripts/sync-to-regions.sh'],
                                        check=True,
                                        capture_output=True,
                                        text=True)
                app.logger.info(f"Sync script output: {result.stdout}")
                if result.stderr:
                    app.logger.warning(f"Sync script stderr: {result.stderr}")
                flash(f'Uploaded, converted & propagated to regions: {original_filename}', 'success')
            except subprocess.SubprocessError as e:
                flash(f'Content uploaded but region sync failed: {e}', 'warning')

        except Exception as e:
            flash(f'Error transcoding: {e}', 'danger')
            if os.path.exists(hls_output_dir):
                shutil.rmtree(hls_output_dir)
        return redirect(url_for('index'))
    return render_template('upload.html')

@app.route('/delete/video/<filename>', methods=['POST'])
def delete_video(filename):
    target_video = os.path.join(MOUNT_PATH, 'videos', filename)
    filename_no_ext, _ = os.path.splitext(filename)
    target_hls = os.path.join(MOUNT_PATH, 'hls', filename_no_ext, 'playlist.m3u8')
    target_playlist0 = os.path.join(MOUNT_PATH, 'hls', filename_no_ext, 'playlist0.ts')
    target_playlist1 = os.path.join(MOUNT_PATH, 'hls', filename_no_ext, 'playlist1.ts')
    target_dir = os.path.join(MOUNT_PATH, 'hls', filename_no_ext)
    if os.path.isdir(target_dir):
        shutil.rmtree(target_dir)
        app.logger.info(f"Deleted HLS directory: {target_dir}")
    if os.path.isfile(target_playlist0):
        os.remove(target_playlist0)
        app.logger.info(f"Deleted HLS file: {target_playlist0}")
    if os.path.isfile(target_playlist1):
        os.remove(target_playlist1)
        app.logger.info(f"Deleted HLS file: {target_playlist1}")
    if os.path.isfile(target_hls):
        os.remove(target_hls)
        app.logger.info(f"Deleted HLS playlist: {target_hls}")
    if os.path.isfile(target_video):
        os.remove(target_video)

    try:
        result = subprocess.run(['/opt/content/scripts/sync-to-regions.sh'],
                                check=True,
                                capture_output=True,
                                text=True)
        app.logger.info(f"Sync script output: {result.stdout}")
        if result.stderr:
            app.logger.warning(f"Sync script stderr: {result.stderr}")
        flash(f'Deleted video: {filename}', 'warning')
    except subprocess.SubprocessError as e:
        app.logger.error(f"Sync script failed: {e}")

    else:
        flash('Video not found', 'danger')
    return redirect(url_for('index'))

@app.route('/delete/hls/<folder>', methods=['POST'])
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

# -----------------------------------------------------------------------------
# Cold Autoscaler Routes
# -----------------------------------------------------------------------------

@app.route('/autoscaler')
def autoscaler_dashboard():
    """Display autoscaler dashboard"""
    return render_template('autoscaler.html')

@app.route('/api/autoscaler/status')
def autoscaler_status():
    """Get current cluster status and scaling analysis"""
    try:
        # Get traffic and latency data (REAL DATA)
        traffic_data = cold_autoscaler.get_mock_traffic_data()  # This now calls real data
        latency_data = cold_autoscaler.get_real_latency_data()  # This gets real latency

        # Analyze traffic
        geographic_analysis = cold_autoscaler.analyze_geographic_traffic(traffic_data)

        # Get scaling decision
        scale_decision = cold_autoscaler.should_scale_based_on_traffic(geographic_analysis, latency_data)

        # Get cluster info for cold regions
        clusters_info = {}
        for region in cold_autoscaler.COLD_REGIONS:
            cluster_info = cold_autoscaler.get_cluster_info(region)
            clusters_info[region] = cluster_info

        return jsonify({
            'status': 'success',
            'traffic_analysis': geographic_analysis,
            'latency_data': latency_data,
            'scale_decision': scale_decision,
            'clusters': clusters_info,
            'data_source': 'real' if len(traffic_data) > 0 else 'mock',  # Indicate data source
            'thresholds': {
                'asia_requests_upper': cold_autoscaler.ASIA_REQUESTS_THRESHOLD_UPPER,
                'asia_percentage_upper': cold_autoscaler.ASIA_REQUESTS_PERCENTAGE_THRESHOLD_UPPER,
                'total_requests_upper': cold_autoscaler.MIN_TOTAL_REQUESTS_UPPER,
                'latency_upper_ms': cold_autoscaler.LATENCY_THRESHOLD_UPPER_MS,
                'asia_requests_lower': cold_autoscaler.ASIA_REQUESTS_THRESHOLD_LOWER,
                'asia_percentage_lower': cold_autoscaler.ASIA_REQUESTS_PERCENTAGE_THRESHOLD_LOWER,
                'latency_lower_ms': cold_autoscaler.LATENCY_THRESHOLD_LOWER_MS
            },
            'regions': {
                'hot': cold_autoscaler.HOT_REGIONS,
                'cold': cold_autoscaler.COLD_REGIONS
            }
        })
    except Exception as e:
        return jsonify({
            'status': 'error',
            'error': str(e)
        }), 500

@app.route('/api/autoscaler/scale', methods=['POST'])
def autoscaler_scale():
    """Trigger scaling operation with detailed command logging"""
    try:
        data = request.get_json()
        action = data.get('action')  # 'up', 'down', or 'auto'
        target_nodes = data.get('target_nodes', 1)

        results = []
        commands_executed = []

        if action == 'up':
            # Force scale up
            for region in cold_autoscaler.COLD_REGIONS:
                app.logger.info(f"Scaling UP {region} to {target_nodes} nodes...")
                result = cold_autoscaler.scale_cluster_nodes(region, target_nodes)

                # Add command details for logging
                result['commands'] = [
                    f"gcloud container clusters describe {cold_autoscaler.PROJECT_ID}-gke-{region} --region {region} --project {cold_autoscaler.PROJECT_ID} --format json",
                    f"gcloud container clusters update {cold_autoscaler.PROJECT_ID}-gke-{region} --enable-autoscaling --node-pool default-pool --total-min-nodes 0 --total-max-nodes {target_nodes} --region {region} --project {cold_autoscaler.PROJECT_ID} --quiet"
                ]

                if target_nodes > 0:
                    result['commands'].append(
                        f"gcloud container clusters resize {cold_autoscaler.PROJECT_ID}-gke-{region} --node-pool default-pool --num-nodes 1 --region {region} --project {cold_autoscaler.PROJECT_ID} --quiet"
                    )

                results.append(result)

        elif action == 'down':
            # Force scale down
            for region in cold_autoscaler.COLD_REGIONS:
                app.logger.info(f"Scaling DOWN {region} to 0 nodes...")
                result = cold_autoscaler.scale_cluster_nodes(region, 0)

                # Add command details for logging
                result['commands'] = [
                    f"gcloud container clusters describe {cold_autoscaler.PROJECT_ID}-gke-{region} --region {region} --project {cold_autoscaler.PROJECT_ID} --format json",
                    f"gcloud container clusters update {cold_autoscaler.PROJECT_ID}-gke-{region} --enable-autoscaling --node-pool default-pool --total-min-nodes 0 --total-max-nodes 0 --region {region} --project {cold_autoscaler.PROJECT_ID} --quiet"
                ]

                results.append(result)

        elif action == 'auto':
            # Automatic scaling based on traffic
            app.logger.info("Running automatic scaling analysis...")
            traffic_data = cold_autoscaler.get_mock_traffic_data()
            latency_data = cold_autoscaler.get_mock_latency_data()
            geographic_analysis = cold_autoscaler.analyze_geographic_traffic(traffic_data)
            scale_decision = cold_autoscaler.should_scale_based_on_traffic(geographic_analysis, latency_data)

            if scale_decision['should_scale']:
                for region in scale_decision['target_regions']:
                    app.logger.info(f"Auto-scaling {region} to {scale_decision['target_nodes']} nodes based on: {scale_decision['reason']}")
                    result = cold_autoscaler.scale_cluster_nodes(region, scale_decision['target_nodes'])

                    # Add analysis details
                    result['analysis'] = {
                        'reason': scale_decision['reason'],
                        'trigger': scale_decision['trigger'],
                        'traffic_data': geographic_analysis,
                        'latency_data': latency_data
                    }

                    # Add command details
                    result['commands'] = [
                        f"# Traffic Analysis: Asia={geographic_analysis['regional_traffic']['asia']} requests ({geographic_analysis['regional_percentages']['asia']:.1f}%), Total={geographic_analysis['total_requests']}",
                        f"# Latency: {latency_data['hot_regions_avg_latency']}ms to hot regions",
                        f"# Decision: {scale_decision['reason']}",
                        f"gcloud container clusters describe {cold_autoscaler.PROJECT_ID}-gke-{region} --region {region} --project {cold_autoscaler.PROJECT_ID} --format json",
                        f"gcloud container clusters update {cold_autoscaler.PROJECT_ID}-gke-{region} --enable-autoscaling --node-pool default-pool --total-min-nodes 0 --total-max-nodes {scale_decision['target_nodes']} --region {region} --project {cold_autoscaler.PROJECT_ID} --quiet"
                    ]

                    results.append(result)
            else:
                # Scale down to zero
                app.logger.info(f"Auto-scaling decision: {scale_decision['reason']}")
                for region in cold_autoscaler.COLD_REGIONS:
                    result = cold_autoscaler.scale_cluster_nodes(region, 0)

                    # Add analysis details
                    result['analysis'] = {
                        'reason': scale_decision['reason'],
                        'traffic_data': geographic_analysis,
                        'latency_data': latency_data
                    }

                    # Add command details
                    result['commands'] = [
                        f"# Traffic Analysis: Asia={geographic_analysis['regional_traffic']['asia']} requests ({geographic_analysis['regional_percentages']['asia']:.1f}%), Total={geographic_analysis['total_requests']}",
                        f"# Latency: {latency_data['hot_regions_avg_latency']}ms to hot regions",
                        f"# Decision: {scale_decision['reason']}",
                        f"gcloud container clusters update {cold_autoscaler.PROJECT_ID}-gke-{region} --enable-autoscaling --node-pool default-pool --total-min-nodes 0 --total-max-nodes 0 --region {region} --project {cold_autoscaler.PROJECT_ID} --quiet"
                    ]

                    results.append(result)

        return jsonify({
            'status': 'success',
            'action': action,
            'results': results,
            'timestamp': datetime.now().isoformat(),
            'summary': {
                'total_regions': len(results),
                'successful': len([r for r in results if r['status'] != 'error']),
                'failed': len([r for r in results if r['status'] == 'error'])
            }
        })

    except Exception as e:
        app.logger.error(f"Autoscaler error: {str(e)}")
        return jsonify({
            'status': 'error',
            'error': str(e),
            'timestamp': datetime.now().isoformat()
        }), 500

if __name__ == '__main__':
    start_background_autoscaler()
    port = int(os.environ.get('PORT', 80))
    app.run(host='0.0.0.0', port=port, debug=True)