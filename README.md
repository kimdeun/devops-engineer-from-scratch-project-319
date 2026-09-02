# Bulletin Board — инфраструктурный проект

[![Hexlet check](https://github.com/kimdeun/devops-engineer-from-scratch-project-319/actions/workflows/hexlet-check.yml/badge.svg?branch=main)](https://github.com/kimdeun/devops-engineer-from-scratch-project-319/actions/workflows/hexlet-check.yml)
[![Infrastructure check](https://github.com/kimdeun/devops-engineer-from-scratch-project-319/actions/workflows/infra-check.yml/badge.svg?branch=main)](https://github.com/kimdeun/devops-engineer-from-scratch-project-319/actions/workflows/infra-check.yml)

Учебный production-стенд в Yandex Cloud: Managed Kubernetes, Managed PostgreSQL, Object Storage, Network Load Balancer, Yandex Monitoring, Cloud Logging, Lockbox и External Secrets Operator. Приложение разворачивается собственным Helm-чартом.

**Задеплоенное приложение:** [http://130.193.46.109](http://130.193.46.109)

## Требования

- Terraform `1.15.8` или совместимая версия;
- Yandex Cloud CLI (`yc`) и выбранные `cloud-id`/`folder-id`;
- service account или пользователь с правами на VPC, Managed Kubernetes, Managed PostgreSQL, Object Storage, Load Balancer, Monitoring, Logging, IAM и Lockbox;
- `kubectl` с контекстом созданного Managed Kubernetes;
- Helm 4;
- Docker и доступ к Docker Hub для чтения образа `123c/hexlet`;
- S3-бакет и static access key для удалённого Terraform state;
- `make`, `curl` и `jq` для команд и диагностических проверок.

Локальные файлы `secret*.tfvars`, JSON-ключи service accounts, kubeconfig и другие credentials не должны попадать в Git.

## Структура

```text
.
├── .github/workflows/     # Hexlet check, инфраструктурный CI и ручной deploy
├── docs/                  # Helm, observability, Lockbox и debugging
├── k8s/
│   ├── bulletin-board/    # Helm-чарт приложения
│   └── external-secrets/  # ClusterSecretStore без credentials
├── output/pdf/            # Итоговая PDF-шпаргалка
├── terraform/
│   ├── vpc/               # VPC, подсети, NAT и security groups
│   └── k8s/               # Kubernetes, node group, PostgreSQL, IAM, Lockbox и logging
├── Makefile
└── README.md
```

## Авторизация

Перед Terraform-командами получите краткоживущий IAM-токен:

```bash
export YC_TOKEN="$(yc iam create-token)"
export YC_CLOUD_ID="$(yc config get cloud-id)"
export YC_FOLDER_ID="$(yc config get folder-id)"
```

Приватные tfvars создаются локально и игнорируются Git:

- `terraform/vpc/secret.backend.tfvars`;
- `terraform/k8s/secret.backend.tfvars`;
- `terraform/k8s/secrets.postgres.tfvars`.

## Создание инфраструктуры

Сначала создаётся сеть, затем кластер и зависимые сервисы:

```bash
make vpc-init
make vpc-plan
make vpc-apply

make k8s-init
make k8s-plan
make k8s-apply
```

Перед `apply` обязательно изучите plan. Команда намеренно запрашивает подтверждение и не содержит `-auto-approve`.

Получить outputs:

```bash
make k8s-output
```

## Подготовка и деплой приложения

Подключить Helm-репозитории:

```bash
make app-prepare
```

Установить External Secrets Operator и применить `ClusterSecretStore` согласно [инструкции Lockbox](docs/external-secrets-lockbox.md).

Проверить чарт без изменений в кластере:

```bash
make helm-lint
make helm-template
make helm-dry-run
```

Установить или обновить приложение:

```bash
make app-deploy
```

Провести rolling update конкретного immutable image tag:

```bash
make helm-deploy-image IMAGE_TAG=sha-6f6ba28
```

Проверить результат:

```bash
make app-status
kubectl rollout status deployment/bulletin-board-deployment \
  -n bulletin-board-prod --timeout=5m
curl --fail --show-error http://130.193.46.109/
```

История и откат:

```bash
make helm-history
make helm-rollback REVISION=1
```

Подробнее: [релизы Helm и rollback](docs/helm-deployment.md).

## Масштабирование и zero-downtime

- node group содержит минимум две рабочие ноды;
- приложение запускается в двух репликах и распределяется по разным hostname через `topologySpreadConstraints`;
- RollingUpdate использует `maxUnavailable: 0` и `maxSurge: 1`;
- readiness/liveness probes исключают неготовые Pod из трафика;
- PodDisruptionBudget сохраняет минимум одну доступную реплику;
- Helm ждёт готовности и выполняет rollback при ошибке обновления.

Проверенный процесс и результаты описаны в [отчёте Helm](docs/helm-assignment-report.md) и [сетевой шпаргалке](docs/kubernetes-network-debugging.md).

## Мониторинг и логи

Prometheus Operator собирает CPU, память, количество Pod и application latency. Метрики отправляются в Yandex Monitoring; Fluent Bit доставляет логи Pod в Cloud Logging. Настроены алерты по 5xx, latency, недоступным репликам и restart.

Как открыть Grafana/Yandex Monitoring, какие запросы и фильтры используются: [observability.md](docs/observability.md).

## Секреты

Production credentials хранятся в Yandex Lockbox. External Secrets Operator раз в минуту синхронизирует их в `app-secret`; в Helm values находится только Lockbox ID. Service account имеет `lockbox.payloadViewer` только на нужный секрет.

Проверенная ротация `Lockbox version → Kubernetes Secret` и порядок rolling restart описаны в [external-secrets-lockbox.md](docs/external-secrets-lockbox.md).

## CI/CD

- `hexlet-check.yml` — обязательная проверка Hexlet на каждый push;
- `infra-check.yml` — `terraform fmt`, `terraform init -backend=false`, `terraform validate` и `helm lint`;
- `deploy.yml` — ручной production deploy по immutable image tag с защищёнными GitHub Environment secrets.

Для deploy workflow нужны `YC_SA_JSON_CREDENTIALS`, `K8S_ENDPOINT` и `K8S_CA_CERT_B64`. Порядок настройки описан в [документации Helm](docs/helm-deployment.md#cicd).
