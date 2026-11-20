terraform {
  # 1.11 is the first release with write-only attributes (value_wo), which keep the
  # autosign secret out of the plan and the state.
  required_version = ">= 1.11"

  backend "s3" {
    bucket = "backend-terraform-online-app"
    key    = "bootstrap/online-app/terraform.tfstate"
    region = "ap-southeast-1"

    # encrypt: the state object is always written with server-side encryption.
    # use_lockfile: S3 native locking. Terraform holds <key>.tflock during plan/apply, so two runs
    # at once cannot overwrite each other's state (Terraform 1.10 or newer).
    encrypt      = true
    use_lockfile = true
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
