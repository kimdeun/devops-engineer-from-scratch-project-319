# Экспорт переменных окружения для авторизации в Yandex Cloud
CHART_DIR ?= k8s/bulletin-board
RELEASE ?= bulletin-board
NAMESPACE ?= bulletin-board-prod
VALUES ?= $(CHART_DIR)/values-prod.yaml
TIMEOUT ?= 5m
EXTERNAL_SECRETS_NAMESPACE ?= external-secrets
LOCK_TIMEOUT ?= 5m
K8S_VAR_FILES ?= -var-file=secrets.postgres.tfvars -var-file=secret.backend.tfvars

auth:
	export YC_TOKEN=$(shell yc iam create-token) && \
	export YC_CLOUD_ID=$(shell yc config get cloud-id) && \
	export YC_FOLDER_ID=$(shell yc config get folder-id)

# === VPC ===

vpc-init:
	terraform -chdir=terraform/vpc init -backend-config=secret.backend.tfvars

vpc-plan:
	terraform -chdir=terraform/vpc plan -lock-timeout=$(LOCK_TIMEOUT)

vpc-apply:
	terraform -chdir=terraform/vpc apply -lock-timeout=$(LOCK_TIMEOUT)

vpc-destroy:
	terraform -chdir=terraform/vpc destroy -auto-approve

# === K8S ===

k8s-init:
	terraform -chdir=terraform/k8s init -backend-config=secret.backend.tfvars

k8s-plan:
	terraform -chdir=terraform/k8s plan -lock-timeout=$(LOCK_TIMEOUT) $(K8S_VAR_FILES)

k8s-apply:
	terraform -chdir=terraform/k8s apply -lock-timeout=$(LOCK_TIMEOUT) $(K8S_VAR_FILES)

k8s-destroy:
	terraform -chdir=terraform/k8s destroy -auto-approve

k8s-output:
	terraform -chdir=terraform/k8s output

# === HELM ===

helm-repos:
	helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx --force-update
	helm repo add external-secrets https://charts.external-secrets.io --force-update
	helm repo update

helm-lint:
	helm lint $(CHART_DIR)
	helm lint $(CHART_DIR) --values $(VALUES)

helm-template:
	helm template $(RELEASE) $(CHART_DIR) --namespace $(NAMESPACE) --values $(VALUES)

helm-dry-run:
	helm upgrade --install $(RELEASE) $(CHART_DIR) --namespace $(NAMESPACE) \
		--create-namespace --values $(VALUES) --dry-run=server

helm-deploy:
	helm upgrade --install $(RELEASE) $(CHART_DIR) --namespace $(NAMESPACE) \
		--create-namespace --values $(VALUES) --wait --timeout $(TIMEOUT)

# Пример: make helm-deploy-image IMAGE_TAG=sha-6f6ba28
helm-deploy-image:
	test -n "$(IMAGE_TAG)" || (echo "Укажите IMAGE_TAG, например IMAGE_TAG=sha-6f6ba28" && exit 1)
	helm upgrade --install $(RELEASE) $(CHART_DIR) --namespace $(NAMESPACE) \
		--create-namespace --values $(VALUES) --set-string image.tag=$(IMAGE_TAG) \
		--wait --timeout $(TIMEOUT) --rollback-on-failure

helm-status:
	helm status $(RELEASE) --namespace $(NAMESPACE)

helm-history:
	helm history $(RELEASE) --namespace $(NAMESPACE)

# Пример: make helm-rollback REVISION=1
helm-rollback:
	test -n "$(REVISION)" || (echo "Укажите REVISION, например REVISION=1" && exit 1)
	helm rollback $(RELEASE) $(REVISION) --namespace $(NAMESPACE) \
		--wait --timeout $(TIMEOUT)

# === EXTERNAL SECRETS ===

external-secrets-install:
	helm upgrade --install external-secrets external-secrets/external-secrets \
		--namespace $(EXTERNAL_SECRETS_NAMESPACE) --create-namespace \
		--set installCRDs=true --wait --timeout $(TIMEOUT)

external-secrets-status:
	helm status external-secrets --namespace $(EXTERNAL_SECRETS_NAMESPACE)
	kubectl get clustersecretstore yandex-lockbox
	kubectl get externalsecret bulletin-board --namespace $(NAMESPACE)

# === PROJECT ===

validate:
	terraform -chdir=terraform/vpc fmt -check -recursive
	terraform -chdir=terraform/k8s fmt -check -recursive
	terraform -chdir=terraform/vpc validate
	terraform -chdir=terraform/k8s validate
	$(MAKE) helm-lint

app-prepare: helm-repos

app-deploy: helm-deploy

app-status: helm-status external-secrets-status

.PHONY: auth vpc-init vpc-plan vpc-apply vpc-destroy k8s-init k8s-plan k8s-apply k8s-destroy k8s-output \
	helm-repos helm-lint helm-template helm-dry-run helm-deploy helm-deploy-image helm-status helm-history helm-rollback \
	external-secrets-install external-secrets-status validate app-prepare app-deploy app-status
