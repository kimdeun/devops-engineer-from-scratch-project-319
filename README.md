### Hexlet tests and linter status:
[![Actions Status](https://github.com/kimdeun/devops-engineer-from-scratch-project-319/actions/workflows/hexlet-check.yml/badge.svg)](https://github.com/kimdeun/devops-engineer-from-scratch-project-319/actions)

---

## Требования к рабочей системе

Для развёртывания инфраструктуры необходимо установить следующие инструменты:

- [Terraform](https://developer.hashicorp.com/terraform/install) >= 1.5
- [Yandex Cloud CLI (yc)](https://yandex.cloud/ru/docs/cli/quickstart) — для получения IAM-токена
- Доступ к Yandex Cloud с правами на создание ресурсов (Managed Kubernetes, PostgreSQL, Object Storage, Lockbox, VPC)
- Настроенный S3-бакет для хранения Terraform state (backend)

---

## Авторизация

Перед запуском Terraform необходимо экспортировать переменные окружения:

```bash
export YC_TOKEN=$(yc iam create-token)
export YC_CLOUD_ID=$(yc config get cloud-id)
export YC_FOLDER_ID=$(yc config get folder-id)
```

---

## Структура проекта

```
terraform/
├── vpc/        # Сеть: VPC, подсети, NAT, security groups
└── k8s/        # Кластер: Kubernetes, PostgreSQL, S3, Lockbox, IAM
```

---

## Команды Makefile

### Инициализация и деплой VPC

```bash
make vpc-init    # Инициализация Terraform (VPC)
make vpc-plan    # Просмотр плана изменений (VPC)
make vpc-apply   # Применение изменений (VPC)
make vpc-destroy # Удаление ресурсов (VPC)
```

### Инициализация и деплой K8S + БД + S3 + Lockbox

```bash
make k8s-init    # Инициализация Terraform (K8S)
make k8s-plan    # Просмотр плана изменений (K8S)
make k8s-apply   # Применение изменений (K8S)
make k8s-destroy # Удаление ресурсов (K8S)
make k8s-output  # Показать outputs (endpoint, ключи S3, ID Lockbox и т.д.)
```

### Порядок развёртывания

1. Сначала создать сеть:
   ```bash
   make vpc-init && make vpc-apply
   ```

2. Затем создать кластер и остальные ресурсы:
   ```bash
   make k8s-init && make k8s-apply
   ```

3. Посмотреть outputs:
   ```bash
   make k8s-output
   ```

---

## Важно

- Не храните `terraform.tfstate` в репозитории — используйте S3-бэкенд.
- Файлы `secret.backend.tfvars` добавлены в `.gitignore` и не попадают в репозиторий.
- Чувствительные данные (ключи S3, токены) хранятся в Yandex Lockbox.
