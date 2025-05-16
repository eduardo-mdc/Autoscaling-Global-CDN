variable "resource_group_name" { type = string }
variable "cpu"                { type = number }
variable "memory"             { type = number }
variable "min_replicas"       { type = number }
variable "max_replicas"       { type = number }
variable "request_count_threshold" { type = number }

variable "vpc_id"      { type = string }
variable "subnet_ids"  { type = list(string) }
variable "alb_sg_id"   { type = string }
variable "instance_sg_id" { type = string }
variable "admin_key_name" { type = string }

variable "region_name" {
  description = "The AWS region (e.g. eu-west-1) in which this module is deployed"
  type        = string
}

