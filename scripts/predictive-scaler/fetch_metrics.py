#!/usr/bin/env python3
"""
GCP Infrastructure Logs Collector for Adaptive Provisioning ML Model
Fetches relevant logs from GKE clusters, load balancers, and compute resources
Uses GeoIP database for geographic analysis
"""

import os
import json
import subprocess
import argparse
from datetime import datetime, timedelta, timezone
import csv
import gzip
import shutil
from pathlib import Path
import urllib.request
import tarfile
import socket
import struct
import sys
import geoip2.database

import sys
import subprocess

# Try to import geoip2, install if not available
try:
    import geoip2.database
except ImportError:
    print("Installing geoip2 library...")
    subprocess.check_call([sys.executable, "-m", "pip", "install", "geoip2"])
    import geoip2.database

# Configuration
PROJECT_ID = os.environ.get('PROJECT_ID', 'uporto-cd')
REGIONS = ['europe-west2', 'us-south1', 'asia-southeast1']
OUTPUT_DIR = Path('ml_training_data')
GEOIP_DIR = Path('../geoip_data')
GEOIP_DB_URL = 'https://github.com/P3TERX/GeoLite.mmdb/raw/download/GeoLite2-City.mmdb'

# Log queries for different components
LOG_QUERIES = {
    'gke_cluster_autoscaling': '''
        resource.type="k8s_cluster"
        jsonPayload.reason=~"Scaled.*"
        severity>=INFO
    ''',

    'gke_node_pressure': '''
        resource.type="k8s_node"
        jsonPayload.reason=~"NodeNotReady|NodePressure|DiskPressure|MemoryPressure"
    ''',

    'pod_scheduling_failures': '''
        resource.type="k8s_pod"
        jsonPayload.reason=~"FailedScheduling|Evicted"
    ''',

    'load_balancer_metrics': '''
        resource.type="http_load_balancer"
        httpRequest.status>=200
    ''',

    'backend_service_requests': '''
        resource.type="gce_backend_service"
        severity>=INFO
    ''',

    'gke_workload_logs': '''
        resource.type="k8s_container"
        resource.labels.namespace_name="streaming"
        severity>=INFO
    ''',

    'cluster_events': '''
        resource.type="k8s_cluster"
        protoPayload.methodName=~".*cluster.*"
    ''',

    'node_pool_operations': '''
        protoPayload.methodName=~".*NodePool.*"
        severity>=INFO
    '''
}

def download_geoip_database():
    """Download GeoIP database if not present"""
    GEOIP_DIR.mkdir(parents=True, exist_ok=True)
    db_path = GEOIP_DIR / 'GeoLite2-City.mmdb'

    if not db_path.exists():
        print("📥 Downloading GeoIP database...")
        try:
            urllib.request.urlretrieve(GEOIP_DB_URL, db_path)
            print(f"✅ Downloaded GeoIP database to {db_path}")
        except Exception as e:
            print(f"❌ Failed to download GeoIP database: {e}")
            print("  Using fallback IP ranges for region detection")
            return None
    else:
        print(f"✅ Using existing GeoIP database: {db_path}")

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
        # Convert IP to integer for range comparison
        ip_int = struct.unpack("!I", socket.inet_aton(ip_address))[0]

        # Common IP ranges by region (simplified)
        # Europe ranges
        if ip_address.startswith(('35.195.', '35.205.', '35.206.', '35.207.', '34.89.', '34.105.')):
            return 'germany'  # europe-west
        # US ranges
        elif ip_address.startswith(('35.188.', '35.192.', '35.193.', '35.194.', '34.66.', '34.67.')):
            return 'united states'
        # Asia ranges
        elif ip_address.startswith(('35.185.', '35.186.', '35.187.', '34.84.', '34.85.')):
            return 'singapore'  # asia-southeast
    except Exception:
        pass

    return 'unknown'

def run_gcloud_command(cmd):
    """Execute gcloud command and return output"""
    try:
        result = subprocess.run(cmd, shell=True, capture_output=True, text=True, check=True)
        return result.stdout
    except subprocess.CalledProcessError as e:
        print(f"Error executing command: {e}")
        print(f"stderr: {e.stderr}")
        return None

