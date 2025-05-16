terraform {
  required_version = ">= 1.0.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }
  }
}

# one credentials profile for all regions:
#   aws configure --profile default
provider "aws" {
  alias   = "europe"
  region  = "eu-west-1"
  profile = "default"
}

provider "aws" {
  alias   = "america"
  region  = "us-east-1"
  profile = "default"
}

provider "aws" {
  alias   = "asia"
  region  = "ap-southeast-1"
  profile = "default"
}
