resource "yandex_vpc_security_group" "k8s_sg" {
  name        = "k8s-cluster-sg"
  description = "Security group for Managed Kubernetes cluster"
  network_id  = data.terraform_remote_state.vpc.outputs.vpc_id

  ingress {
    protocol  = "ANY"
    from_port = 0
    to_port   = 65535
    v4_cidr_blocks  = ["10.10.11.0/24"]
  }

  ingress {
    protocol  = "TCP"
    from_port = 443
    to_port   = 443
    v4_cidr_blocks  = ["0.0.0.0/0"]
  }

  egress {
    protocol  = "ANY"
    from_port = 0
    to_port   = 65535
    v4_cidr_blocks  = ["0.0.0.0/0"]
  }
}
