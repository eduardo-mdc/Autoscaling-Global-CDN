#!/usr/bin/env python3
"""
Test script for the Predictive Scaling System
Creates mock data and tests the RAG pipeline
"""

import json
import csv
from pathlib import Path
from datetime import datetime, timedelta
import random

def create_mock_training_data(output_dir="./ml_training_data"):
    """Create mock training data for testing"""
    output_dir = Path(output_dir)
    output_dir.mkdir(parents=True, exist_ok=True)

    print("📊 Creating mock training data...")

    # Mock load balancer logs
    lb_logs = []
    countries = ['singapore', 'thailand', 'germany', 'united states', 'france', 'japan', 'canada']

    for i in range(50):
        timestamp = (datetime.now() - timedelta(hours=random.randint(1, 24))).isoformat() + "Z"
        country = random.choice(countries)

        log = {
            "timestamp": timestamp,
            "httpRequest": {
                "requestMethod": random.choice(["GET", "POST"]),
                "status": random.choice([200, 200, 200, 404, 500]),
                "latency": f"{random.randint(50, 800)}ms",
                "remoteIp": f"203.{random.randint(1,255)}.{random.randint(1,255)}.{random.randint(1,255)}",
                "userAgent": "Mozilla/5.0 (compatible; test-client)"
            },
            "jsonPayload": {
                "country": country
            }
        }
        lb_logs.append(log)

    with open(output_dir / "load_balancer_access.json", 'w') as f:
        json.dump(lb_logs, f, indent=2)

    # Mock scaling events
    scaling_logs = []
    regions = ['europe-west2', 'us-south1', 'asia-southeast1']

    for i in range(10):
        timestamp = (datetime.now() - timedelta(hours=random.randint(1, 48))).isoformat() + "Z"
        region = random.choice(regions)

        log = {
            "timestamp": timestamp,
            "resource": {
                "labels": {
                    "cluster_name": f"uporto-cd-gke-{region}",
                    "location": region
                }
            },
            "jsonPayload": {
                "reason": random.choice([
                    "Scaled up due to CPU pressure",
                    "Scaled down due to low utilization",
                    "Scaled up due to high request rate",
                    "Node pool expanded"
                ]),
                "message": f"Cluster {region} scaling event"
            }
        }
        scaling_logs.append(log)

    with open(output_dir / "gke_cluster_autoscaling.json", 'w') as f:
        json.dump(scaling_logs, f, indent=2)

    # Mock pressure events
    pressure_logs = []
    for i in range(5):
        timestamp = (datetime.now() - timedelta(hours=random.randint(1, 12))).isoformat() + "Z"
        region = random.choice(regions)

        log = {
            "timestamp": timestamp,
            "resource": {
                "labels": {
                    "node_name": f"node-{region}-{random.randint(1,3)}",
                    "cluster_name": f"uporto-cd-gke-{region}"
                }
            },
            "jsonPayload": {
                "reason": random.choice([
                    "DiskPressure",
                    "MemoryPressure",
                    "NodeNotReady",
                    "FailedScheduling"
                ]),
                "message": "Resource pressure detected"
            }
        }
        pressure_logs.append(log)

    with open(output_dir / "gke_node_pressure.json", 'w') as f:
        json.dump(pressure_logs, f, indent=2)

    # Mock training features
    # Simulate different traffic patterns
    scenarios = [
        {  # High Asia traffic scenario
            'total_requests': 300,
            'asia_requests': 180,
            'europe_requests': 80,
            'americas_requests': 40,
            'asia_percentage': 60.0,
            'europe_percentage': 26.7,
            'americas_percentage': 13.3,
            'avg_backend_latency_ms': 450,
            'scaling_events_count': 3,
            'pressure_events_count': 2,
            'unique_countries': 8,
            'top_country': 'singapore',
            'top_country_requests': 120
        },
        {  # Balanced traffic scenario
            'total_requests': 150,
            'asia_requests': 45,
            'europe_requests': 60,
            'americas_requests': 45,
            'asia_percentage': 30.0,
            'europe_percentage': 40.0,
            'americas_percentage': 30.0,
            'avg_backend_latency_ms': 200,
            'scaling_events_count': 1,
            'pressure_events_count': 0,
            'unique_countries': 6,
            'top_country': 'germany',
            'top_country_requests': 35
        },
        {  # Low traffic scenario
            'total_requests': 50,
            'asia_requests': 5,
            'europe_requests': 30,
            'americas_requests': 15,
            'asia_percentage': 10.0,
            'europe_percentage': 60.0,
            'americas_percentage': 30.0,
            'avg_backend_latency_ms': 150,
            'scaling_events_count': 0,
            'pressure_events_count': 0,
            'unique_countries': 4,
            'top_country': 'united states',
            'top_country_requests': 15
        }
    ]

    # Add timestamp to each scenario
    for scenario in scenarios:
        scenario['timestamp'] = datetime.now().isoformat()

    # Write to CSV
    with open(output_dir / "training_features.csv", 'w', newline='') as f:
        writer = csv.DictWriter(f, fieldnames=scenarios[0].keys())
        writer.writeheader()
        for scenario in scenarios:
            writer.writerow(scenario)

    print(f"✅ Created mock training data in {output_dir}")
    print(f"  - {len(lb_logs)} load balancer logs")
    print(f"  - {len(scaling_logs)} scaling events")
    print(f"  - {len(pressure_logs)} pressure events")
    print(f"  - {len(scenarios)} training scenarios")

