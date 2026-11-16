terraform {
  # 1.11 is the first release with write-only attributes (value_wo), which keep the
  # autosign secret out of the plan and the state.
  required_version = ">= 1.11"

  backend "s3" {
    bucket = "backend-terraform-online-course"
    key    = "bootstrap/online-course/terraform.tfstate"
    region = "ap-southeast-1"
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.7"
    }
  }
}

provider "aws" {
  region = var.region
}
