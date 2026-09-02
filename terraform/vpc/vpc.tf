resource "yandex_vpc_network" "main" {
  name        = var.vpc_name
  description = "vpc yandex cloud"
}

resource "yandex_vpc_subnet" "main" {
  for_each       = var.subnets
  name           = each.key
  zone           = each.value.zone
  network_id     = yandex_vpc_network.main.id
  v4_cidr_blocks = [each.value.cidr]
  route_table_id = each.value.public ? null : yandex_vpc_route_table.nat.id
}