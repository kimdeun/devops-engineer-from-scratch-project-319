resource "yandex_iam_service_account" "sa" {
  name        = "robot"
  folder_id   = var.folder_id
}

resource "yandex_resourcemanager_folder_iam_member" "admin-account-iam" {
  folder_id   = var.folder_id
  role        = "editor"
  member      = "serviceAccount:${yandex_iam_service_account.sa.id}"
}

resource "yandex_storage_bucket" "tfstate" {
  folder_id = var.folder_id
  bucket    = "state-bucket-hexlet"
  
  depends_on = [yandex_resourcemanager_folder_iam_member.admin-account-iam]
}

resource "yandex_ydb_database_serverless" "database1" {
  name                = "state_bd"
  deletion_protection = false
  
  serverless_database {
    storage_size_limit = 10
  }
  
  depends_on = [yandex_resourcemanager_folder_iam_member.admin-account-iam]
}