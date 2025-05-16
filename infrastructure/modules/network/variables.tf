variable "resource_group_name" {
  type = string
}
variable "admin_sg_id" {
  description = "Security Group ID of the bastion/admin host, to allow SSH"
  type        = string
}