terraform {
  required_providers {
    yandex = {
      source  = "yandex-cloud/yandex"
      version = "~> 0.222.0"
    }
  }
  required_version = ">= 0.13"

  backend "s3" {
    endpoints = {
      s3 = "https://storage.yandexcloud.net"
    }
    region                      = "ru-central1"
    bucket                      = "hexlet-backend-kimdeun"
    key                         = "k8s/terraform.tfstate"
    use_lockfile                = true
    skip_region_validation      = true
    skip_credentials_validation = true
    skip_requesting_account_id  = true
    skip_s3_checksum            = true
  }
}

provider "yandex" {
  zone      = "ru-central1-a"
  folder_id = var.folder_id
}


data "terraform_remote_state" "vpc" {
  backend = "s3"
  config = {
    endpoints = {
      s3 = "https://storage.yandexcloud.net"
    }
    bucket = "hexlet-backend-kimdeun"
    region = "ru-central1"
    key    = "hexlet-remote-state"

    skip_region_validation      = true
    skip_credentials_validation = true
    skip_requesting_account_id  = true # Необходимая опция при описании бэкенда для Terraform версии старше 1.6.1.
    skip_s3_checksum            = true

    access_key = var.access_key
    secret_key = var.secret_key
  }
}
