provider "aws" {
  profile = "kaapana"
  region  = var.aws_region
}

terraform {
  required_version = ">= 1.5.0"

  backend "s3" {
    bucket       = "223271671018-kaapana-ec2-tfstate"
    key          = "poc/terraform.tfstate"
    region       = "us-east-1"
    encrypt      = true
    use_lockfile = true
    profile      = "kaapana"
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.5"
    }
  }
}