def fetch_monitoring_metrics(metric_type, start_time, end_time):
    """Fetch monitoring metrics using gcloud"""
    print(f"\n📊 Fetching monitoring metrics: {metric_type}")

    # Format timestamps for monitoring API
    start_str = start_time.strftime('%Y-%m-%dT%H:%M:%S.%fZ')
    end_str = end_time.strftime('%Y-%m-%dT%H:%M:%S.%fZ')

    cmd = f'''
        gcloud monitoring time-series list \
            --project={PROJECT_ID} \
            --filter='metric.type="{metric_type}"' \
            --interval-start-time="{start_str}" \
            --interval-end-time="{end_str}" \
            --format=json
    '''

    output = run_gcloud_command(cmd)
    if output:
        try:
            metrics = json.loads(output) if output.strip() else []
            print(f"✅ Fetched {len(metrics)} metric time series")
            return metrics
        except json.JSONDecodeError:
            print(f"⚠️  Could not parse metrics JSON")
            return []
    return []

def fetch_load_balancer_logs(start_time, end_time):
    """Fetch load balancer access logs specifically"""
    print(f"\n📊 Fetching load balancer access logs...")

    # Format timestamps
    start_str = start_time.strftime('%Y-%m-%dT%H:%M:%SZ')
    end_str = end_time.strftime('%Y-%m-%dT%H:%M:%SZ')

    # More specific query for HTTP load balancer logs
    query = f'''
        resource.type="http_load_balancer"
        resource.labels.project_id="{PROJECT_ID}"
        httpRequest.requestMethod!=""
        timestamp>="{start_str}"
        timestamp<="{end_str}"
    '''

    cmd = f'''
        gcloud logging read '{query}' \
            --project={PROJECT_ID} \
            --format=json \
            --limit=5000
    '''

    output = run_gcloud_command(cmd)
    if output:
        try:
            logs = json.loads(output) if output.strip() else []
            print(f"✅ Fetched {len(logs)} load balancer logs")
            return logs
        except json.JSONDecodeError:
            print(f"⚠️  Could not parse JSON output")
            return []
    return []

def fetch_logs(query_name, query, start_time, end_time, output_file):
    """Fetch logs using gcloud logging read"""
    print(f"\n📊 Fetching {query_name} logs...")

    # Format timestamps
    start_str = start_time.strftime('%Y-%m-%dT%H:%M:%SZ')
    end_str = end_time.strftime('%Y-%m-%dT%H:%M:%SZ')

    # Build query with timestamp
    time_filter = f'timestamp>="{start_str}" AND timestamp<="{end_str}"'
    full_query = f'{query} AND {time_filter}'

    # Build gcloud command
    cmd = f'''
        gcloud logging read '{full_query}' \
            --project={PROJECT_ID} \
            --format=json \
            --order=asc \
            --limit=1000
    '''

    output = run_gcloud_command(cmd)
    if output:
        with open(output_file, 'w') as f:
            f.write(output)

        # Parse and count entries
        try:
            logs = json.loads(output) if output.strip() else []
            print(f"✅ Fetched {len(logs)} log entries")
            return logs
        except json.JSONDecodeError:
            print(f"⚠️  Could not parse JSON output")
            return []
    return []

