# Диагностика внешнего доступа к приложению в Kubernetes

Практическая шпаргалка: как пройти от симптома «`curl` не отвечает» до точной причины.

## Главная идея

Не проверяйте всю систему одним запросом. Разделите путь трафика на слои и двигайтесь изнутри наружу. Каждый успешный тест исключает уже проверенную часть.

```text
Клиент
  -> Public Load Balancer :80
  -> Worker node          :30080
  -> Kubernetes Service
  -> Pod                  :8080
  -> Приложение
```

Если запрос к Pod не работает, Load Balancer пока проверять рано. Если Pod и Service отвечают, а внешний IP — нет, проблема находится в NodePort, health-check или security group.

## Какие адреса участвуют

| Пример | Что это | Где доступен |
|---|---|---|
| `84.252.134.120` | Публичный IP Load Balancer | Из интернета |
| `10.10.11.17` | Приватный IP рабочей ноды | В VPC |
| `10.96.254.7` | Виртуальный ClusterIP Service | Внутри кластера |
| `10.112.128.23` | Временный IP Pod | Внутри кластера |

## 1. Проверить рабочие ноды

```bash
kubectl get nodes -o wide
```

Ожидаем минимум две ноды со статусом `Ready`. Если нода `NotReady`, сначала диагностируем её: остальные уровни зависят от рабочих нод.

## 2. Проверить Pod

```bash
kubectl get pods \
  -n bulletin-board-prod \
  -o wide
```

Проверяем:

- `READY` — контейнер готов принимать трафик, например `1/1`;
- `STATUS` — ожидаем `Running`;
- `RESTARTS` — счётчик не должен постоянно расти;
- `IP` — внутренний адрес Pod для диагностики;
- `NODE` — рабочая нода, на которой запущен Pod.

Подробности и события Pod:

```bash
kubectl describe pod \
  -n bulletin-board-prod \
  <POD_NAME>
```

В разделе `Events` ищем:

- ошибки скачивания образа;
- ошибки readiness/liveness probe;
- нехватку CPU или памяти;
- проблемы планирования Pod.

## 3. Проверить логи приложения

```bash
kubectl logs \
  -n bulletin-board-prod \
  deployment/bulletin-board-deployment \
  --tail=200
```

Быстрый фильтр:

```bash
kubectl logs \
  -n bulletin-board-prod \
  deployment/bulletin-board-deployment | \
grep -Ei 'started|8080|9090|error|exception|tomcat|netty'
```

Важно: readiness probe на порту `9090` подтверждает работу health endpoint, но не доказывает, что основное приложение отвечает на `8080`.

## 4. Проверить Service

```bash
kubectl get service \
  -n bulletin-board-prod \
  backend-service
```

Запись `80:30080/TCP` означает: внешний порт Service `80` связан с NodePort `30080`. Параметр `targetPort` направляет запрос дальше на порт Pod `8080`.

```text
LoadBalancer:80 -> Node:30080 -> Pod:8080
```

Подробная информация и события:

```bash
kubectl describe service \
  -n bulletin-board-prod \
  backend-service
```

Раздел `Events` особенно важен:

- `PermissionDenied` указывает на недостаточные права облачного сервисного аккаунта;
- `EnsuredLoadBalancer` означает успешное создание балансировщика.

Старые предупреждения остаются в истории, поэтому учитывайте время событий.

## 5. Проверить, нашёл ли Service поды

Современный вариант через EndpointSlice:

```bash
kubectl get endpointslice \
  -n bulletin-board-prod \
  -l kubernetes.io/service-name=backend-service
```

Endpoint должен содержать IP Pod и порт `8080`. Если адресов нет, сравните `selector` Service с labels Pod:

```bash
kubectl get pods \
  -n bulletin-board-prod \
  --show-labels
```

Если endpoints пуст, Service не нашёл подходящие Pod. Значения `selector` и `labels` должны совпадать буквально.

## 6. Проверить Service изнутри кластера

Получить ClusterIP без ручного копирования:

```bash
CLUSTER_IP=$(kubectl get service \
  -n bulletin-board-prod \
  backend-service \
  -o jsonpath='{.spec.clusterIP}')

echo "$CLUSTER_IP"
```

Запустить временный Pod с `curl`:

```bash
kubectl run curl-test \
  -n bulletin-board-prod \
  --rm \
  -it \
  --restart=Never \
  --image=curlimages/curl \
  -- curl -v --max-time 10 "http://${CLUSTER_IP}/"
```

Команда:

- создаёт временный Pod `curl-test`;
- запускает его в том же namespace;
- выполняет запрос к Service изнутри Kubernetes;
- удаляет тестовый Pod после завершения благодаря `--rm`.

## 7. Проверить Pod напрямую

Получить IP первого Pod приложения:

```bash
POD_IP=$(kubectl get pods \
  -n bulletin-board-prod \
  -l app=bulletin-board \
  -o jsonpath='{.items[0].status.podIP}')

echo "$POD_IP"
```

Обратиться к нему из временного Pod:

```bash
kubectl run curl-test \
  -n bulletin-board-prod \
  --rm \
  -it \
  --restart=Never \
  --image=curlimages/curl \
  -- curl -v --max-time 10 "http://${POD_IP}:8080/"
```

Интерпретация:

