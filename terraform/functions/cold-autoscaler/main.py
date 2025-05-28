import os
import json
import logging
from google.cloud import container_v1
from google.cloud import monitoring_v3
from google.cloud import bigquery
import base64
from datetime import datetime, timedelta

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Environment variables #t
PROJECT_ID = os.environ.get('PROJECT_ID')
HOT_REGIONS = os.environ.get('HOT_REGIONS', '').split(',')
COLD_REGIONS = os.environ.get('COLD_REGIONS', '').split(',')
LOAD_BALANCER_NAME = os.environ.get('LOAD_BALANCER_NAME', 'uporto-cd-https-lb-rule')

# Scaling thresholds
ASIA_REQUESTS_THRESHOLD = int(os.environ.get('ASIA_REQUESTS_THRESHOLD', 50))  # requests/min from Asia
LATENCY_THRESHOLD_MS = int(os.environ.get('LATENCY_THRESHOLD_MS', 500))  # 500ms
GEOGRAPHIC_REGIONS = {
    'asia-southeast1': ['asia', 'australia', 'japan', 'singapore', 'thailand', 'vietnam', 'malaysia'],
    'us-south1': ['us', 'canada', 'mexico', 'brazil'],
    'europe-west2': ['europe', 'uk', 'germany', 'france', 'spain', 'italy']
}

# Initialize clients
container_client = container_v1.ClusterManagerClient()
monitoring_client = monitoring_v3.MetricServiceClient()
bigquery_client = bigquery.Client()

def scale_cold_cluster(event, context):
    """
    Main function to handle traffic-based cold cluster scaling
    """
    try:
        # Get traffic metrics from load balancer
        traffic_metrics = get_load_balancer_traffic()

        # Analyze geographic traffic patterns
        geographic_analysis = analyze_geographic_traffic(traffic_metrics)

        # Check latency metrics
        latency_metrics = get_latency_metrics()

        # Make scaling decision based on traffic and latency
        scale_decision = should_scale_based_on_traffic(geographic_analysis, latency_metrics)

        if scale_decision['should_scale']:
            logger.info(f"Traffic-based scaling decision: {scale_decision}")

            for region in scale_decision['target_regions']:
                scale_result = scale_cluster_nodes(
                    region=region,
                    target_nodes=scale_decision['target_nodes']
                )
                logger.info(f"Scaled {region}: {scale_result}")
        else:
            logger.info("No scaling action required based on traffic analysis")

        return {"status": "success", "action": scale_decision, "metrics": geographic_analysis}

    except Exception as e:
        logger.error(f"Error in traffic-based scaling: {str(e)}")
        return {"status": "error", "error": str(e)}

def get_load_balancer_traffic():
    """
    Get traffic metrics from Global Load Balancer
    """
    try:
        project_name = f"projects/{PROJECT_ID}"

        # Query for load balancer request count by client country
        interval = monitoring_v3.TimeInterval({
            "end_time": {"seconds": int(datetime.now().timestamp())},
            "start_time": {"seconds": int((datetime.now() - timedelta(minutes=10)).timestamp())}
        })

        # Load balancer request count by country
        request = monitoring_v3.ListTimeSeriesRequest(
            name=project_name,
            filter=(
                f'resource.type="https_lb_rule" AND '
                f'resource.labels.forwarding_rule_name="{LOAD_BALANCER_NAME}" AND '
                f'metric.type="loadbalancing.googleapis.com/https/request_count"'
            ),
            interval=interval,
            view=monitoring_v3.ListTimeSeriesRequest.TimeSeriesView.FULL
        )

        results = monitoring_client.list_time_series(request=request)

        traffic_data = {}
        for result in results:
            # Extract client country from labels if available
            client_country = result.metric.labels.get('client_country', 'unknown')
            client_region = result.metric.labels.get('client_region', 'unknown')

            # Sum request count
            total_requests = sum([point.value.int64_value for point in result.points])

            if client_country not in traffic_data:
                traffic_data[client_country] = {'requests': 0, 'region': client_region}

            traffic_data[client_country]['requests'] += total_requests

        return traffic_data

    except Exception as e:
        logger.error(f"Error getting load balancer traffic: {str(e)}")
        return {}

