# Отчёт: управление приложением с помощью Helm

Дата проверки: 2 сентября 2026 года.

## Что реализовано

### 1. Helm и репозитории чартов

На рабочей машине установлен Helm `v4.2.4`. Подключены репозитории:

- `ingress-nginx` — `https://kubernetes.github.io/ingress-nginx`;
- `external-secrets` — `https://charts.external-secrets.io`.

Для воспроизводимости добавлена команда:

```bash
make helm-repos
```

Подключение репозитория только делает чарт доступным для установки. Сами ingress-nginx и External Secrets Operator в кластер не устанавливались: приложение уже использует рабочий Yandex Network Load Balancer, а production Secret пока создаётся отдельно.

### 2. Собственный Helm-чарт

Чарт расположен в `k8s/bulletin-board/` и включает:

- `Chart.yaml` — метаданные чарта;
- `values.yaml` — базовые значения;
- `values-prod.yaml` — production-переопределения;
- `templates/deployment.yaml` — два Pod, RollingUpdate, health probes и распределение по нодам;
- `templates/service.yaml` — внешний Service LoadBalancer;
- `templates/configmap.yaml` — несекретная конфигурация приложения;
- `templates/secret.yaml` — опциональный шаблон Secret без сохранённых паролей;
- `templates/ingress.yaml` — опциональный Ingress;
- `templates/pdb.yaml` — PodDisruptionBudget;
- `templates/monitoring.yaml` — metrics Service и ServiceMonitor;
- `templates/NOTES.txt` — подсказки после установки.

Production-релиз использует:

- `replicaCount: 2`;
- образ `123c/hexlet:sha-7ba412a`;
- `LoadBalancer`, порт `80` → container port `8080`;
- NodePort `30080` для backend targets балансировщика;
- RollingUpdate: `maxSurge: 1`, `maxUnavailable: 0`;
- PDB: `minAvailable: 1`;
- `topologySpreadConstraints` по `kubernetes.io/hostname`;
- liveness/readiness probes через management port `9090`;
- ServiceMonitor для `/actuator/prometheus`.

### 3. Установленный Helm-релиз

В кластер установлен релиз:

```text
NAME:       bulletin-board
NAMESPACE:  bulletin-board-prod
STATUS:     deployed
REVISION:   1
CHART:      bulletin-board-0.1.0
```

Проверка Deployment:

```text
READY:       2/2
UP-TO-DATE:  2
AVAILABLE:   2
```

Pod размещены на разных рабочих нодах:

```text
10.112.129.23  cl1tbof3see7k9piu876-ezek
10.112.128.30  cl1tbof3see7k9piu876-idil
```

EndpointSlice сервиса содержит оба Pod IP:

```text
10.112.129.23,10.112.128.30  port 8080
```

Текущий публичный адрес приложения:

```text
http://130.193.46.109/
```

Пять последовательных HTTP-проверок вернули:

```text
200
200
200
200
200
```

### 4. Makefile

Добавлены команды:

| Команда | Назначение |
|---|---|
| `make helm-repos` | Подключить и обновить репозитории |
| `make helm-lint` | Проверить базовые и production values |
| `make helm-template` | Вывести сгенерированные Kubernetes YAML |
| `make helm-dry-run` | Проверить релиз через Kubernetes API без сохранения |
| `make helm-deploy` | Установить или обновить production-релиз |
| `make helm-deploy-image IMAGE_TAG=...` | Провести rolling update образа |
| `make helm-status` | Показать текущее состояние релиза |
| `make helm-history` | Показать историю ревизий |
| `make helm-rollback REVISION=...` | Откатиться к выбранной ревизии |

### 5. CI/CD

Создан `.github/workflows/deploy.yml`. Workflow:

1. запускается вручную с immutable `image_tag`;
2. не допускает параллельных production-деплоев;
3. получает краткоживущий Yandex Cloud IAM token из JSON-ключа service account;
4. формирует kubeconfig из GitHub Secrets;
5. выполняет `helm lint`;
6. выполняет `helm upgrade --install --wait --rollback-on-failure`;
7. выводит статус релиза даже при ошибке.

Workflow синтаксически проверен, но не запускался в GitHub: для выполнения нужно добавить environment secrets и RBAC, перечисленные в `docs/helm-deployment.md`.

### 6. Документация

В `docs/helm-deployment.md` описаны:

- назначение Helm и его граница ответственности с Terraform;
- подготовка и проверка чарта;
- установка и rolling update;
- порядок переопределения values;
- история и `helm rollback`;
- разные окружения;
- безопасная работа с Secret;
- включение Ingress;
- настройка CI/CD.

## Выполненные проверки

```text
helm lint (default values):       passed
helm lint (production values):    passed
helm template:                    passed
helm dry-run через API server:    passed
Helm release status:              deployed
Deployment rollout:               successfully rolled out
Ready replicas:                   2/2
Размещение на двух нодах:          passed
Service endpoints:                2
Внешние HTTP-запросы:              5 × HTTP 200
Workflow YAML syntax:              passed
git diff --check:                  passed
```

## Важные замечания

При первой миграции уже существующих Kubernetes-ресурсов команда с `--take-ownership --atomic` завершилась rollback и удалила принятые ресурсы. Приложение было сразу восстановлено через локальный Secret и обычную установку Helm. Из-за пересоздания `Service LoadBalancer` облако назначило новый публичный IP `130.193.46.109`; старый IP больше нельзя использовать.

Для следующих обновлений миграционные флаги больше не нужны: ресурсами уже управляет Helm. В Helm 4 для обычного upgrade используется `--rollback-on-failure`: при ошибке Helm возвращает предыдущую успешную ревизию.

Production-пароли не внесены в чарт и CI workflow. Они перенесены в Yandex Lockbox, синхронизируются External Secrets Operator и описаны в `docs/external-secrets-lockbox.md`; старый локальный Secret-манифест удалён после проверки миграции.

Существующие одиночные Kubernetes-манифесты не удалены, чтобы сохранить учебные изменения. Однако источником дальнейших production-релизов должен быть Helm-чарт; одновременное применение старых YAML и Helm может привести к перезаписи настроек.
