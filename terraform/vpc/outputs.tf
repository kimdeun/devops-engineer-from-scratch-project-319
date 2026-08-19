output "vpc_id" {
  description = "ID созданной VPC"
  value       = yandex_vpc_network.main.id
}
output "public_subnet_ids" {
  description = "ID публичных подсетей по зонам"
  value = {
    for name, subnet in yandex_vpc_subnet.main :
    name => subnet.id
    if var.subnets[name].public
  }
}
output "private_subnet_ids" {
  description = "ID приватных подсетей по зонам"
  value = {
    for name, subnet in yandex_vpc_subnet.main :
    name => subnet.id
    if !var.subnets[name].public
  }
}
output "backend_sg_id" {
  description = "Backend security group id"
  value       = yandex_vpc_security_group.backend.id
}
