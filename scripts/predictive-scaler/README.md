# Predictive Scaling Quick Start

## Prerequisites

1. **Python 3.8+** installed
2. **Ollama** running with mistral model
3. **AMD GPU drivers** (optional, for GPU acceleration)

## Setup Steps

### 1. Install Ollama (if not installed)
```bash
# Download from https://ollama.ai or use:
curl -fsSL https://ollama.ai/install.sh | sh

# Start Ollama
ollama serve

# Install mistral model
ollama pull mistral
```

### 2. Run Setup Script
```cmd
setup_predictive_scaling.bat
```

### 3. Test the System
```cmd
# Activate environment
predictive_scaling_env\Scripts\activate.bat

# Run test with mock data
python test_predictive_system.py
```

### 4. Generate Real Training Data
```cmd
# From your GCP project directory, run:
python fetch_metrics.py --hours 24

# This creates ./ml_training_data/ with real logs
```

### 5. Run Predictive Analysis
```cmd
# With real data
python predictive_scaler.py

# With different model
python predictive_scaler.py --model llama2

# Test mode
python predictive_scaler.py --test
```

## Expected Output

The system will:
1. Load historical logs and metrics
2. Create vector embeddings for similarity search
3. Analyze current infrastructure state
4. Provide scaling recommendations like:

```
RECOMMENDATION: SCALE_UP_ASIA
CONFIDENCE: HIGH  
TARGET_NODES: 2

REASONING:
- Primary trigger: geographic_traffic
- Key factors: Asia traffic 60% (180 requests), High latency 450ms
- Risk assessment: Cost increase but improved user experience

EXECUTION:
- Immediate action: gcloud container clusters update uporto-cd-gke-asia-southeast1 --enable-autoscaling --total-max-nodes 2
- Monitoring: Watch Asia request latency and node utilization
- Rollback condition: If Asia traffic drops below 10% for 30 minutes
```

## Troubleshooting

### Ollama Connection Issues
```cmd
# Check if Ollama is running
curl http://localhost:11434/api/version

# Restart Ollama service
ollama serve

# Check available models
ollama list
```

### PyTorch AMD GPU Issues
```cmd
# Reinstall with ROCm support
pip uninstall torch torchvision torchaudio
pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/rocm5.6
```

### Missing Training Data
```cmd
# Generate mock data for testing
python test_predictive_system.py

# Or collect real data
python fetch_metrics.py --hours 6
```

## Integration with Existing Scripts

You can integrate the scaling decisions with your cold autoscaler:

```python
# In your cold-autoscaler script
from predictive_scaler import InfrastructureScaler

# Get AI recommendation
scaler = InfrastructureScaler()
decision = scaler.run_analysis()

# Parse recommendation and execute
if "SCALE_UP_ASIA" in decision['recommendation']:
    scale_cluster_nodes(region="asia-southeast1", target_nodes=2)
```