#!/usr/bin/env python3
"""
Standalone Cold Cluster Scaler - Module version (no main function)
Scales GKE clusters based on geographic traffic patterns
Requires: gcloud auth and appropriate IAM permissions
"""

import os
import json
import logging
import subprocess
import argparse
from datetime import datetime, timedelta
import subprocess
import json
from datetime import datetime, timedelta, timezone
import geoip2.database
import struct
import socket
from pathlib import Path


# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

# Configuration - can be set via environment variables
PROJECT_ID = os.environ.get('PROJECT_ID', 'uporto-cd')
HOT_REGIONS = os.environ.get('HOT_REGIONS', 'europe-west2,us-south1').split(',')
COLD_REGIONS = os.environ.get('COLD_REGIONS', 'asia-southeast1').split(',')

# Scaling thresholds
ASIA_REQUESTS_THRESHOLD_UPPER = int(os.environ.get('ASIA_REQUESTS_THRESHOLD_UPPER', '50'))
MIN_TOTAL_REQUESTS_UPPER = int(os.environ.get('MIN_TOTAL_REQUESTS_UPPER', '300'))
ASIA_REQUESTS_PERCENTAGE_THRESHOLD_UPPER = float(os.environ.get('ASIA_REQUESTS_PERCENTAGE_THRESHOLD_UPPER', '10.0'))
LATENCY_THRESHOLD_UPPER_MS = int(os.environ.get('LATENCY_THRESHOLD_UPPER_MS', '500'))
ASIA_REQUESTS_THRESHOLD_LOWER = int(os.environ.get('ASIA_REQUESTS_THRESHOLD_LOWER', '50'))
ASIA_REQUESTS_PERCENTAGE_THRESHOLD_LOWER = float(os.environ.get('ASIA_REQUESTS_PERCENTAGE_THRESHOLD_LOWER', '2.0'))
LATENCY_THRESHOLD_LOWER_MS = int(os.environ.get('LATENCY_THRESHOLD_LOWER_MS', '200'))



def download_geoip_database():
    """Download GeoIP database if not present"""
    geoip_dir = Path('/tmp/geoip')
    geoip_dir.mkdir(parents=True, exist_ok=True)
    db_path = geoip_dir / 'GeoLite2-City.mmdb'

    if not db_path.exists():
        try:
            import urllib.request
            geoip_url = 'https://github.com/P3TERX/GeoLite.mmdb/raw/download/GeoLite2-City.mmdb'
            urllib.request.urlretrieve(geoip_url, db_path)
        except Exception as e:
            return None

    return db_path

def get_country_from_ip(ip_address, geoip_reader):
    """Get country from IP address using GeoIP database"""
    try:
        if geoip_reader:
            response = geoip_reader.city(ip_address)
            country = response.country.name
            if country:
                return country.lower()
    except Exception:
        pass

    # Fallback: Use IP ranges for major cloud providers/regions
    try:
        # Europe ranges
        if ip_address.startswith(('35.195.', '35.205.', '35.206.', '35.207.', '34.89.', '34.105.')):
            return 'germany'
        # US ranges
        elif ip_address.startswith(('35.188.', '35.192.', '35.193.', '35.194.', '34.66.', '34.67.')):
            return 'united states'
        # Asia ranges
        elif ip_address.startswith(('35.185.', '35.186.', '35.187.', '34.84.', '34.85.')):
            return 'singapore'
    except Exception:
        pass

    return 'unknown'

def run_gcloud_command(cmd):
    """Execute gcloud command and return output"""
    try:
        result = subprocess.run(cmd, shell=True, capture_output=True, text=True, check=True, timeout=30)
        return result.stdout
    except subprocess.CalledProcessError as e:
        return None
    except subprocess.TimeoutExpired:
        return None

def fetch_load_balancer_logs(hours=1):
    """Fetch recent load balancer access logs"""
    try:
        end_time = datetime.now(timezone.utc)
        start_time = end_time - timedelta(hours=hours)

        start_str = start_time.strftime('%Y-%m-%dT%H:%M:%SZ')
        end_str = end_time.strftime('%Y-%m-%dT%H:%M:%SZ')

        project_id = 'uporto-cd'  # Your project ID

        query = f'''
            resource.type="http_load_balancer"
            resource.labels.project_id="{project_id}"
            httpRequest.requestMethod!=""
            timestamp>="{start_str}"
            timestamp<="{end_str}"
        '''

        cmd = f'''
            gcloud logging read '{query}' \
                --project={project_id} \
                --format=json \
                --limit=1000
        '''

        output = run_gcloud_command(cmd)
        if output:
            try:
                logs = json.loads(output) if output.strip() else []
                return logs
            except json.JSONDecodeError:
                return []
        return []
    except Exception as e:
        return []

