variable "resource_group_name" {
  description = "Prefix for all resources (e.g. myapp)"
  type        = string
}

variable "alb_endpoints" {
  description = "Map of region key to ALB DNS name"
  type        = map(string)
}
