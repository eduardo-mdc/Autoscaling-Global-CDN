// Get available Kubernetes versions
data "digitalocean_kubernetes_versions" "available" {}

// Create Kubernetes cluster
resource "digitalocean_kubernetes_cluster" "cluster" {
  name    = "${var.project_name}-k8s-${var.region}"
  region  = var.region
  version = data.digitalocean_kubernetes_versions.available.latest_version  // Use latest available version

  vpc_uuid = var.vpc_id

  // Auto scaling node pool
  node_pool {
    name       = "${var.project_name}-node-pool"
    size       = var.node_size
    auto_scale = true
    min_nodes  = var.min_nodes
    max_nodes  = var.max_nodes
    tags       = ["${var.project_name}-k8s-node"]
  }
}

// Create a Load Balancer for the application
resource "digitalocean_loadbalancer" "public" {
  name   = "${var.project_name}-lb-${var.region}"
  region = var.region

  forwarding_rule {
    entry_port     = 80
    entry_protocol = "http"

    target_port     = 80  // Target port
    target_protocol = "http"
  }

  healthcheck {
    port     = 80
    protocol = "http"
    path     = "/"
  }

  vpc_uuid = var.vpc_id

  // Use the custom tag we defined for the node pool
  droplet_tag = "${var.project_name}-k8s-node"
}

// Note: Instead of using local_file and null_resource to deploy Kubernetes resources,
// which might cause issues in different environments, we can use the kubernetes provider.
// For simplicity in this migration, we'll rely on manual kubectl commands after the
// infrastructure is deployed.

// The following is a sample Kubernetes YAML that can be used with kubectl
resource "local_file" "k8s_deployment" {
  content = <<-YAML
    apiVersion: apps/v1
    kind: Deployment
    metadata:
      name: web-app
      namespace: default
    spec:
      replicas: ${var.min_nodes}
      selector:
        matchLabels:
          app: web-app
      template:
        metadata:
          labels:
            app: web-app
        spec:
          containers:
          - name: web-app
            image: nginx:latest  # Using nginx as a placeholder like the original
            ports:
            - containerPort: 80
            resources:
              requests:
                memory: "512Mi"
                cpu: "500m"
              limits:
                memory: "1Gi"
                cpu: "1000m"
    ---
    apiVersion: v1
    kind: Service
    metadata:
      name: web-app-service
      namespace: default
      annotations:
        service.beta.kubernetes.io/do-loadbalancer-id: "${digitalocean_loadbalancer.public.id}"
    spec:
      type: LoadBalancer
      selector:
        app: web-app
      ports:
      - port: 80
        targetPort: 80
  YAML

  filename = "${path.module}/deployment-${var.region}.yaml"
}

// Create a script to apply the Kubernetes manifests
resource "local_file" "apply_script" {
  content = <<-SCRIPT
    #!/bin/bash
    # Get kubeconfig for the cluster
    doctl auth init -t $DO_TOKEN
    doctl kubernetes cluster kubeconfig save ${digitalocean_kubernetes_cluster.cluster.id}

    # Apply the deployment
    kubectl apply -f ${local_file.k8s_deployment.filename}
  SCRIPT

  filename = "${path.module}/apply-deployment-${var.region}.sh"

  provisioner "local-exec" {
    command = "chmod +x ${self.filename}"
  }
}