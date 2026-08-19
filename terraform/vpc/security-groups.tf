resource "yandex_vpc_security_group" "backend" {
  name       = "backend-sg"
  network_id = yandex_vpc_network.main.id
  ingress {
    protocol       = "TCP"
    description    = "App from VPC"
    port           = 8080
    v4_cidr_blocks = ["10.10.0.0/16"]
  }
  ingress {
    protocol       = "TCP"
    description    = "SSH from VPC"
    port           = 22
    v4_cidr_blocks = ["10.10.0.0/16"]
  }
  # Healthcheck'и от балансировщика Yandex Cloud
  ingress {
    protocol          = "TCP"
    description       = "Healthchecks"
    port              = 8080
    predefined_target = "loadbalancer_healthchecks"
  }
  # Исходящий — всё разрешено
  egress {
    protocol       = "ANY"
    description    = "All outgoing"
    v4_cidr_blocks = ["0.0.0.0/0"]
    from_port      = 0
    to_port        = 65535
  }
}

resource "yandex_vpc_security_group" "postgres" {
  name       = "postgres-sg"
  network_id = yandex_vpc_network.main.id
  ingress {
    protocol       = "TCP"
    port           = 6432
    v4_cidr_blocks = ["10.10.11.0/24", "10.10.12.0/24", "10.10.13.0/24"]
  }
  ingress {
    protocol       = "TCP"
    port           = 5432
    v4_cidr_blocks = ["10.10.11.0/24", "10.10.12.0/24", "10.10.13.0/24"]
  }
}
