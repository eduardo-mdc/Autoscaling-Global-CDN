# AI-Powered Global CDN with Intelligent Scaling

A multi-region content delivery network on Google Cloud Platform featuring ML-driven geographic traffic analysis, predictive autoscaling, and intelligent resource optimization powered by Large Language Models.

## Architecture

**Hot Regions (Always Active)**
- `europe-west2` - Primary hot region
- `us-south1` - Americas traffic

**Cold Regions (Scale-to-Zero)**
- `asia-southeast1` - Scales based on Asia traffic patterns

**Core Components**
- Multi-region GKE clusters with AI-driven workload optimization
- Global HTTP Load Balancer with ML-powered geographic routing
- HLS video streaming with adaptive neural encoding
- OAuth2-protected admin interface with intelligent monitoring
- Real-time traffic analysis using vector embeddings and RAG
- Suricata IDS with AI-enhanced threat detection

## Quick Start

1. **Deploy Infrastructure**
   ```bash
   terraform init
   terraform plan
   terraform apply
   ```

2. **Configure Clusters**
   ```bash
   ansible-playbook -i inventory/hosts.ini streaming-deployment.yaml
   ```

3. **Upload Content**
    - Access admin interface at `https://content-manager.adm-cdn.pt`
    - Upload videos for automatic HLS conversion
    - Content distributes globally within minutes

## Key Features

- **AI-Driven Scaling**: Neural network analysis of traffic patterns with LLM-powered decision making
- **Smart Global CDN**: ML-optimized content caching with predictive pre-positioning
- **Intelligent Video Processing**: AI-enhanced HLS conversion with adaptive quality optimization
- **Advanced Security**: OAuth2 + AI-powered threat detection and anomaly analysis
- **Cost Optimization**: Machine learning models predict and prevent over-provisioning

## Admin Access

**Content Manager**: `https://content-manager.adm-cdn.pt`
- AI-assisted video upload and management
- Real-time ML autoscaler dashboard with predictive analytics
- Advanced geographic traffic analysis with neural insights

**Global CDN**: `https://adm-cdn.pt`
- Video streaming interface
- Health monitoring endpoints

## AI-Powered Scaling Logic

```
LLM-Driven Scale UP Asia:
- Neural analysis detects >50 requests OR >10% geographic shift
- ML models predict latency degradation >500ms 
- AI identifies resource pressure patterns in real-time

Intelligent Scale DOWN Asia:  
- Vector embeddings confirm <10 requests AND <2% traffic
- Predictive models ensure <200ms sustained performance
- ML-optimized cost analysis validates scaling decisions
```

## File Structure

```
terraform/          # Infrastructure as Code
playbooks/          # Ansible deployment automation  
scripts/            # Utilities and scaling logic
functions/          # Cloud Functions for automation
```

## Technologies

- **Infrastructure**: Terraform, GCP (GKE, Load Balancer, GCS)
- **Orchestration**: Kubernetes, Ansible
- **AI/ML Stack**: RAG with Ollama, Vector Embeddings, Neural Traffic Analysis
- **Streaming**: nginx + HLS, AI-optimized FFmpeg transcoding
- **Monitoring**: Suricata IDS with ML anomaly detection, Cloud AI Monitoring
- **Authentication**: OAuth2 + IAP with intelligent access patterns