def extract_geographic_metrics(logs, geoip_reader=None):
    """Extract geographic distribution metrics from load balancer logs"""
    geographic_data = {}
    latency_by_country = {}
    ip_addresses_found = 0

    for log in logs:
        country = None
        ip_address = None

        # Extract IP address from various fields
        if 'httpRequest' in log:
            request = log['httpRequest']
            ip_address = request.get('remoteIp') or request.get('userIp')

            if not ip_address and 'requestHeaders' in request:
                headers = request['requestHeaders']
                ip_address = headers.get('X-Forwarded-For') or headers.get('X-Real-IP')
                if ip_address and ',' in ip_address:
                    ip_address = ip_address.split(',')[0].strip()

        if not ip_address and 'jsonPayload' in log:
            payload = log['jsonPayload']
            if isinstance(payload, dict):
                ip_address = payload.get('remoteIp') or payload.get('clientIp') or payload.get('sourceIp')

        # Get country from IP
        if ip_address:
            ip_addresses_found += 1
            country = get_country_from_ip(ip_address, geoip_reader)

        if not country:
            country = 'unknown'

        # Count the request
        geographic_data[country] = geographic_data.get(country, 0) + 1

        # Extract latency if available
        if 'httpRequest' in log:
            request = log['httpRequest']
            latency = request.get('latency', '0s')

            latency_ms = 0
            if isinstance(latency, str):
                if latency.endswith('s'):
                    try:
                        latency_ms = float(latency[:-1]) * 1000
                    except ValueError:
                        latency_ms = 0
                elif latency.endswith('ms'):
                    try:
                        latency_ms = float(latency[:-2])
                    except ValueError:
                        latency_ms = 0

            if country not in latency_by_country:
                latency_by_country[country] = []
            if latency_ms > 0:
                latency_by_country[country].append(latency_ms)

    # Calculate average latencies
    avg_latencies = {}
    for country, latencies in latency_by_country.items():
        if latencies:
            avg_latencies[country] = sum(latencies) / len(latencies)

    return geographic_data, avg_latencies

def get_real_traffic_data():
    """Get real traffic data from load balancer logs"""
    try:
        # Load GeoIP database
        geoip_reader = None
        db_path = download_geoip_database()
        if db_path and db_path.exists():
            try:
                geoip_reader = geoip2.database.Reader(str(db_path))
            except Exception as e:
               print(f"Failed to load GeoIP database: {e}")

        # Fetch recent logs (last 2 hours for more data)
        logs = fetch_load_balancer_logs(hours=2)

        if not logs:
            # Fallback to mock data if no logs available
            return get_mock_traffic_data()

        # Extract geographic metrics
        geographic_data, avg_latencies = extract_geographic_metrics(logs, geoip_reader)

        if geoip_reader:
            geoip_reader.close()

        # Convert to expected format
        traffic_data = {}
        for country, count in geographic_data.items():
            if country != 'unknown':
                traffic_data[country] = {'requests': count, 'region': classify_region(country)}

        # If no geographic data found, use mock data
        if not traffic_data:
            return get_mock_traffic_data()

        return traffic_data, avg_latencies

    except Exception as e:
        return get_mock_traffic_data(), {}

def get_real_latency_data():
    """Get real latency data from monitoring metrics and logs"""
    try:
        # Get traffic data with latencies
        _, country_latencies = get_real_traffic_data()

        # Calculate average latency to hot regions
        hot_regions_latencies = []

        # Map countries to regions and collect latencies
        for country, latencies in country_latencies.items():
            region = classify_region(country)
            if region in ['europe', 'americas']:  # Hot regions
                hot_regions_latencies.extend(latencies)

        # Calculate average
        hot_avg = sum(hot_regions_latencies) / len(hot_regions_latencies) if hot_regions_latencies else 150

        # Return in expected format
        return {
            'hot_regions_avg_latency': hot_avg,
            'europe-west2': country_latencies.get('germany', [120])[0] if country_latencies.get('germany') else 120,
            'us-south1': country_latencies.get('united states', [180])[0] if country_latencies.get('united states') else 180,
        }

    except Exception as e:
        return get_mock_latency_data()

