# modules/bastion/templates/connect-to-cluster.sh.tpl
#!/bin/bash

# Script to connect to local GKE cluster from bastion host
export USE_GKE_GCLOUD_AUTH_PLUGIN=True

CLUSTER_NAME="${project_name}-gke-${region}"
PROJECT_ID="${project_id}"
REGION="${region}"

echo "=== Connecting to ${region} GKE Cluster ==="
echo "Cluster: $CLUSTER_NAME"
echo "Region: $REGION"
echo "Project: $PROJECT_ID"
echo ""

# Check if cluster exists
echo "Checking if cluster exists..."
if ! gcloud container clusters describe $CLUSTER_NAME --region $REGION --project $PROJECT_ID >/dev/null 2>&1; then
    echo "❌ Cluster $CLUSTER_NAME not found in region $REGION"
    exit 1
fi

echo "✅ Cluster found"

# Get cluster credentials
echo "Getting cluster credentials..."
if gcloud container clusters get-credentials $CLUSTER_NAME --region $REGION --project $PROJECT_ID; then
    echo "✅ Successfully obtained cluster credentials"

    echo ""
    echo "=== Cluster Information ==="
    kubectl cluster-info --request-timeout=15s

    echo ""
    echo "=== Cluster Nodes ==="
    kubectl get nodes -o wide

    echo ""
    echo "=== Current Context ==="
    kubectl config current-context

else
    echo "❌ Failed to get cluster credentials"
    exit 1
fi

echo ""
echo "🎉 Ready to use kubectl with $CLUSTER_NAME!"
echo "Example commands:"
echo "  kubectl get pods --all-namespaces"
echo "  kubectl get services --all-namespaces"