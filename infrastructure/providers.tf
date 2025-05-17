terraform {
  required_providers {
    digitalocean = {
      source  = "digitalocean/digitalocean"
      version = "2.46.0"
    }
  }
}

variable "do_token" {
  description = "Digital Ocean API Token"
  type        = string
  sensitive   = true
}

provider "digitalocean" {
  token = var.do_token
}