def get_latency_metrics():
    """
    Get latency metrics for different regions
    """
    try:
        project_name = f"projects/{PROJECT_ID}"

        interval = monitoring_v3.TimeInterval({
            "end_time": {"seconds": int(datetime.now().timestamp())},
            "start_time": {"seconds": int((datetime.now() - timedelta(minutes=5)).timestamp())}
        })

        # Get response latency by backend region
        request = monitoring_v3.ListTimeSeriesRequest(
            name=project_name,
            filter=(
                f'resource.type="https_lb_rule" AND '
                f'resource.labels.forwarding_rule_name="{LOAD_BALANCER_NAME}" AND '
                f'metric.type="loadbalancing.googleapis.com/https/total_latencies"'
            ),
            interval=interval,
            view=monitoring_v3.ListTimeSeriesRequest.TimeSeriesView.FULL
        )

        results = monitoring_client.list_time_series(request=request)

        latency_data = {}
        for result in results:
            backend_target_name = result.metric.labels.get('backend_target_name', 'unknown')

            # Calculate average latency
            latencies = [point.value.distribution_value.mean for point in result.points if point.value.distribution_value]
            avg_latency = sum(latencies) / len(latencies) if latencies else 0

            # Convert to milliseconds
            avg_latency_ms = avg_latency * 1000

            latency_data[backend_target_name] = avg_latency_ms

        return latency_data

    except Exception as e:
        logger.error(f"Error getting latency metrics: {str(e)}")
        return {}

def analyze_geographic_traffic(traffic_data):
    """
    Analyze traffic patterns by geographic region
    """
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

def should_scale_based_on_traffic(geographic_analysis, latency_metrics):
    """
    Determine if cold clusters should be scaled based on traffic patterns and latency
    """
    asia_requests = geographic_analysis['regional_traffic'].get('asia', 0)
    asia_percentage = geographic_analysis['regional_percentages'].get('asia', 0)
    total_requests = geographic_analysis['total_requests']

    # Get average latency to hot clusters
    hot_cluster_latency = 0
    hot_latency_count = 0

    for backend, latency in latency_metrics.items():
        # Check if this backend is from a hot region
        if any(hot_region in backend for hot_region in HOT_REGIONS):
            hot_cluster_latency += latency
            hot_latency_count += 1

    avg_hot_latency = hot_cluster_latency / hot_latency_count if hot_latency_count > 0 else 0

    logger.info(f"Traffic analysis: Asia requests={asia_requests}, Asia %={asia_percentage:.1f}, Avg latency={avg_hot_latency:.1f}ms")

    # Scale up cold clusters if:
    # 1. Significant traffic from Asia (>10% of total or >50 requests/10min)
    # 2. High latency to hot clusters (>500ms)
    # 3. Total traffic is high enough to justify cold cluster costs

    if (asia_requests >= ASIA_REQUESTS_THRESHOLD or asia_percentage >= 10) and total_requests >= 100:
        return {
            'should_scale': True,
            'reason': f'High Asia traffic: {asia_requests} requests ({asia_percentage:.1f}%)',
            'target_regions': ['asia-southeast1'],
            'target_nodes': 2 if asia_requests >= 200 else 1,
            'trigger': 'geographic_traffic'
        }

    elif avg_hot_latency >= LATENCY_THRESHOLD_MS and total_requests >= 50:
        return {
            'should_scale': True,
            'reason': f'High latency to hot clusters: {avg_hot_latency:.1f}ms',
            'target_regions': ['asia-southeast1'],
            'target_nodes': 1,
            'trigger': 'latency_threshold'
        }

    # Scale down if very low Asia traffic and low latency
    elif asia_requests < 10 and asia_percentage < 2 and avg_hot_latency < 200:
        return {
            'should_scale': True,
            'reason': f'Low Asia traffic: {asia_requests} requests ({asia_percentage:.1f}%), Low latency: {avg_hot_latency:.1f}ms',
            'target_regions': ['asia-southeast1'],
            'target_nodes': 0,
            'trigger': 'scale_down'
        }

    return {
        'should_scale': False,
        'reason': f'Traffic within normal range - Asia: {asia_requests} req ({asia_percentage:.1f}%), Latency: {avg_hot_latency:.1f}ms',
        'asia_traffic': asia_requests,
        'asia_percentage': asia_percentage,
        'avg_latency': avg_hot_latency
    }

