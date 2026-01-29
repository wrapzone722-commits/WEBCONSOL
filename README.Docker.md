# 🐳 AutoDetailHub - Docker Quick Start

## Быстрый старт

### 1. Собрать и запустить контейнер

```bash
# С помощью docker-compose (рекомендуется)
docker-compose up -d

# Или напрямую через Docker
docker build -t autodetailhub .
docker run -d -p 8080:8080 --name autodetailhub autodetailhub
```

### 2. Проверить что приложение работает

```bash
# Проверить логи
docker-compose logs -f

# Или для Docker CLI
docker logs -f autodetailhub

# Открыть приложение
open http://localhost:8080
```

### 3. Остановить приложение

```bash
# docker-compose
docker-compose down

# Docker CLI
docker stop autodetailhub
docker rm autodetailhub
```

## Основные команды

### Сборка

```bash
# Собрать образ
docker build -t autodetailhub .

# Пересобрать без кэша
docker build --no-cache -t autodetailhub .

# Собрать и сразу запустить
docker-compose up --build
```

### Запуск

```bash
# Фоновый режим
docker-compose up -d

# С логами в терминале
docker-compose up

# Только сборка (без запуска)
docker-compose build
```

### Логи и мониторинг

```bash
# Показать логи
docker-compose logs

# Следить за логами в реальном времени
docker-compose logs -f

# Последние 100 строк
docker-compose logs --tail=100

# Статус контейнера
docker-compose ps

# Использование ресурсов
docker stats
```

### Управление

```bash
# Остановить
docker-compose stop

# Запустить снова
docker-compose start

# Перезапустить
docker-compose restart

# Удалить контейнеры
docker-compose down

# Удалить с volumes
docker-compose down -v
```

## Переменные окружения

Создайте файл `.env`:

```bash
cp .env.example .env
```

Основные переменные:

- `NODE_ENV=production` - режим работы
- `PORT=8080` - порт сервера
- `PING_MESSAGE=pong` - кастомное сообщение для /api/ping

## Health Check

Приложение предоставляет 2 эндпоинта для проверки здоровья:

- **`GET /health`** - основной health check
- **`GET /api/ping`** - проверка API

Проверка вручную:

```bash
# Внутри контейнера
docker exec autodetailhub wget -qO- http://localhost:8080/health

# Или через curl
curl http://localhost:8080/health
```

## Production Deployment

### Timeweb Cloud (Рекомендуется для РФ)

```bash
# 1. Запустите скрипт автоматического деплоя
bash scripts/deploy-timeweb.sh

# Или вручную:
docker build -t autodetailhub .
docker tag autodetailhub YOUR_USERNAME/autodetailhub:latest
docker push YOUR_USERNAME/autodetailhub:latest

# 2. Создайте приложение на https://timeweb.cloud
# 3. Выберите Docker Registry
# 4. Укажите: YOUR_USERNAME/autodetailhub:latest
```

📚 **Полная инструкция**: [TIMEWEB.md](./TIMEWEB.md)

### DigitalOcean

```bash
# 1. Залогиниться в registry
doctl registry login

# 2. Тегировать образ
docker tag autodetailhub registry.digitalocean.com/YOUR_REGISTRY/autodetailhub:latest

# 3. Загрузить
docker push registry.digitalocean.com/YOUR_REGISTRY/autodetailhub:latest

# 4. Развернуть через App Platform или Droplet
```

### Docker Hub

```bash
# 1. Залогиниться
docker login

# 2. Тегировать
docker tag autodetailhub YOUR_USERNAME/autodetailhub:latest

# 3. Загрузить
docker push YOUR_USERNAME/autodetailhub:latest

# На сервере:
docker pull YOUR_USERNAME/autodetailhub:latest
docker run -d -p 8080:8080 YOUR_USERNAME/autodetailhub:latest
```

## Troubleshooting

### Контейнер не запускается

```bash
# Проверить логи
docker-compose logs app

# Проверить статус
docker-compose ps

# Запустить интерактивно для отладки
docker run -it --rm autodetailhub sh
```

### Порт уже занят

```bash
# Найти процесс на порту 8080
lsof -i :8080

# Или изменить порт в docker-compose.yml:
ports:
  - "3000:8080"  # host:container
```

### Медленная сборка

```bash
# Использовать BuildKit
DOCKER_BUILDKIT=1 docker build -t autodetailhub .

# Или включить в docker-compose.yml:
COMPOSE_DOCKER_CLI_BUILD=1 DOCKER_BUILDKIT=1 docker-compose build
```

### Пересоздать контейнеры

```bash
# Полная очистка и пересоздание
docker-compose down -v
docker-compose build --no-cache
docker-compose up -d
```

## Безопасность

✅ **Образ основан на Alpine Linux** - минимальный размер  
✅ **Multi-stage build** - только необходимые зависимости  
✅ **Non-root user** - запуск от пользователя `nodejs`  
✅ **Health checks** - автоматический мониторинг  
✅ **Locked dependencies** - `pnpm-lock.yaml`

## Размер образа

- **Builder stage**: ~800MB (временный)
- **Production stage**: ~250-300MB (финальный)

Оптимизация:

- Alpine Linux (~5MB база)
- Только production dependencies
- Multi-stage build
- .dockerignore исключает лишнее

## Дополнительная документация

- [DOCKER.md](./DOCKER.md) - полная документация по Docker
- [DEPLOY.md](./DEPLOY.md) - деплой на разные платформы
- [.env.example](./.env.example) - примеры переменных окружения

## Поддержка

Проблемы с Docker:

1. Проверьте логи: `docker-compose logs -f`
2. Проверьте health: `curl http://localhost:8080/health`
3. Пересоберите образ: `docker-compose build --no-cache`
4. Откройте issue на GitHub

---

🚀 **Готово к production!**
