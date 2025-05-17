
output "serverless_endpoints" {
  description = "Map of serverless endpoints by region"
  value = {
    "fr-par" = module.serverless_par.endpoint_url
    "nl-ams" = module.serverless_ams.endpoint_url
    "pl-waw" = module.serverless_waw.endpoint_url
  }
}


output "vpc_ids" {
  description = "VPC IDs by region"
  value = {
    "fr-par" = module.network_par.vpc_id
    "nl-ams" = module.network_ams.vpc_id
    "pl-waw" = module.network_waw.vpc_id
  }
}