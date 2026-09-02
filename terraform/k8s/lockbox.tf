resource "yandex_lockbox_secret" "my_secret" {
  name                = "hexlet-secret"
  description         = "Sensitive values used by the Bulletin Board application"
  folder_id           = var.folder_id
  deletion_protection = true
}

# Unlike yandex_lockbox_secret_version, this resource stores only hashes of
# payload values in Terraform state. The values themselves come from ignored
# *.tfvars files and must never be committed to Git.
resource "yandex_lockbox_secret_version_hashed" "application" {
  secret_id   = yandex_lockbox_secret.my_secret.id
  description = "Bulletin Board production credentials"

  key_1        = "SPRING_DATASOURCE_USERNAME"
  text_value_1 = var.db_login
  key_2        = "SPRING_DATASOURCE_PASSWORD"
  text_value_2 = var.db_password
  key_3        = "STORAGE_S3_ACCESSKEY"
  text_value_3 = var.access_key
  key_4        = "STORAGE_S3_SECRETKEY"
  text_value_4 = var.secret_key
}

resource "yandex_lockbox_secret_iam_member" "external_secrets_payload_viewer" {
  secret_id = yandex_lockbox_secret.my_secret.id
  role      = "lockbox.payloadViewer"
  member    = "serviceAccount:${yandex_iam_service_account.external_secrets.id}"
}
