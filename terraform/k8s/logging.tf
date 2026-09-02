resource "yandex_logging_group" "bulletin_board" {
  name             = "bulletin-board-prod"
  description      = "Centralized Kubernetes pod logs for bulletin-board-prod"
  folder_id        = var.folder_id
  retention_period = "168h"
}