def extract_geographic_metrics(logs, geoip_reader=None):
    """Extract geographic distribution metrics from load balancer logs using GeoIP"""
    geographic_data = {}
    latency_by_country = {}
    ip_addresses_found = 0

    print(f"  Processing {len(logs)} logs for geographic data...")

    for log in logs:
        country = None
        ip_address = None

        # Extract IP address from various fields
        if 'httpRequest' in log:
            request = log['httpRequest']

            # Try to get IP address
            ip_address = request.get('remoteIp') or request.get('userIp')

            # Sometimes IP is in headers
            if not ip_address and 'requestHeaders' in request:
                headers = request['requestHeaders']
                ip_address = headers.get('X-Forwarded-For') or headers.get('X-Real-IP')
                # X-Forwarded-For might have multiple IPs, take the first
                if ip_address and ',' in ip_address:
                    ip_address = ip_address.split(',')[0].strip()

        # Try jsonPayload for IP
        if not ip_address and 'jsonPayload' in log:
            payload = log['jsonPayload']
            if isinstance(payload, dict):
                ip_address = payload.get('remoteIp') or payload.get('clientIp') or payload.get('sourceIp')

        # Get country from IP
        if ip_address:
            ip_addresses_found += 1
            country = get_country_from_ip(ip_address, geoip_reader)

        # If still no country, check if it's already in the log
        if not country and 'httpRequest' in log:
            request = log['httpRequest']
            if 'remoteLocation' in request:
                country = request['remoteLocation'].get('country', None)
                if country:
                    country = country.lower()

        # Default to unknown
        if not country:
            country = 'unknown'

        # Count the request
        geographic_data[country] = geographic_data.get(country, 0) + 1

        # Extract latency if available
        if 'httpRequest' in log:
            request = log['httpRequest']
            latency = request.get('latency', '0s')

            # Parse latency to milliseconds
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
            elif isinstance(latency, (int, float)):
                latency_ms = float(latency)

            # Track latency by country
            if country not in latency_by_country:
                latency_by_country[country] = []
            if latency_ms > 0:
                latency_by_country[country].append(latency_ms)

    # Print what we found
    print(f"  Found {ip_addresses_found} IP addresses in logs")
    if geographic_data:
        print(f"  Found requests from {len(geographic_data)} countries/regions")
        top_countries = sorted(geographic_data.items(), key=lambda x: x[1], reverse=True)[:5]
        for country, count in top_countries:
            print(f"    - {country}: {count} requests")
    else:
        print("  No geographic data found in logs")

    # Calculate average latencies
    avg_latencies = {}
    for country, latencies in latency_by_country.items():
        if latencies:
            avg_latencies[country] = sum(latencies) / len(latencies)

    return geographic_data, avg_latencies

def extract_scaling_events(logs):
    """Extract cluster scaling events"""
    scaling_events = []

    for log in logs:
        if 'jsonPayload' in log:
            payload = log['jsonPayload']
            if 'reason' in payload and 'Scaled' in payload.get('reason', ''):
                event = {
                    'timestamp': log.get('timestamp'),
                    'cluster': log.get('resource', {}).get('labels', {}).get('cluster_name'),
                    'location': log.get('resource', {}).get('labels', {}).get('location'),
                    'reason': payload.get('reason'),
                    'message': payload.get('message', '')
                }
                scaling_events.append(event)

    return scaling_events

def extract_resource_pressure(logs):
    """Extract resource pressure events"""
    pressure_events = []

    for log in logs:
        if 'jsonPayload' in log:
            payload = log['jsonPayload']
            reason = payload.get('reason', '')
            if any(pressure in reason for pressure in ['Pressure', 'NotReady', 'Evicted']):
                event = {
                    'timestamp': log.get('timestamp'),
                    'node': log.get('resource', {}).get('labels', {}).get('node_name'),
                    'cluster': log.get('resource', {}).get('labels', {}).get('cluster_name'),
                    'reason': reason,
                    'message': payload.get('message', '')
                }
                pressure_events.append(event)

    return pressure_events

