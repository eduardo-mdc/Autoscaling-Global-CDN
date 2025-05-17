output "cluster_id" {
  description = "ID of the Kubernetes cluster"
  value       = scaleway_k8s_cluster.this.id
}

output "pool_id" {
  description = "ID of the node pool"
  value       = scaleway_k8s_pool.this.id
}

output "kubeconfig" {
  description = "Kubeconfig for the K8s cluster"
  value       = data.scaleway_k8s_cluster.kubeconfig.kubeconfig[0].config_file
  sensitive   = true
}

output "security_group_id" {
  description = "ID of the K8s security group"
  value       = scaleway_instance_security_group.k8s.id
}

output "cluster_endpoint" {
  description = "API endpoint of the K8s cluster"
  value       = scaleway_k8s_cluster.this.apiserver_url
}
