resource "yandex_mdb_postgresql_cluster" "my_cluster" {
  name        = "postgres"
  environment = "PRESTABLE"
  network_id  = data.terraform_remote_state.vpc.outputs.vpc_id

  config {
    version = 15
    resources {
      resource_preset_id = "s2.micro"
      disk_type_id       = "network-ssd"
      disk_size          = 16
    }
    postgresql_config = {
      max_connections                = 395
      enable_parallel_hash           = true
      autovacuum_vacuum_scale_factor = 0.34
      default_transaction_isolation  = "TRANSACTION_ISOLATION_READ_COMMITTED"
      shared_preload_libraries       = "SHARED_PRELOAD_LIBRARIES_AUTO_EXPLAIN,SHARED_PRELOAD_LIBRARIES_PG_HINT_PLAN"
    }
  }

  maintenance_window {
    type = "WEEKLY"
    day  = "SAT"
    hour = 12
  }

  host {
    zone      = "ru-central1-a"
    subnet_id = data.terraform_remote_state.vpc.outputs.private_subnet_ids["private-a"]
  }
}

resource "yandex_mdb_postgresql_database" "postgres-db" {
  cluster_id  = yandex_mdb_postgresql_cluster.my_cluster.id
  name        = "postgres-db"
}