def create_training_dataset(all_logs, monitoring_metrics, output_dir, geoip_reader=None):
    """Create structured training dataset from logs and metrics"""
    dataset = []

    # Extract metrics from different log types
    lb_logs = all_logs.get('load_balancer_access', []) + all_logs.get('load_balancer_metrics', [])
    geographic_data, latency_by_country = extract_geographic_metrics(lb_logs, geoip_reader)

    scaling_events = extract_scaling_events(all_logs.get('gke_cluster_autoscaling', []))
    pressure_events = extract_resource_pressure(all_logs.get('gke_node_pressure', []))

    # Create time-series dataset
    print("\n📈 Creating training dataset...")

    # Geographic distribution features
    total_requests = sum(geographic_data.values()) if geographic_data else 0

    # Regional distribution (with more countries)
    asia_countries = ['singapore', 'thailand', 'japan', 'china', 'india', 'australia', 'indonesia', 'malaysia', 'philippines', 'vietnam', 'korea']
    europe_countries = ['germany', 'france', 'uk', 'united kingdom', 'spain', 'italy', 'netherlands', 'belgium', 'poland', 'sweden', 'portugal']
    americas_countries = ['united states', 'us', 'canada', 'brazil', 'mexico', 'argentina', 'chile', 'colombia']

    asia_requests = sum(count for country, count in geographic_data.items()
                        if any(ac in country.lower() for ac in asia_countries))
    europe_requests = sum(count for country, count in geographic_data.items()
                          if any(ec in country.lower() for ec in europe_countries))
    americas_requests = sum(count for country, count in geographic_data.items()
                            if any(ac in country.lower() for ac in americas_countries))

    # Extract average latencies from monitoring metrics
    avg_backend_latency = 0
    if monitoring_metrics.get('backend_latencies'):
        latency_values = []
        for series in monitoring_metrics['backend_latencies']:
            for point in series.get('points', []):
                value = point.get('value', {}).get('doubleValue', 0)
                if value > 0:
                    latency_values.append(value)
        if latency_values:
            avg_backend_latency = sum(latency_values) / len(latency_values)

    # Create feature vector
    features = {
        'timestamp': datetime.now(timezone.utc).isoformat(),
        'total_requests': total_requests,
        'asia_requests': asia_requests,
        'europe_requests': europe_requests,
        'americas_requests': americas_requests,
        'asia_percentage': (asia_requests / total_requests * 100) if total_requests > 0 else 0,
        'europe_percentage': (europe_requests / total_requests * 100) if total_requests > 0 else 0,
        'americas_percentage': (americas_requests / total_requests * 100) if total_requests > 0 else 0,
        'avg_backend_latency_ms': avg_backend_latency * 1000,  # Convert to ms
        'scaling_events_count': len(scaling_events),
        'pressure_events_count': len(pressure_events),
        'unique_countries': len(geographic_data),
        'top_country': max(geographic_data.items(), key=lambda x: x[1])[0] if geographic_data else 'unknown',
        'top_country_requests': max(geographic_data.values()) if geographic_data else 0,
        'unknown_region_requests': geographic_data.get('unknown', 0)
    }

    # Save as CSV for training
    csv_file = output_dir / 'training_features.csv'
    with open(csv_file, 'w', newline='') as f:
        writer = csv.DictWriter(f, fieldnames=features.keys())
        writer.writeheader()
        writer.writerow(features)

    print(f"✅ Created training dataset: {csv_file}")

    # Save detailed logs for analysis
    detailed_file = output_dir / 'detailed_analysis.json'
    with open(detailed_file, 'w') as f:
        json.dump({
            'geographic_distribution': geographic_data,
            'latency_by_country': latency_by_country,
            'scaling_events': scaling_events,
            'pressure_events': pressure_events,
            'summary': features
        }, f, indent=2)

    print(f"✅ Created detailed analysis: {detailed_file}")

    return features

