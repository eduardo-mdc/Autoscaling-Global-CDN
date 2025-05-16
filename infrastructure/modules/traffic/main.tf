locals {
  regions = {
    europe  = "eu-west-1"
    america = "us-east-1"
    asia    = "ap-southeast-1"
  }
}

// Just a data–pass module: nothing being created, just exposing your ALB DNS names.
