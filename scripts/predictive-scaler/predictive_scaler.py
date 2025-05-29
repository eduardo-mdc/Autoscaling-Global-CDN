#!/usr/bin/env python3
"""
Predictive Scaling System using RAG with Ollama
Analyzes GCP logs and metrics to make intelligent scaling decisions
"""

import json
import os
import sys
import argparse
from pathlib import Path
from datetime import datetime, timedelta
import pandas as pd
import numpy as np

# LangChain imports
from langchain_community.embeddings import HuggingFaceEmbeddings
from langchain_community.vectorstores import Chroma
from langchain.text_splitter import RecursiveCharacterTextSplitter
from langchain_community.llms import Ollama
from langchain.docstore.document import Document
from langchain.schema import BaseRetriever

class InfrastructureScaler:
    def __init__(self, data_dir="./ml_training_data", model_name="mistral"):
        self.data_dir = Path(data_dir)
        self.model_name = model_name
        self.embeddings = None
        self.vectorstore = None
        self.llm = None
        self.setup_components()

    def setup_components(self):
        """Initialize LLM and embedding components"""
        print("🔧 Setting up AI components...")

        # Use sentence-transformers for better embeddings
        self.embeddings = HuggingFaceEmbeddings(
            model_name="all-MiniLM-L6-v2",
            model_kwargs={'device': 'cpu'}  # Use CPU for AMD compatibility
        )

        # Initialize Ollama
        try:
            self.llm = Ollama(model=self.model_name, temperature=0.3)
            # Test connection
            test_response = self.llm.invoke("Test connection")
            print(f"✅ Connected to Ollama model: {self.model_name}")
        except Exception as e:
            print(f"❌ Failed to connect to Ollama: {e}")
            print("Make sure Ollama is running and the model is installed")
            sys.exit(1)

    def load_training_data(self):
        """Load and process logs into documents"""
        print("📊 Loading training data...")
        documents = []

        # Load different log types
        log_files = {
            'load_balancer_access': 'Load Balancer Access',
            'gke_cluster_autoscaling': 'GKE Autoscaling Events',
            'gke_node_pressure': 'Node Pressure Events',
            'backend_service_requests': 'Backend Service Requests',
            'cluster_events': 'Cluster Events'
        }

        for log_file, log_type in log_files.items():
            file_path = self.data_dir / f"{log_file}.json"
            if file_path.exists():
                try:
                    with open(file_path, 'r') as f:
                        logs = json.load(f)

                    print(f"  Loading {len(logs)} entries from {log_type}")

                    for log in logs:
                        doc_text = self.convert_log_to_text(log, log_type)
                        if doc_text:
                            documents.append(Document(
                                page_content=doc_text,
                                metadata={
                                    'source': log_type,
                                    'timestamp': log.get('timestamp', ''),
                                    'log_file': log_file
                                }
                            ))

                except Exception as e:
                    print(f"  ⚠️  Failed to load {log_file}: {e}")

        # Load training features
        features_file = self.data_dir / 'training_features.csv'
        if features_file.exists():
            try:
                df = pd.read_csv(features_file)
                for _, row in df.iterrows():
                    doc_text = self.convert_features_to_text(row)
                    documents.append(Document(
                        page_content=doc_text,
                        metadata={
                            'source': 'Training Features',
                            'timestamp': row.get('timestamp', ''),
                            'log_file': 'training_features'
                        }
                    ))
                print(f"  Loading {len(df)} feature vectors")
            except Exception as e:
                print(f"  ⚠️  Failed to load training features: {e}")

        print(f"✅ Loaded {len(documents)} total documents")
        return documents

    def convert_log_to_text(self, log, log_type):
        """Convert log entry to meaningful text for embeddings"""
        if log_type == 'Load Balancer Access':
            return self.format_lb_log(log)
        elif log_type == 'GKE Autoscaling Events':
            return self.format_scaling_log(log)
        elif log_type == 'Node Pressure Events':
            return self.format_pressure_log(log)
        elif log_type == 'Backend Service Requests':
            return self.format_backend_log(log)
        elif log_type == 'Cluster Events':
            return self.format_cluster_log(log)
        else:
            return self.format_generic_log(log, log_type)

    def format_lb_log(self, log):
        """Format load balancer log"""
        try:
            timestamp = log.get('timestamp', '')

            # Extract HTTP request info
            http_req = log.get('httpRequest', {})
            method = http_req.get('requestMethod', 'UNKNOWN')
            status = http_req.get('status', 0)
            latency = http_req.get('latency', '0s')
            remote_ip = http_req.get('remoteIp', 'unknown')
            user_agent = http_req.get('userAgent', '')

            # Try to extract country/region info
            country = 'unknown'
            if 'jsonPayload' in log:
                payload = log['jsonPayload']
                if isinstance(payload, dict):
                    country = payload.get('country', 'unknown')

            text = f"""
            Load Balancer Request at {timestamp}:
            - Method: {method}, Status: {status}
            - Latency: {latency}
            - Source IP: {remote_ip}
            - Country: {country}
            - User Agent: {user_agent[:100]}
            - Request indicates traffic from {country} with {latency} response time
            """
            return text.strip()
        except Exception:
            return None

    def format_scaling_log(self, log):
        """Format scaling event log"""
        try:
            timestamp = log.get('timestamp', '')

            # Extract scaling info
            payload = log.get('jsonPayload', {})
            reason = payload.get('reason', 'Unknown scaling event')
            message = payload.get('message', '')

            # Extract resource info
            resource = log.get('resource', {}).get('labels', {})
            cluster = resource.get('cluster_name', 'unknown')
            location = resource.get('location', 'unknown')

            text = f"""
            Cluster Scaling Event at {timestamp}:
            - Cluster: {cluster} in {location}
            - Reason: {reason}
            - Details: {message}
            - This scaling event shows cluster {cluster} responded to load changes
            """
            return text.strip()
        except Exception:
            return None

    def format_pressure_log(self, log):
        """Format node pressure log"""
        try:
            timestamp = log.get('timestamp', '')

            payload = log.get('jsonPayload', {})
            reason = payload.get('reason', 'Resource pressure')
            message = payload.get('message', '')

            resource = log.get('resource', {}).get('labels', {})
            node = resource.get('node_name', 'unknown')
            cluster = resource.get('cluster_name', 'unknown')

            text = f"""
            Node Resource Pressure at {timestamp}:
            - Node: {node} in cluster {cluster}
            - Pressure Type: {reason}
            - Details: {message}
            - This indicates resource constraints requiring scaling consideration
            """
            return text.strip()
        except Exception:
            return None

    def format_backend_log(self, log):
        """Format backend service log"""
        try:
            timestamp = log.get('timestamp', '')

            # Extract backend service info
            resource = log.get('resource', {}).get('labels', {})
            backend_service = resource.get('backend_service_name', 'unknown')
            region = resource.get('region', 'global')

            severity = log.get('severity', 'INFO')

            text = f"""
            Backend Service Event at {timestamp}:
            - Service: {backend_service} in {region}
            - Severity: {severity}
            - This backend service event provides insights into load distribution
            """
            return text.strip()
        except Exception:
            return None

    def format_cluster_log(self, log):
        """Format cluster event log"""
        try:
            timestamp = log.get('timestamp', '')

            proto_payload = log.get('protoPayload', {})
            method = proto_payload.get('methodName', 'unknown')

            resource = log.get('resource', {}).get('labels', {})
            cluster = resource.get('cluster_name', 'unknown')
            location = resource.get('location', 'unknown')

            text = f"""
            Cluster Operation at {timestamp}:
            - Cluster: {cluster} in {location}
            - Operation: {method}
            - This cluster operation affects capacity and availability
            """
            return text.strip()
        except Exception:
            return None

    def format_generic_log(self, log, log_type):
        """Format generic log entry"""
        try:
            timestamp = log.get('timestamp', '')
            severity = log.get('severity', 'INFO')

            text = f"""
            {log_type} Event at {timestamp}:
            - Severity: {severity}
            - Raw log entry for analysis
            """
            return text.strip()
        except Exception:
            return None

    def convert_features_to_text(self, row):
        """Convert feature row to text"""
        text = f"""
        Infrastructure Metrics Summary:
        - Total Requests: {row.get('total_requests', 0)}
        - Geographic Distribution:
          * Asia: {row.get('asia_percentage', 0):.1f}% ({row.get('asia_requests', 0)} requests)
          * Europe: {row.get('europe_percentage', 0):.1f}% ({row.get('europe_requests', 0)} requests)
          * Americas: {row.get('americas_percentage', 0):.1f}% ({row.get('americas_requests', 0)} requests)
        - Average Backend Latency: {row.get('avg_backend_latency_ms', 0):.0f}ms
        - Scaling Events: {row.get('scaling_events_count', 0)}
        - Resource Pressure Events: {row.get('pressure_events_count', 0)}
        - Geographic Diversity: {row.get('unique_countries', 0)} countries
        - Top Traffic Source: {row.get('top_country', 'unknown')} ({row.get('top_country_requests', 0)} requests)
        
        This data shows current load patterns and system performance metrics.
        """
        return text.strip()

    def create_vector_store(self, documents):
        """Create vector store from documents"""
        print("🔍 Creating vector embeddings...")

        # Split documents into chunks
        text_splitter = RecursiveCharacterTextSplitter(
            chunk_size=1000,
            chunk_overlap=200,
            separators=["\n\n", "\n", " ", ""]
        )

        splits = text_splitter.split_documents(documents)
        print(f"  Split into {len(splits)} chunks")

        # Create vector store
        persist_directory = self.data_dir / "chroma_db"

        try:
            self.vectorstore = Chroma.from_documents(
                documents=splits,
                embedding=self.embeddings,
                persist_directory=str(persist_directory)
            )
            print(f"✅ Created vector store with {len(splits)} embeddings")
        except Exception as e:
            print(f"❌ Failed to create vector store: {e}")
            raise

    def query_for_scaling_decision(self, current_metrics, k=5):
        """Query vector store for relevant scaling context"""
        if not self.vectorstore:
            raise ValueError("Vector store not initialized")

        # Create query based on current metrics
        query = f"""
        Current infrastructure state:
        - Total requests: {current_metrics.get('total_requests', 0)}
        - Asia traffic: {current_metrics.get('asia_percentage', 0):.1f}%
        - Europe traffic: {current_metrics.get('europe_percentage', 0):.1f}%
        - Americas traffic: {current_metrics.get('americas_percentage', 0):.1f}%
        - Backend latency: {current_metrics.get('avg_backend_latency_ms', 0):.0f}ms
        - Resource pressure events: {current_metrics.get('pressure_events_count', 0)}
        
        Similar scaling scenarios and outcomes
        """

        # Retrieve relevant documents
        relevant_docs = self.vectorstore.similarity_search(query, k=k)

        return relevant_docs, query

    def make_scaling_decision(self, current_metrics):
        """Make intelligent scaling decision using RAG"""
        print("🤔 Analyzing current metrics for scaling decision...")

        # Get relevant historical context
        relevant_docs, query = self.query_for_scaling_decision(current_metrics)

        # Build context from relevant documents
        context = "\n\n".join([doc.page_content for doc in relevant_docs])

        # Create prompt for LLM
        prompt = f"""
        You are an expert cloud infrastructure engineer making scaling decisions for a multi-region GKE deployment.

        CURRENT METRICS:
        - Total requests: {current_metrics.get('total_requests', 0)}
        - Geographic distribution:
          * Asia: {current_metrics.get('asia_percentage', 0):.1f}% ({current_metrics.get('asia_requests', 0)} requests)
          * Europe: {current_metrics.get('europe_percentage', 0):.1f}% ({current_metrics.get('europe_requests', 0)} requests)  
          * Americas: {current_metrics.get('americas_percentage', 0):.1f}% ({current_metrics.get('americas_requests', 0)} requests)
        - Average backend latency: {current_metrics.get('avg_backend_latency_ms', 0):.0f}ms
        - Scaling events: {current_metrics.get('scaling_events_count', 0)}
        - Resource pressure events: {current_metrics.get('pressure_events_count', 0)}
        - Geographic diversity: {current_metrics.get('unique_countries', 0)} countries

        HISTORICAL CONTEXT FROM SIMILAR SCENARIOS:
        {context}

        INFRASTRUCTURE SETUP:
        - Hot regions (always active): europe-west2, us-south1
        - Cold regions (scale-to-zero): asia-southeast1

        DECISION FRAMEWORK:
        1. Scale UP Asia cluster if:
           - Asia traffic > 50 requests OR > 10% of total traffic
           - High latency (> 500ms) to hot regions
           - Resource pressure in hot regions

        2. Scale DOWN Asia cluster if:
           - Asia traffic < 10 requests AND < 2% of total traffic
           - Low latency (< 200ms) to hot regions
           - No resource pressure

        Based on the current metrics and historical patterns, provide a structured scaling recommendation:

        RECOMMENDATION: [SCALE_UP_ASIA | SCALE_DOWN_ASIA | NO_CHANGE]
        CONFIDENCE: [HIGH | MEDIUM | LOW]
        TARGET_NODES: [0-5]
        
        REASONING:
        - Primary trigger: [geographic_traffic | latency | resource_pressure | cost_optimization]
        - Key factors: [list 2-3 key factors from the data]
        - Risk assessment: [potential risks of this decision]
        
        EXECUTION:
        - Immediate action: [specific command or action to take]
        - Monitoring: [what to watch after scaling]
        - Rollback condition: [when to reverse this decision]
        """

        try:
            # Get LLM response
            response = self.llm.invoke(prompt)

            print("🎯 Scaling Decision:")
            print(response)

            return {
                'recommendation': response,
                'context_docs': len(relevant_docs),
                'query_used': query,
                'current_metrics': current_metrics
            }

        except Exception as e:
            print(f"❌ Failed to get scaling decision: {e}")
            return None

    def run_analysis(self):
        """Run complete analysis pipeline"""
        print("🚀 Starting Predictive Scaling Analysis...")

        # Load training data
        documents = self.load_training_data()
        if not documents:
            print("❌ No training data found")
            return

        # Create vector store
        self.create_vector_store(documents)

        # Load current metrics (from latest training features)
        features_file = self.data_dir / 'training_features.csv'
        if features_file.exists():
            df = pd.read_csv(features_file)
            current_metrics = df.iloc[-1].to_dict()
        else:
            # Use mock data for testing
            current_metrics = {
                'total_requests': 150,
                'asia_requests': 75,
                'europe_requests': 50,
                'americas_requests': 25,
                'asia_percentage': 50.0,
                'europe_percentage': 33.3,
                'americas_percentage': 16.7,
                'avg_backend_latency_ms': 250,
                'scaling_events_count': 2,
                'pressure_events_count': 1,
                'unique_countries': 8
            }

        # Make scaling decision
        decision = self.make_scaling_decision(current_metrics)

        if decision:
            # Save decision for record
            decision_file = self.data_dir / f"scaling_decision_{datetime.now().strftime('%Y%m%d_%H%M%S')}.json"
            with open(decision_file, 'w') as f:
                json.dump(decision, f, indent=2, default=str)

            print(f"💾 Saved decision to: {decision_file}")

        return decision

def main():
    parser = argparse.ArgumentParser(description='Predictive Infrastructure Scaler')
    parser.add_argument('--data-dir', default='../ml_training_data',
                        help='Directory containing training data')
    parser.add_argument('--model', default='mistral',
                        help='Ollama model to use (mistral, llama2, codellama)')
    parser.add_argument('--test', action='store_true',
                        help='Run test analysis with mock data')

    args = parser.parse_args()

    # Initialize scaler
    scaler = InfrastructureScaler(data_dir=args.data_dir, model_name=args.model)

    # Run analysis
    decision = scaler.run_analysis()

    if decision:
        print("\n✅ Analysis complete!")
        print("📊 Review the scaling recommendation above")
        print("🔧 Execute the suggested actions manually or integrate with automation")
    else:
        print("\n❌ Analysis failed")
        return 1

    return 0

if __name__ == "__main__":
    sys.exit(main())