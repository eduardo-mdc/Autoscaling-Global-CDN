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


def get_mock_traffic_data():
    """Mock traffic data for testing"""
    return {
        'singapore': {'requests': 60, 'region': 'asia'},
        'thailand': {'requests': 25, 'region': 'asia'},
        'united states': {'requests': 200, 'region': 'americas'},
        'canada': {'requests': 50, 'region': 'americas'},
        'germany': {'requests': 150, 'region': 'europe'},
        'france': {'requests': 80, 'region': 'europe'}
    }

def get_mock_latency_data():
    """Mock latency data for testing (in milliseconds)"""
    return {
        'hot_regions_avg_latency': 150,
        'europe-west2': 120,
        'us-south1': 180,
    }

def analyze_geographic_traffic(traffic_data):
    """Analyze traffic patterns by geographic region"""
    regional_traffic = {
        'asia': 0,
        'americas': 0,
        'europe': 0,
        'unknown': 0
    }

    asia_countries = [
        'china', 'japan', 'south korea', 'singapore', 'thailand', 'vietnam',
        'malaysia', 'indonesia', 'philippines', 'india', 'australia', 'new zealand'
    ]

    americas_countries = [
        'united states', 'canada', 'mexico', 'brazil', 'argentina', 'chile',
        'colombia', 'peru', 'venezuela'
    ]

    europe_countries = [
        'united kingdom', 'germany', 'france', 'spain', 'italy', 'netherlands',
        'belgium', 'switzerland', 'austria', 'poland', 'sweden', 'norway'
    ]

    total_requests = 0

    for country, data in traffic_data.items():
        requests = data['requests']
        total_requests += requests
        country_lower = country.lower()

        if any(asia_country in country_lower for asia_country in asia_countries):
            regional_traffic['asia'] += requests
        elif any(americas_country in country_lower for americas_country in americas_countries):
            regional_traffic['americas'] += requests
        elif any(europe_country in country_lower for europe_country in europe_countries):
            regional_traffic['europe'] += requests
        else:
            regional_traffic['unknown'] += requests

    # Calculate percentages
    regional_percentages = {}
    if total_requests > 0:
        for region, requests in regional_traffic.items():
            regional_percentages[region] = (requests / total_requests) * 100

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

        return {
            'should_scale': False,
            'reason': reason,
            'asia_traffic': asia_requests,
            'asia_percentage': asia_percentage,
            'hot_latency': hot_latency
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
            if 'cold' in pool_name.lower():
                node_pool_name = pool_name
                autoscaling = pool.get('autoscaling', {})
                current_min = autoscaling.get('minNodeCount', 0)
                current_max = autoscaling.get('maxNodeCount', 0)
                break

        if not node_pool_name and cluster_info['node_pools']:
            pool = cluster_info['node_pools'][0]
            node_pool_name = pool.get('name', '')
            autoscaling = pool.get('autoscaling', {})
            current_min = autoscaling.get('minNodeCount', 0)
            current_max = autoscaling.get('maxNodeCount', 0)

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

        if current_min == min_nodes and current_max == max_nodes:
            return {
                'region': region,
                'cluster_name': cluster_name,
                'node_pool_name': node_pool_name,
                'current_min': current_min,
                'current_max': current_max,
                'target_min': min_nodes,
                'target_max': max_nodes,
                'status': 'no_change',
                'message': 'Already at target autoscaling settings'
            }

        cmd = [
            'gcloud', 'container', 'clusters', 'update', cluster_name,
            '--enable-autoscaling',
            '--node-pool', node_pool_name,
            '--total-min-nodes', str(min_nodes),
            '--total-max-nodes', str(max_nodes),
            '--region', region,
            '--project', PROJECT_ID,
            '--quiet'
        ]

        logger.info(f"🔄 Updating TOTAL autoscaling for {cluster_name}/{node_pool_name}: total-min={min_nodes}, total-max={max_nodes}")

        result = subprocess.run(cmd, capture_output=True, text=True, check=True, timeout=180)

        if max_nodes > 0 and current_max == 0:
            logger.info("Cluster was at 0 max nodes, the autoscaler will now scale up based on demand")

            resize_cmd = [
                'gcloud', 'container', 'clusters', 'resize', cluster_name,
                '--node-pool', node_pool_name,
                '--num-nodes', '1',
                '--region', region,
                '--project', PROJECT_ID,
                '--quiet'
            ]

            logger.info(f"🔄 First resizing to 1 node: {' '.join(resize_cmd)}")
            subprocess.run(resize_cmd, capture_output=True, text=True, check=True, timeout=300)

        logger.info(f"✅ Successfully updated autoscaling for {region}")

        return {
            'region': region,
            'cluster_name': cluster_name,
            'node_pool_name': node_pool_name,
            'current_min': current_min,
            'current_max': current_max,
            'target_min': min_nodes,
            'target_max': max_nodes,
            'status': 'autoscaling_updated',
            'message': f'Autoscaling updated: min={min_nodes}, max={max_nodes}'
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