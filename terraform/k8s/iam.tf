resource "yandex_iam_service_account" "service_account_cluster" {
  name        = "service_account_cluster"
}

resource "yandex_iam_service_account" "service_account_node" {
  name        = "service_account_node"
}

resource "yandex_resourcemanager_folder_iam_member" "service_account_cluster_role" {
  role        = "k8s.clusters.agent"
  member      = "serviceAccount:${yandex_iam_service_account.service_account_cluster.id}"
  folder_id = var.folder_id
}

resource "yandex_resourcemanager_folder_iam_member" "service_account_cluster_vpc_role" {
  role        = "vpc.publicAdmin"
  member      = "serviceAccount:${yandex_iam_service_account.service_account_cluster.id}"
  folder_id = var.folder_id
}

resource "yandex_resourcemanager_folder_iam_member" "service_account_node_role" {
  role        = "k8s.nodes.accountant"
  member      = "serviceAccount:${yandex_iam_service_account.service_account_node.id}"
  folder_id = var.folder_id
}
