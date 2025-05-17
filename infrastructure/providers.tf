terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 4.80"
    }
    google-beta = {
      source  = "hashicorp/google-beta"
      version = "~> 4.80"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.4"
    }
  }
  required_version = ">= 0.14"
}

