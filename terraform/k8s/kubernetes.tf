resource "yandex_kubernetes_cluster" "zonal_cluster" {
  name        = "kuber-cluster"
  description = "description"

  network_id = data.terraform_remote_state.vpc.outputs.vpc_id

  master {
    zonal {
      zone      = "ru-central1-a"
      subnet_id = data.terraform_remote_state.vpc.outputs.private_subnet_ids["private-a"]
    }

    public_ip = true

    security_group_ids = ["${data.terraform_remote_state.vpc.outputs.backend_sg_id}"]

    maintenance_policy {
      auto_upgrade = true

      maintenance_window {
        start_time = "15:00"
        duration   = "3h"
      }
    }
  }

  service_account_id      = yandex_iam_service_account.service_account_cluster.id
  node_service_account_id = yandex_iam_service_account.service_account_node.id

  labels = {
    my_key       = "my_value"
    my_other_key = "my_other_value"
  }

  release_channel         = "RAPID"
  network_policy_provider = "CALICO"
}

resource "yandex_kubernetes_node_group" "node_group" {
  cluster_id = yandex_kubernetes_cluster.zonal_cluster.id
  name       = "node-group"
  instance_template {
    platform_id = "standard-v3"
    network_acceleration_type = "standard"
    container_runtime {
      type = "containerd"
    }
    network_interface {
      nat = false
      subnet_ids = [data.terraform_remote_state.vpc.outputs.private_subnet_ids["private-a"]]
    }
    resources {
        memory        = 4
        core_fraction = 50
    }
    boot_disk {
        type = "network-hdd"
        size = 64
    }
  }
  scale_policy {
    fixed_scale {
        size = 1
    }
  }
  deploy_policy {
    max_expansion   = 2
    max_unavailable = 1
  }
  allocation_policy {
    location {
      zone = "ru-central1-a"
    }
  }
}
