terraform {

  backend "s3" {
    bucket = "backend-terraform-online-course"
    key    = "build/online-course/terraform.tfstate"
    region = "ap-southeast-1"
  }
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

provider "aws" {
  region = var.region
}

