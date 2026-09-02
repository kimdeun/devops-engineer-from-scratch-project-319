# Развёртывание Bulletin Board с помощью Helm

## Зачем проекту Helm

Раньше каждый Kubernetes-объект применялся отдельным YAML-файлом. Helm объединяет эти объекты в один **чарт**, подставляет настройки окружения и хранит историю релизов в кластере.

В этом проекте:

- `Chart.yaml` описывает чарт и его версию;
- `values.yaml` содержит безопасные значения по умолчанию для разработки;
- `values-prod.yaml` переопределяет настройки production;
- `templates/` содержит шаблоны Deployment, Service, ConfigMap, Secret, Ingress, PDB и мониторинга;
- один вызов `helm upgrade --install` создаёт или обновляет весь релиз.

Helm не заменяет Terraform. Terraform создаёт инфраструктуру: сеть, кластер и рабочие ноды. Helm управляет приложением **внутри уже созданного Kubernetes-кластера**.

## Подготовка

Проверить установку Helm:

```bash
helm version
```

Подключить репозитории сторонних чартов:

```bash
make helm-repos
```

Команда добавляет каталоги `ingress-nginx` и `external-secrets`, но не устанавливает контроллеры в кластер. Сейчас приложение опубликовано через `Service` типа `LoadBalancer`, а секрет уже существует в Kubernetes, поэтому эти контроллеры не обязательны.

## Проверка до релиза

Проверка синтаксиса и логики чарта:

```bash
make helm-lint
```

Посмотреть итоговые YAML-манифесты без обращения к кластеру:

```bash
make helm-template
```

Попросить Kubernetes API проверить итоговые объекты, но не сохранять их:

```bash
make helm-dry-run
```

`helm template` отвечает на вопрос «что сгенерирует Helm», а server-side dry run дополнительно отвечает на вопрос «примет ли это текущий Kubernetes-кластер».

## Выпуск релиза

Обычный релиз с образом из `values-prod.yaml`:

```bash
make helm-deploy
```

Rolling update конкретной версии образа:

```bash
make helm-deploy-image IMAGE_TAG=sha-6f6ba28
```

Под капотом выполняется `helm upgrade --install`:

- если релиза нет, Helm устанавливает его;
- если релиз есть, Helm сравнивает желаемое и текущее состояние и обновляет изменившиеся ресурсы;
- `--wait` ждёт готовности ресурсов;
- `--rollback-on-failure` при ошибке обновления возвращает предыдущую рабочую ревизию;
- `--timeout 5m` ограничивает ожидание пятью минутами.

После команды проверить состояние:

```bash
make helm-status
kubectl get pods -n bulletin-board-prod -o wide
kubectl get service backend-service -n bulletin-board-prod
```

## Порядок переопределения values

Приоритет растёт слева направо:

1. `values.yaml` — базовые значения чарта;
2. файлы `--values` / `-f` — каждый следующий файл перекрывает предыдущий;
3. `--set`, `--set-string` и `--set-file` — наивысший приоритет командной строки.

Пример:

```bash
helm upgrade --install bulletin-board k8s/bulletin-board \
  -n bulletin-board-prod \
  -f k8s/bulletin-board/values-prod.yaml \
  --set-string image.tag=sha-6f6ba28
```

Здесь тег из командной строки перекроет `image.tag` из обоих values-файлов. Для строковых тегов лучше `--set-string`, чтобы Helm не пытался преобразовать значение в число или boolean.

## История и откат

Показать ревизии релиза:

```bash
make helm-history
```

Откатиться к выбранной рабочей ревизии:

```bash
make helm-rollback REVISION=1
```

Helm создаст новую ревизию на основе состояния revision 1 и дождётся готовности приложения. Это не удаление истории: выполненный rollback тоже появится в `helm history`.

## Окружения

Для нового окружения создаётся отдельный файл, например `values-stage.yaml`, содержащий только отличия от базового `values.yaml`:

```bash
helm upgrade --install bulletin-board-stage k8s/bulletin-board \
  -n bulletin-board-stage --create-namespace \
  -f k8s/bulletin-board/values-stage.yaml
```

Разные имена релиза и namespace изолируют окружения друг от друга.

## Secret и безопасные credentials

Шаблон Secret присутствует в чарте, но в production задано `secret.create: false` и `externalSecret.enabled: true`. Объект `ExternalSecret` получает значения из Yandex Lockbox и синхронизирует их в `app-secret`; паролей в `values-prod.yaml` нет.

Для учебного локального запуска Secret можно создать отдельно или включить шаблон через приватный, не добавляемый в Git values-файл:

```yaml
secret:
  create: true
  stringData:
    SPRING_DATASOURCE_USERNAME: example
    SPRING_DATASOURCE_PASSWORD: example
```

Production уже использует External Secrets Operator + Yandex Lockbox. В Git хранится ID Lockbox и описание синхронизации, а не значения. Base64 в Kubernetes Secret — это кодирование, а не шифрование. Подробности и процедура ротации находятся в `docs/external-secrets-lockbox.md`.

## Ingress

По умолчанию используется уже работающий `LoadBalancer`, поэтому `ingress.enabled: false`. Чтобы перейти на Ingress:

1. установить ingress-nginx из подключённого репозитория;
2. изменить Service приложения на `ClusterIP`;
3. включить `ingress.enabled: true` и указать реальный DNS host;
4. настроить DNS на публичный адрес ingress-controller.

Сам объект Ingress не принимает трафик без ingress-controller: он лишь описывает правила маршрутизации.

## CI/CD

Workflow `.github/workflows/deploy.yml` запускается вручную и принимает immutable Docker tag. В GitHub Environment `production` нужны secrets:

- `YC_SA_JSON_CREDENTIALS` — JSON-ключ отдельного service account;
- `K8S_ENDPOINT` — URL Kubernetes API вида `https://...`;
- `K8S_CA_CERT_B64` — CA-сертификат кластера в base64.

Service account должен иметь минимально необходимые права в Yandex Cloud, а его Kubernetes-пользователь — RBAC-права на ресурсы только нужного namespace. Workflow получает краткоживущий IAM-токен, собирает kubeconfig, проверяет чарт и выполняет Helm upgrade с автоматическим rollback при ошибке.

Не добавляйте kubeconfig, IAM-токены, JSON-ключи и пароли в репозиторий или обычные workflow variables.

## Миграция старых манифестов

Первый релиз принял под управление Helm ранее созданные ресурсы с теми же именами. Старые одиночные YAML оставлены как учебная история, но дальнейшие изменения приложения следует вносить в чарт, иначе появятся два конкурирующих источника желаемого состояния.
