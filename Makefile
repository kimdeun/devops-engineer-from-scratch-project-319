# Экспорт переменных окружения для авторизации в Yandex Cloud
auth:
	export YC_TOKEN=$(shell yc iam create-token) && \
	export YC_CLOUD_ID=$(shell yc config get cloud-id) && \
	export YC_FOLDER_ID=$(shell yc config get folder-id)

# === VPC ===

vpc-init:
	terraform -chdir=terraform/vpc init -backend-config=secret.backend.tfvars

vpc-plan:
	terraform -chdir=terraform/vpc plan

vpc-apply:
	terraform -chdir=terraform/vpc apply -auto-approve

vpc-destroy:
	terraform -chdir=terraform/vpc destroy -auto-approve

# === K8S ===

k8s-init:
	terraform -chdir=terraform/k8s init -backend-config=secret.backend.tfvars

k8s-plan:
	terraform -chdir=terraform/k8s plan

k8s-apply:
	terraform -chdir=terraform/k8s apply -auto-approve

k8s-destroy:
	terraform -chdir=terraform/k8s destroy -auto-approve

k8s-output:
	terraform -chdir=terraform/k8s output

.PHONY: auth vpc-init vpc-plan vpc-apply vpc-destroy k8s-init k8s-plan k8s-apply k8s-destroy k8s-output
