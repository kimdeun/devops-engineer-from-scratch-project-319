resource "yandex_vpc_security_group" "k8s_sg" {
  name        = "k8s-cluster-sg"
  description = "Security group for Managed Kubernetes cluster"
  network_id  = data.terraform_remote_state.vpc.outputs.vpc_id

  ingress {
    protocol       = "ANY"
    from_port      = 0
    to_port        = 65535
    v4_cidr_blocks = ["10.10.11.0/24"]
  }

  ingress {
    protocol       = "TCP"
    port           = 443
    v4_cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    protocol       = "TCP"
    port           = 30080
    v4_cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    protocol       = "ANY"
    from_port      = 0
    to_port        = 65535
    v4_cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Traffic between Kubernetes pods and services"
    protocol    = "ANY"
    from_port   = 0
    to_port     = 65535

    v4_cidr_blocks = [
      "10.96.0.0/16",
      "10.112.0.0/16",
    ]
  }

  ingress {
    description       = "Network Load Balancer health checks"
    protocol          = "TCP"
    from_port         = 0
    to_port           = 65535
    predefined_target = "loadbalancer_healthchecks"
  }
}

resource "yandex_vpc_security_group" "pg_sg" {
  name        = "pg-cluster-sg"
  description = "Security group for PostgreSQL Cluster"
  network_id  = data.terraform_remote_state.vpc.outputs.vpc_id

  ingress {
    protocol          = "TCP"
    port              = 6432
    security_group_id = yandex_vpc_security_group.k8s_sg.id
  }

  egress {
    protocol       = "ANY"
    from_port      = 0
    to_port        = 65535
    v4_cidr_blocks = ["0.0.0.0/0"]
  }
}
