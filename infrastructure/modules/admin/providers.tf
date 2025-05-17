terraform {
  required_providers {
    scaleway = {
      source  = "scaleway/scaleway"
      version = "~> 2.31.0"
    }
  }
  required_version = ">= 1.0.0"
}