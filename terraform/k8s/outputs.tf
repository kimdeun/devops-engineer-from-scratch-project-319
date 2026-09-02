output "zonal_cluster_id" {
  value = yandex_kubernetes_cluster.zonal_cluster.id
}

output "node_group_id" {
  value = yandex_kubernetes_node_group.node_group.id
}

output "logging_group_id" {
  description = "Cloud Logging group for Kubernetes pod logs"
  value       = yandex_logging_group.bulletin_board.id
}

output "fluent_bit_service_account_id" {
  description = "Service account used by Fluent Bit"
  value       = yandex_iam_service_account.fluent_bit_logging.id
}

output "kubeconfig_endpoint" {
  value = yandex_kubernetes_cluster.zonal_cluster.master[0].external_v4_endpoint
}

output "kubeconfig_certificate" {
  value     = yandex_kubernetes_cluster.zonal_cluster.master[0].cluster_ca_certificate
  sensitive = true
}

output "data_base_fdqn" {
  value = yandex_mdb_postgresql_cluster.my_cluster.host[0].fqdn
}

output "lockbox_secret_id" {
  value = yandex_lockbox_secret.my_secret.id
}

output "external_secrets_service_account_id" {
  description = "Service account used by External Secrets Operator to read Lockbox"
  value       = yandex_iam_service_account.external_secrets.id
}