| Результат | Вывод |
|---|---|
| Pod отвечает, а ClusterIP нет | Проверить Service и сетевые правила Service |
| Оба адреса отвечают | Внутренняя часть исправна |
| Pod не отвечает | Проверить приложение или сеть между Pod |

IP Pod временный. Его используют только для диагностики, но не сохраняют в конфигурации.

## 8. Проверить приложение через port-forward

В первом терминале:

```bash
kubectl port-forward \
  -n bulletin-board-prod \
  deployment/bulletin-board-deployment \
  18080:8080
```

Оставьте его открытым. Во втором терминале:

```bash
curl -v \
  --connect-timeout 5 \
  --max-time 10 \
  http://127.0.0.1:18080/
```

Этот тест обходит Load Balancer и Service. Если он работает, приложение точно слушает `8080`.

## 9. Проверить внешний IP

Получить IP автоматически:

```bash
EXTERNAL_IP=$(kubectl get service \
  -n bulletin-board-prod \
  backend-service \
  -o jsonpath='{.status.loadBalancer.ingress[0].ip}')

echo "$EXTERNAL_IP"
```

Выполнить запрос:

```bash
curl -v \
  --connect-timeout 5 \
  --max-time 10 \
  "http://${EXTERNAL_IP}/"
```

В терминале URL вводится без Markdown-разметки.

Правильно:

```bash
curl http://84.252.134.120/
```

Неправильно:

```text
curl "[http://84.252.134.120](http://84.252.134.120)"
```

## 10. Проверить состояние целей Load Balancer

Посмотреть балансировщики:

```bash
yc load-balancer network-load-balancer list
```

Получить подробности и найти `target_group_id`:

```bash
yc load-balancer network-load-balancer get <LOAD_BALANCER_ID>
```

Проверить состояние нод в target group:

```bash
yc load-balancer network-load-balancer target-states \
  <LOAD_BALANCER_ID> \
  --target-group-id=<TARGET_GROUP_ID>
```

| Статус | Значение |
|---|---|
| `HEALTHY` | Нода прошла проверку и получает трафик |
| `UNHEALTHY` | Проверка не проходит; пользовательский трафик не направляется |
| `INITIAL` | Проверка ещё настраивается |
| `INACTIVE` | Балансировщик или цель не активны |

## 11. Проверить security group

Посмотреть фактическое состояние правила в Terraform state:

```bash
terraform state show yandex_vpc_security_group.k8s_sg
```

### NodePort для внешнего трафика

```hcl
ingress {
  protocol       = "TCP"
  port           = 30080
  v4_cidr_blocks = ["0.0.0.0/0"]
}
```

### Связь Pod и Service

```hcl
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
```

### Проверки Network Load Balancer

```hcl
ingress {
  description       = "Network Load Balancer health checks"
  protocol          = "TCP"
  from_port         = 0
  to_port           = 65535
  predefined_target = "loadbalancer_healthchecks"
}
```

## Как читать результат curl

| Результат | Что означает | Куда смотреть |
|---|---|---|
| Timeout | Пакет не получил ответа | Маршрут, security group, firewall |
| Connection refused | Адрес доступен, но порт не слушается | Порт контейнера, процесс приложения |
| Could not resolve host | DNS не преобразовал имя в IP | CoreDNS, имя и namespace Service |
| HTTP 404 | Сеть и сервер работают, но маршрута нет | URL приложения |
| HTTP 500 | Запрос дошёл, приложение завершило обработку с ошибкой | Логи приложения и зависимости |
| HTTP 200 | Запрос успешно обработан | Переходить к следующему уровню |

## Безопасный цикл Terraform

Обновить IAM-токен текущего терминала:

```bash
export YC_TOKEN="$(yc iam create-token)"
```

Проверить конфигурацию:

```bash
terraform fmt
terraform validate
```

Построить план:

```bash
terraform plan \
  -lock-timeout=1m \
  -var-file=secrets.postgres.tfvars \
  -var-file=secret.backend.tfvars
```

Не подтверждайте изменения с `destroy` или `must be replaced`, если не понимаете их причину. Только после проверки запускайте `terraform apply` и дожидайтесь освобождения state lock.

Terraform сам создаёт и снимает блокировку. Не запускайте параллельные `apply`, не используйте `-lock=false` и не выполняйте `force-unlock`, пока активен другой процесс Terraform.

## Короткий алгоритм

```text
1. kubectl get nodes
2. kubectl get pods -o wide
3. kubectl logs / kubectl describe pod
4. kubectl get / describe service
5. kubectl get endpointslice
6. curl напрямую к Pod из тестового Pod
7. curl к ClusterIP из тестового Pod
8. yc load-balancer ... target-states
9. terraform state show security group
10. curl к External IP
```

| Граница сбоя | Вероятная область |
|---|---|
| Pod не отвечает | Приложение или сеть Pod |
| Pod отвечает, Service не отвечает | Selector, endpoints или сеть Service |
| Service отвечает, External IP не отвечает | Load Balancer, NodePort, health-check или security group |
| Всё отвечает | Внешний доступ настроен |

## Официальные источники

- [Настройка security groups Managed Kubernetes](https://yandex.cloud/ru/docs/managed-kubernetes/operations/connect/security-groups)
- [Проверки состояния Network Load Balancer](https://yandex.cloud/ru/docs/network-load-balancer/concepts/health-check)
- [Проверка target states](https://yandex.cloud/ru/docs/network-load-balancer/operations/check-resource-health)
