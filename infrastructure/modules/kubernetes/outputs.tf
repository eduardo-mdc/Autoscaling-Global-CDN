output "cluster_id" {
  value = digitalocean_kubernetes_cluster.cluster.id
}

output "cluster_name" {
  value = digitalocean_kubernetes_cluster.cluster.name
}

output "loadbalancer_ip" {
  value = digitalocean_loadbalancer.public.ip
}

output "kubernetes_endpoint" {
  value = digitalocean_kubernetes_cluster.cluster.endpoint
}

output "deployment_script" {
  value = local_file.apply_script.filename
}