def main():
    parser = argparse.ArgumentParser(description='Collect GCP logs for ML training')
    parser.add_argument('--hours', type=int, default=24,
                        help='Number of hours of logs to collect')
    parser.add_argument('--output-dir', type=str, default='./ml_training_data',
                        help='Output directory for logs')

    args = parser.parse_args()

    # Create output directory
    output_dir = Path(args.output_dir)
    output_dir.mkdir(parents=True, exist_ok=True)

    # Download or load GeoIP database
    geoip_reader = None
    db_path = download_geoip_database()
    if db_path and db_path.exists():
        try:
            geoip_reader = geoip2.database.Reader(str(db_path))
            print("✅ Loaded GeoIP database")
        except Exception as e:
            print(f"⚠️  Failed to load GeoIP database: {e}")

    # Calculate time range
    end_time = datetime.now(timezone.utc)
    start_time = end_time - timedelta(hours=args.hours)

    print(f"🚀 GCP Logs Collector for ML Training")
    print(f"Project: {PROJECT_ID}")
    print(f"Time range: {start_time} to {end_time}")
    print(f"Output directory: {output_dir}")

    # Collect all logs
    all_logs = {}

    for query_name, query in LOG_QUERIES.items():
        output_file = output_dir / f"{query_name}.json"
        logs = fetch_logs(query_name, query, start_time, end_time, output_file)
        all_logs[query_name] = logs

    # Fetch load balancer logs separately for better geographic data
    lb_logs = fetch_load_balancer_logs(start_time, end_time)
    if lb_logs:
        all_logs['load_balancer_access'] = lb_logs
        lb_file = output_dir / "load_balancer_access.json"
        with open(lb_file, 'w') as f:
            json.dump(lb_logs, f, indent=2)

    # Fetch monitoring metrics
    monitoring_metrics = {
        'cpu_utilization': fetch_monitoring_metrics(
            "compute.googleapis.com/instance/cpu/utilization",
            start_time, end_time
        ),
        'backend_latencies': fetch_monitoring_metrics(
            "loadbalancing.googleapis.com/https/backend_latencies",
            start_time, end_time
        )
    }

    # Save a sample of logs to understand structure
    if lb_logs:
        sample_file = output_dir / "sample_lb_logs.json"
        with open(sample_file, 'w') as f:
            # Save first 10 logs as a sample
            json.dump(lb_logs[:10], f, indent=2)
        print(f"\n📋 Saved sample load balancer logs to: {sample_file}")
        print("  Review this file to understand log structure")

    # Create training dataset
    features = create_training_dataset(all_logs, monitoring_metrics, output_dir, geoip_reader)

    # Close GeoIP reader
    if geoip_reader:
        geoip_reader.close()

    # Skip compression - keep full JSON files
    print("\n📊 Keeping full JSON files (no compression)")

    print("\n✨ Log collection complete!")
    print(f"📊 Summary:")
    print(f"  - Total requests: {features['total_requests']}")
    print(f"  - Geographic distribution: Asia {features['asia_percentage']:.1f}% ({features['asia_requests']}), Europe {features['europe_percentage']:.1f}% ({features['europe_requests']}), Americas {features['americas_percentage']:.1f}% ({features['americas_requests']})")
    print(f"  - Unknown region requests: {features['unknown_region_requests']}")
    print(f"  - Scaling events: {features['scaling_events_count']}")
    print(f"  - Pressure events: {features['pressure_events_count']}")
    print(f"  - Unique countries: {features['unique_countries']}")
    if features['top_country'] != 'unknown':
        print(f"  - Top country: {features['top_country']} ({features['top_country_requests']} requests)")

    print(f"\n💡 To understand why geographic data might be missing:")
    print(f"  1. Check sample_lb_logs.json to see the actual log structure")
    print(f"  2. Load balancer logs might not include country data by default")
    print(f"  3. You may need to enable additional logging features in GCP")

    # Create Ollama training prompt
    ollama_prompt = f"""
Based on the following metrics, determine optimal cluster provisioning:
- Total requests: {features['total_requests']}
- Asia traffic: {features['asia_percentage']:.1f}% ({features['asia_requests']} requests)
- Europe traffic: {features['europe_percentage']:.1f}% ({features['europe_requests']} requests)
- Americas traffic: {features['americas_percentage']:.1f}% ({features['americas_requests']} requests)
- Average backend latency: {features['avg_backend_latency_ms']:.0f}ms
- Resource pressure events: {features['pressure_events_count']}
- Scaling events: {features['scaling_events_count']}
- Geographic diversity: {features['unique_countries']} countries
- Top traffic source: {features['top_country']} ({features['top_country_requests']} requests)

Recommend: Should we scale up Asia cluster? Add new regions? Increase node counts?
"""

    prompt_file = output_dir / 'ollama_training_prompt.txt'
    with open(prompt_file, 'w') as f:
        f.write(ollama_prompt)

    print(f"\n📝 Created Ollama training prompt: {prompt_file}")

if __name__ == "__main__":
    main()