def test_ollama_connection():
    """Test connection to Ollama"""
    try:
        from langchain_community.llms import Ollama
        llm = Ollama(model="mistral", temperature=0.3)

        print("🔧 Testing Ollama connection...")
        response = llm.invoke("Respond with 'Connection successful'")

        if "successful" in response.lower():
            print("✅ Ollama connection successful")
            return True
        else:
            print(f"⚠️  Ollama responded but output unexpected: {response}")
            return False

    except Exception as e:
        print(f"❌ Ollama connection failed: {e}")
        print("Make sure Ollama is running and mistral model is installed")
        return False

def test_embeddings():
    """Test embedding generation"""
    try:
        from langchain_community.embeddings import HuggingFaceEmbeddings

        print("🔧 Testing embeddings...")
        embeddings = HuggingFaceEmbeddings(
            model_name="all-MiniLM-L6-v2",
            model_kwargs={'device': 'cpu'}
        )

        test_text = "This is a test document for embedding generation"
        embedding = embeddings.embed_query(test_text)

        print(f"✅ Generated embedding with {len(embedding)} dimensions")
        return True

    except Exception as e:
        print(f"❌ Embeddings test failed: {e}")
        return False

def main():
    """Run complete test suite"""
    print("🧪 Testing Predictive Scaling System")
    print("=" * 50)

    # Test 1: Create mock data
    create_mock_training_data()
    print()

    # Test 2: Test Ollama
    if not test_ollama_connection():
        print("\n❌ Ollama test failed - fix connection before proceeding")
        return 1
    print()

    # Test 3: Test embeddings
    if not test_embeddings():
        print("\n❌ Embeddings test failed - check dependencies")
        return 1
    print()

    # Test 4: Run actual predictive scaler
    try:
        print("🚀 Testing full predictive scaler...")

        # Import and run the scaler
        from predictive_scaler import InfrastructureScaler

        scaler = InfrastructureScaler(data_dir="./ml_training_data", model_name="mistral")
        decision = scaler.run_analysis()

        if decision:
            print("\n✅ Full system test successful!")
            print("🎯 Scaling recommendation generated")

            # Show quick summary
            print("\n📊 Test Results Summary:")
            print(f"  - Context documents used: {decision['context_docs']}")
            print(f"  - Current metrics processed: {len(decision['current_metrics'])} features")
            print("  - Recommendation: See detailed output above")

            return 0
        else:
            print("\n❌ Full system test failed")
            return 1

    except Exception as e:
        print(f"\n❌ Full system test failed: {e}")
        import traceback
        traceback.print_exc()
        return 1

if __name__ == "__main__":
    exit(main())