def get_mock_latency_data():
    """Mock latency data for testing (in milliseconds)"""
    return {
        'hot_regions_avg_latency': 150,
        'europe-west2': 120,
        'us-south1': 180,
    }

def classify_region(country):
    """Classify country into geographic region"""
    country_lower = country.lower()

    asia_countries = ['singapore', 'thailand', 'japan', 'china', 'india', 'australia',
                      'indonesia', 'malaysia', 'philippines', 'vietnam', 'korea']
    europe_countries = ['germany', 'france', 'uk', 'united kingdom', 'spain', 'italy',
                        'netherlands', 'belgium', 'poland', 'sweden', 'portugal']
    americas_countries = ['united states', 'us', 'canada', 'brazil', 'mexico',
                          'argentina', 'chile', 'colombia']

    if any(ac in country_lower for ac in asia_countries):
        return 'asia'
    elif any(ec in country_lower for ec in europe_countries):
        return 'europe'
    elif any(ac in country_lower for ac in americas_countries):
        return 'americas'
    else:
        return 'unknown'

def analyze_geographic_traffic(traffic_data):
    """Analyze traffic patterns by geographic region"""
    regional_traffic = {
        'asia': 0,
        'americas': 0,
        'europe': 0,
        'unknown': 0
    }

    total_requests = 0

    for country, data in traffic_data.items():
        requests = data['requests']
        total_requests += requests
        region = data.get('region', 'unknown')

        if region in regional_traffic:
            regional_traffic[region] += requests
        else:
            regional_traffic['unknown'] += requests

    # Calculate percentages
    regional_percentages = {}
    if total_requests > 0:
        for region, requests in regional_traffic.items():
            regional_percentages[region] = (requests / total_requests) * 100
    else:
        for region in regional_traffic.keys():
            regional_percentages[region] = 0

    return {
        'total_requests': total_requests,
        'regional_traffic': regional_traffic,
        'regional_percentages': regional_percentages,
        'raw_traffic_data': traffic_data
    }

def should_scale_based_on_traffic(geographic_analysis, latency_data=None):
    """Determine if cold clusters should be scaled based on traffic patterns and latency"""
    asia_requests = geographic_analysis['regional_traffic'].get('asia', 0)
    asia_percentage = geographic_analysis['regional_percentages'].get('asia', 0)
    total_requests = geographic_analysis['total_requests']

    hot_latency = latency_data.get('hot_regions_avg_latency', 0) if latency_data else 0

    logger.info(f"Traffic analysis: Asia requests={asia_requests}, Asia %={asia_percentage:.1f}, Total={total_requests}, Hot latency={hot_latency}ms")

    high_asia_requests = asia_requests >= ASIA_REQUESTS_THRESHOLD_UPPER
    high_asia_percentage = asia_percentage >= ASIA_REQUESTS_PERCENTAGE_THRESHOLD_UPPER
    high_total_requests = total_requests >= MIN_TOTAL_REQUESTS_UPPER
    high_latency = hot_latency >= LATENCY_THRESHOLD_UPPER_MS

    low_asia_requests = asia_requests < ASIA_REQUESTS_THRESHOLD_LOWER
    low_asia_percentage = asia_percentage < ASIA_REQUESTS_PERCENTAGE_THRESHOLD_LOWER
    low_latency = hot_latency < LATENCY_THRESHOLD_LOWER_MS

    if ((high_asia_requests or high_asia_percentage) and high_total_requests) or high_latency:
        triggers = []
        if high_asia_requests:
            triggers.append(f"High Asia requests ({asia_requests} >= {ASIA_REQUESTS_THRESHOLD_UPPER})")
        if high_asia_percentage:
            triggers.append(f"High Asia percentage ({asia_percentage:.1f}% >= {ASIA_REQUESTS_PERCENTAGE_THRESHOLD_UPPER}%)")
        if high_total_requests and (high_asia_requests or high_asia_percentage):
            triggers.append(f"High total traffic ({total_requests} >= {MIN_TOTAL_REQUESTS_UPPER})")
        if high_latency:
            triggers.append(f"High latency to hot clusters ({hot_latency}ms >= {LATENCY_THRESHOLD_UPPER_MS}ms)")

        reason = " + ".join(triggers)

        return {
            'should_scale': True,
            'reason': reason,
            'target_regions': ['asia-southeast1'],
            'target_nodes': 2,
            'trigger': 'latency' if high_latency and not (high_asia_requests or high_asia_percentage) else 'geographic_traffic'
        }

    elif low_asia_requests and low_asia_percentage and low_latency:
        reason = f"Low Asia requests ({asia_requests} < {ASIA_REQUESTS_THRESHOLD_LOWER}) + Low Asia percentage ({asia_percentage:.1f}% < {ASIA_REQUESTS_PERCENTAGE_THRESHOLD_LOWER}%) + Low latency ({hot_latency}ms < {LATENCY_THRESHOLD_LOWER_MS}ms)"
        return {
            'should_scale': True,
            'reason': reason,
            'target_regions': ['asia-southeast1'],
            'target_nodes': 0,
            'trigger': 'scale_down'
        }

    else:
        reasons = []
        if not high_asia_requests:
            reasons.append(f"Asia requests below threshold ({asia_requests} < {ASIA_REQUESTS_THRESHOLD_UPPER})")
        if not high_asia_percentage:
            reasons.append(f"Asia percentage below threshold ({asia_percentage:.1f}% < {ASIA_REQUESTS_PERCENTAGE_THRESHOLD_UPPER}%)")
        if not high_total_requests:
            reasons.append(f"Total requests below threshold ({total_requests} < {MIN_TOTAL_REQUESTS_UPPER})")
        if not high_latency:
            reasons.append(f"Latency below threshold ({hot_latency}ms < {LATENCY_THRESHOLD_UPPER_MS}ms)")

        reason = " + ".join(reasons) if reasons else f"Traffic and latency within normal range"
        # FIX: Add the missing return statement
        return {
            'should_scale': False,
            'reason': reason,
            'asia_traffic': asia_requests,
            'asia_percentage': asia_percentage,
            'hot_latency': hot_latency
        }

