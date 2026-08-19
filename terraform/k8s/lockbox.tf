resource "yandex_lockbox_secret" "my_secret" {
  name                = "hexlet-secret"
  folder_id           = var.folder_id
}
