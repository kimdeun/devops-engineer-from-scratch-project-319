resource "yandex_iam_service_account" "service_account_cluster" {
  name = "service-account-cluster"
}

resource "yandex_iam_service_account" "service_account_node" {
  name = "service-account-node"
}

resource "yandex_resourcemanager_folder_iam_member" "service_account_cluster_role" {
  role      = "k8s.clusters.agent"
  member    = "serviceAccount:${yandex_iam_service_account.service_account_cluster.id}"
  folder_id = var.folder_id
}

resource "yandex_resourcemanager_folder_iam_member" "service_account_cluster_vpc_role" {
  role      = "vpc.publicAdmin"
  member    = "serviceAccount:${yandex_iam_service_account.service_account_cluster.id}"
  folder_id = var.folder_id
}

resource "yandex_resourcemanager_folder_iam_member" "service_account_cluster_load_balancer_role" {
  role      = "load-balancer.admin"
  member    = "serviceAccount:${yandex_iam_service_account.service_account_cluster.id}"
  folder_id = var.folder_id
}

resource "yandex_iam_service_account" "prometheus_writer" {
  name        = "prometheus-writer"
  description = "Writes Kubernetes application metrics to Yandex Monitoring"
}

resource "yandex_resourcemanager_folder_iam_member" "prometheus_writer_role" {
  folder_id = var.folder_id
  role      = "monitoring.editor"
  member    = "serviceAccount:${yandex_iam_service_account.prometheus_writer.id}"
}

resource "yandex_iam_service_account" "fluent_bit_logging" {
  name        = "fluent-bit-logging"
  description = "Writes Kubernetes pod logs to Yandex Cloud Logging"
}

resource "yandex_iam_service_account" "external_secrets" {
  name        = "external-secrets-lockbox"
  description = "Reads the Bulletin Board payload from Yandex Lockbox for External Secrets Operator"
}

resource "yandex_resourcemanager_folder_iam_member" "fluent_bit_logging_writer_role" {
  folder_id = var.folder_id
  role      = "logging.writer"
  member    = "serviceAccount:${yandex_iam_service_account.fluent_bit_logging.id}"
}

resource "yandex_resourcemanager_folder_iam_member" "fluent_bit_monitoring_editor_role" {
  folder_id = var.folder_id
  role      = "monitoring.editor"
  member    = "serviceAccount:${yandex_iam_service_account.fluent_bit_logging.id}"
}