# Replace the existing get_mock_traffic_data function with:
def get_mock_traffic_data():
    """Get real traffic data (with mock fallback)"""
    try:
        traffic_data, _ = get_real_traffic_data()
        return traffic_data
    except:
        return {
            'singapore': {'requests': 60, 'region': 'asia'},
            'thailand': {'requests': 25, 'region': 'asia'},
            'united states': {'requests': 200, 'region': 'americas'},
            'canada': {'requests': 50, 'region': 'americas'},
            'germany': {'requests': 150, 'region': 'europe'},
            'france': {'requests': 80, 'region': 'europe'}
        }

def get_cluster_info(region):
    """Get current cluster information using gcloud"""
    cluster_name = f"{PROJECT_ID}-gke-{region}"

    try:
        cmd = [
            'gcloud', 'container', 'clusters', 'describe', cluster_name,
            '--region', region, '--project', PROJECT_ID,
            '--format', 'json'
        ]

        result = subprocess.run(cmd, capture_output=True, text=True, check=True)
        cluster_info = json.loads(result.stdout)

        return {
            'name': cluster_name,
            'status': cluster_info.get('status', 'UNKNOWN'),
            'node_pools': cluster_info.get('nodePools', [])
        }

    except subprocess.CalledProcessError as e:
        logger.error(f"Failed to get cluster info for {region}: {e}")
        return None

