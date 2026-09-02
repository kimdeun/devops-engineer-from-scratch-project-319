# Yandex Lockbox и External Secrets Operator

## Результат

Приложение больше не получает production credentials из YAML-файла. Рабочая цепочка выглядит так:

```text
Yandex Lockbox (encrypted payload)
  ↓ service account с lockbox.payloadViewer
ClusterSecretStore/yandex-lockbox
  ↓ External Secrets Operator, refresh каждые 1m
ExternalSecret/bulletin-board
  ↓
Kubernetes Secret/app-secret
  ↓ envFrom при старте Pod
Deployment/bulletin-board-deployment
```

Идентификаторы стенда:

```text
Lockbox secret ID:       e6qoe6sh3eh9m15mh09m
ESO service account ID:  ajedd1qiqhog8gjnju53
ClusterSecretStore:      yandex-lockbox
ExternalSecret:          bulletin-board
Target Secret:           app-secret
Namespace приложения:    bulletin-board-prod
```

Lockbox содержит ключи:

- `SPRING_DATASOURCE_USERNAME`;
- `SPRING_DATASOURCE_PASSWORD`;
- `STORAGE_S3_ACCESSKEY`;
- `STORAGE_S3_SECRETKEY`.

Значения этих ключей не находятся в Helm values или отслеживаемых Git-файлах.

## За что отвечает каждый компонент

`yandex_lockbox_secret` создаёт контейнер для версий секрета. `yandex_lockbox_secret_version_hashed` создаёт payload-версию и сохраняет в Terraform state хеши значений, а не открытый payload.

Service account `external-secrets-lockbox` имеет `lockbox.payloadViewer` только на один Lockbox secret. Это принцип минимальных привилегий: оператор не может редактировать Lockbox и читать другие секреты folder.

`ClusterSecretStore` описывает провайдер Yandex Lockbox и способ аутентификации. Authorized key хранится только в Kubernetes Secret `external-secrets/yandex-lockbox-sa-key`, а не в Git.

`ExternalSecret` задаёт ID удалённого секрета, target Secret и интервал синхронизации. `creationPolicy: Merge` выбран для безопасной миграции ранее существовавшего `app-secret`: ESO обновляет его ключи, не удаляя объект.

Deployment по-прежнему использует:

```yaml
envFrom:
  - secretRef:
      name: app-secret
```

Приложению не нужно знать, откуда появился Kubernetes Secret.

## Установка оператора

Подключить репозиторий и установить оператор с CRD:

```bash
make helm-repos
make external-secrets-install
```

Для первого bootstrap создаётся authorized key отдельного service account. Его приватная часть должна сразу попасть в Kubernetes Secret и быть удалена с локального диска. Не добавляйте JSON-файл ключа в Git.

После создания bootstrap Secret применяется хранилище:

```bash
kubectl apply -f k8s/external-secrets/cluster-secret-store.yaml
kubectl wait --for=condition=Ready \
  clustersecretstore/yandex-lockbox \
  --timeout=2m
```

Затем обычный Helm upgrade создаёт `ExternalSecret`:

```bash
make helm-deploy
```

## Проверка синхронизации без чтения значений

```bash
make external-secrets-status
```

Ожидаемые состояния:

```text
ClusterSecretStore:  Valid, Ready=True
ExternalSecret:      SecretSynced, Ready=True
```

Посмотреть события:

```bash
kubectl describe externalsecret bulletin-board \
  -n bulletin-board-prod
```

Проверить только имена ключей, не печатая values:

```bash
kubectl get secret app-secret -n bulletin-board-prod \
  -o go-template='{{range $key, $value := .data}}{{$key}}{{"\n"}}{{end}}'
```

Никогда не используйте `kubectl get secret ... -o yaml` в CI-логах: поле `data` закодировано base64, но легко декодируется.

## Ротация

Lockbox не изменяет существующую версию. Ротация создаёт новую версию, которая становится текущей. ESO замечает новую версию на следующем refresh и обновляет Kubernetes Secret.

Безопасная последовательность для настоящего credential:

1. Создать новое значение в целевой системе. Для S3 — новый static access key; для БД — новый пароль или нового пользователя.
2. Проверить, что новое значение действительно действует.
3. Создать новую версию Lockbox, сохранив остальные ключи и заменив нужный.
4. Дождаться `ExternalSecret Ready=True` и изменения `app-secret.metadata.resourceVersion`.
5. Выполнить rolling restart, если приложение читает Secret через environment variables:

   ```bash
   kubectl rollout restart deployment/bulletin-board-deployment \
     -n bulletin-board-prod
   kubectl rollout status deployment/bulletin-board-deployment \
     -n bulletin-board-prod --timeout=5m
   ```

6. Проверить HTTP, ошибки и новые соединения.
7. Только после проверки отозвать старый credential в БД/Object Storage.

Порядок «сначала создать новое, в конце отозвать старое» обеспечивает период перекрытия и позволяет избежать простоя.

### Почему нужен rolling restart

ESO автоматически меняет Kubernetes Secret. Но значения, переданные контейнеру через `envFrom`, фиксируются при запуске Pod. Уже запущенный Java-процесс не получает новые environment variables. Rolling restart по одному заменяет Pod, и readiness probe не пускает трафик на новый Pod до его готовности.

Если Secret смонтирован как volume, Kubernetes со временем обновляет файлы без перезапуска, но приложение всё равно должно уметь перечитывать их.

## Проверка ротации на стенде

На стенде создана новая версия Lockbox с тестовым `ROTATION_MARKER`, не влияющим на приложение:

```text
Версия до:     e6q5d33krr3588nbbfvb
Версия после:  e6q669etntso7sm07uhl
Secret resourceVersion до:     2855163
Secret resourceVersion после:  2855452
ESO status:    SecretSynced, Ready=True
HTTP-проверка: 45 из 45 ответов — 200
5xx/000:       0
```

Таким образом подтверждено: новая версия появилась в Lockbox, оператор автоматически обновил Kubernetes Secret в пределах `refreshInterval: 1m`, а приложение продолжило обслуживать запросы без простоя.

## Ротация authorized key самого оператора

Authorized key — bootstrap credential. Его также нужно периодически менять:

1. создать второй authorized key того же service account;
2. обновить Kubernetes Secret `external-secrets/yandex-lockbox-sa-key`;
3. дождаться успешной следующей синхронизации ExternalSecret;
4. удалить старый authorized key в IAM.

Нельзя сначала удалять старый key: если новый окажется некорректным, ESO потеряет доступ к Lockbox.