def scale_cluster_nodes(region, target_nodes):
    """
    Actually scale a cluster's node pool to target number of nodes
    """
    try:
        cluster_name = f"uporto-cd-gke-{region}"
        node_pool_name = f"uporto-cd-node-pool-{region}-cold"

        # Get current node pool status first
        cluster_path = f"projects/{PROJECT_ID}/locations/{region}/clusters/{cluster_name}"
        try:
            cluster = container_client.get_cluster(name=cluster_path)
            logger.info(f"Cluster {cluster_name} status: {cluster.status}")
        except Exception as e:
            logger.error(f"Cannot access cluster {cluster_name}: {str(e)}")
            return {'status': 'error', 'error': f'Cluster not accessible: {str(e)}'}

        # Find the correct node pool
        target_pool = None
        for pool in cluster.node_pools:
            if pool.name.endswith('cold') or 'cold' in pool.name:
                target_pool = pool
                break

        if not target_pool:
            # Use the primary node pool if no cold pool found
            target_pool = cluster.node_pools[0] if cluster.node_pools else None
            logger.info(f"No cold node pool found, using primary: {target_pool.name if target_pool else 'None'}")

        if not target_pool:
            return {'status': 'error', 'error': 'No node pools found'}

        current_size = target_pool.initial_node_count
        logger.info(f"Current node pool size: {current_size}, target: {target_nodes}")

        # Skip if already at target size
        if current_size == target_nodes:
            return {
                'region': region,
                'target_nodes': target_nodes,
                'current_nodes': current_size,
                'status': 'no_change',
                'message': 'Already at target size'
            }

        # Create scaling request
        node_pool_path = f"{cluster_path}/nodePools/{target_pool.name}"

        request = container_v1.SetNodePoolSizeRequest(
            name=node_pool_path,
            node_count=target_nodes
        )

        # Execute scaling operation
        operation = container_client.set_node_pool_size(request=request)

        logger.info(f"✅ SCALING INITIATED: {region} from {current_size} to {target_nodes} nodes")
        logger.info(f"Operation ID: {operation.name}")

        return {
            'region': region,
            'cluster_name': cluster_name,
            'node_pool_name': target_pool.name,
            'current_nodes': current_size,
            'target_nodes': target_nodes,
            'operation_id': operation.name,
            'status': 'scaling_initiated',
            'scaling_type': 'traffic_based'
        }

    except Exception as e:
        logger.error(f"❌ ERROR scaling cluster in {region}: {str(e)}")
        return {
            'region': region,
            'target_nodes': target_nodes,
            'status': 'error',
            'error': str(e)
        }

# Add HTTP trigger support
def scale_cold_cluster_http(request):
    """
    HTTP Cloud Function entry point for manual/scheduled triggers
    """
    return scale_cold_cluster(None, None)

# Keep both entry points for flexibility
def scale_cold_cluster(event, context):
    """
    Main function - works with both Pub/Sub and HTTP triggers
    """
    try:
        logger.info("🚀 Starting traffic-based cold cluster scaling check...")

        # Get traffic metrics from load balancer
        traffic_metrics = get_load_balancer_traffic()
        logger.info(f"Retrieved traffic data for {len(traffic_metrics)} countries")

        # Analyze geographic traffic patterns
        geographic_analysis = analyze_geographic_traffic(traffic_metrics)

        # Check latency metrics
        latency_metrics = get_latency_metrics()
        logger.info(f"Retrieved latency data for {len(latency_metrics)} backends")

        # Make scaling decision based on traffic and latency
        scale_decision = should_scale_based_on_traffic(geographic_analysis, latency_metrics)

        if scale_decision['should_scale']:
            logger.info(f"🎯 SCALING DECISION: {scale_decision['reason']}")

            scaling_results = []
            for region in scale_decision['target_regions']:
                scale_result = scale_cluster_nodes(
                    region=region,
                    target_nodes=scale_decision['target_nodes']
                )
                scaling_results.append(scale_result)
                logger.info(f"Scaling result for {region}: {scale_result['status']}")

            return {
                "status": "success",
                "action": "scaled",
                "decision": scale_decision,
                "results": scaling_results,
                "metrics": geographic_analysis
            }
        else:
            logger.info(f"ℹ️  No scaling needed: {scale_decision['reason']}")

            return {
                "status": "success",
                "action": "no_scaling",
                "decision": scale_decision,
                "metrics": geographic_analysis
            }

    except Exception as e:
        logger.error(f"💥 FATAL ERROR in traffic-based scaling: {str(e)}")
        return {"status": "error", "error": str(e)}