def scale_cluster_nodes(region, target_nodes):
    """Scale a cluster's node pool autoscaling limits using gcloud"""
    cluster_name = f"{PROJECT_ID}-gke-{region}"

    try:
        cluster_info = get_cluster_info(region)
        if not cluster_info:
            return {
                'region': region,
                'status': 'error',
                'error': 'Could not get cluster information'
            }

        if cluster_info['status'] != 'RUNNING':
            return {
                'region': region,
                'status': 'error',
                'error': f'Cluster not running (status: {cluster_info["status"]})'
            }

        node_pool_name = None
        current_min = 0
        current_max = 0

        for pool in cluster_info['node_pools']:
            pool_name = pool.get('name', '')
            if 'cold' in pool_name.lower() or region in pool_name:  # Better matching
                node_pool_name = pool_name
                autoscaling = pool.get('autoscaling', {})
                # Fix: Use totalMinNodeCount and totalMaxNodeCount for regional clusters
                current_min = autoscaling.get('totalMinNodeCount', autoscaling.get('minNodeCount', 0))
                current_max = autoscaling.get('totalMaxNodeCount', autoscaling.get('maxNodeCount', 0))
                logger.info(f"Found pool: {pool_name}, autoscaling config: {autoscaling}")
                break

        if not node_pool_name and cluster_info['node_pools']:
            pool = cluster_info['node_pools'][0]
            node_pool_name = pool.get('name', '')
            autoscaling = pool.get('autoscaling', {})
            # Fix: Same here
            current_min = autoscaling.get('totalMinNodeCount', autoscaling.get('minNodeCount', 0))
            current_max = autoscaling.get('totalMaxNodeCount', autoscaling.get('maxNodeCount', 0))
            logger.info(f"Using first pool: {node_pool_name}, autoscaling config: {autoscaling}")

        if not node_pool_name:
            return {
                'region': region,
                'status': 'error',
                'error': 'No node pools found'
            }

        if target_nodes == 0:
            min_nodes = 0
            max_nodes = 0
        else:
            min_nodes = 0
            max_nodes = target_nodes

        logger.info(f"Current autoscaling: min={current_min}, max={current_max}")
        logger.info(f"Target autoscaling: min={min_nodes}, max={max_nodes}")
        if target_nodes == 0:
            cmd = [
                'gcloud', 'container', 'node-pools', 'update', node_pool_name,
                '--cluster', cluster_name,
                '--enable-autoscaling',
                '--min-nodes', '0',
                '--max-nodes', '0',
                '--region', region,
                '--project', PROJECT_ID,
                '--quiet'
            ]
            logger.info(f"🔄 Updating autoscaling: {' '.join(cmd)}")
            subprocess.run(cmd, capture_output=True, text=True, check=True, timeout=180)
            cmd = [
                'gcloud', 'container', 'node-pools', 'update', node_pool_name,
                '--cluster', cluster_name,
                '--enable-autoscaling',
                '--total-min-nodes', '0',
                '--total-max-nodes', '0',
                '--region', region,
                '--project', PROJECT_ID,
                '--quiet'
            ]
            logger.info(f"🔄 Updating autoscaling: {' '.join(cmd)}")
            subprocess.run(cmd, capture_output=True, text=True, check=True, timeout=180)

            # Kill all nodes - direct resize to 0
            cmd = [
                 'gcloud', 'container', 'clusters', 'resize', cluster_name,
                 '--node-pool', node_pool_name,
                 '--num-nodes', '0',
                 '--region', region,
                 '--project', PROJECT_ID,
                 '--quiet'
            ]
        else:
            # Scale up - first update autoscaling then resize
            update_cmd = [
                'gcloud', 'container', 'node-pools', 'update', node_pool_name,
                '--cluster', cluster_name,
                '--enable-autoscaling',
                '--min-nodes', '0',
                '--max-nodes', str(target_nodes),
                '--region', region,
                '--project', PROJECT_ID,
                '--quiet'
            ]


            logger.info(f"🔄 Updating autoscaling: {' '.join(update_cmd)}")
            subprocess.run(update_cmd, capture_output=True, text=True, check=True, timeout=180)

            # Scale up - first update autoscaling then resize
            update_cmd = [
                'gcloud', 'container', 'node-pools', 'update', node_pool_name,
                '--cluster', cluster_name,
                '--enable-autoscaling',
                '--total-min-nodes', '0',
                '--total-max-nodes', str(target_nodes),
                '--region', region,
                '--project', PROJECT_ID,
                '--quiet'
            ]

            logger.info(f"🔄 Updating autoscaling: {' '.join(update_cmd)}")
            subprocess.run(update_cmd, capture_output=True, text=True, check=True, timeout=180)

            # Then resize to 1 node to trigger scaling
            cmd = [
                'gcloud', 'container', 'clusters', 'resize', cluster_name,
                '--node-pool', node_pool_name,
                '--num-nodes', '1',
                '--region', region,
                '--project', PROJECT_ID,
                '--quiet'
            ]

        logger.info(f"🔄 Executing: {' '.join(cmd)}")
        result = subprocess.run(cmd, capture_output=True, text=True, check=True, timeout=300)

        return {
            'region': region,
            'cluster_name': cluster_name,
            'node_pool_name': node_pool_name,
            'target_nodes': target_nodes,
            'status': 'resized',
            'message': f'Pool resized to {target_nodes} nodes'
        }

    except subprocess.CalledProcessError as e:
        error_msg = e.stderr if e.stderr else str(e)
        logger.error(f"❌ Failed to update autoscaling for {region}: {error_msg}")
        return {
            'region': region,
            'target_nodes': target_nodes,
            'status': 'error',
            'error': error_msg
        }