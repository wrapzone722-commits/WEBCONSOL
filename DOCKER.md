# Docker Deployment Guide

## Quick Start

### Using Docker Compose (Recommended)

```bash
# Build and start the application
docker-compose up -d

# View logs
docker-compose logs -f

# Stop the application
docker-compose down
```

The app will be available at http://localhost:8080

### Using Docker CLI

```bash
# Build the image
docker build -t autodetailhub .

# Run the container
docker run -d \
  -p 8080:8080 \
  -e NODE_ENV=production \
  -e PORT=8080 \
  --name autodetailhub \
  autodetailhub

# View logs
docker logs -f autodetailhub

# Stop and remove
docker stop autodetailhub
docker rm autodetailhub
```

## Production Deployment

### 1. Build Optimization

The Dockerfile uses multi-stage builds for minimal image size:

- Build stage: Compiles the application
- Production stage: Only includes runtime dependencies

Current image size: ~200-300MB (Alpine-based)

### 2. Environment Variables

Create a `.env` file from `.env.example`:

```bash
cp .env.example .env
# Edit .env with your values
```

Required variables:

- `NODE_ENV=production`
- `PORT=8080`

Optional variables:

- `DATABASE_URL` - PostgreSQL connection string
- `STRIPE_SECRET_KEY` - For payment processing
- Custom API keys

### 3. Docker Compose Production

```yaml
# docker-compose.prod.yml
version: "3.8"

services:
  app:
    image: autodetailhub:latest
    ports:
      - "8080:8080"
    environment:
      - NODE_ENV=production
      - PORT=8080
    env_file:
      - .env
    restart: always
    healthcheck:
      test:
        [
          "CMD",
          "node",
          "-e",
          "require('http').get('http://localhost:8080/api/ping', (r) => {process.exit(r.statusCode === 200 ? 0 : 1)})",
        ]
      interval: 30s
      timeout: 3s
      retries: 3
```

Deploy:

```bash
docker-compose -f docker-compose.prod.yml up -d
```

## Registry & Cloud Deployment

### Docker Hub

```bash
# Tag the image
docker tag autodetailhub:latest YOUR_USERNAME/autodetailhub:latest

# Push to Docker Hub
docker push YOUR_USERNAME/autodetailhub:latest

# Pull and run on server
docker pull YOUR_USERNAME/autodetailhub:latest
docker run -d -p 8080:8080 YOUR_USERNAME/autodetailhub:latest
```

### DigitalOcean Container Registry

```bash
# Install doctl
brew install doctl  # macOS
# or download from: https://docs.digitalocean.com/reference/doctl/

# Login
doctl auth init

# Create registry (if not exists)
doctl registry create autodetailhub-registry

# Login to registry
doctl registry login

# Tag and push
docker tag autodetailhub:latest registry.digitalocean.com/YOUR_REGISTRY/autodetailhub:latest
docker push registry.digitalocean.com/YOUR_REGISTRY/autodetailhub:latest
```

### DigitalOcean App Platform (Docker)

1. Push image to DigitalOcean Container Registry
2. Create new App → Docker Hub or DigitalOcean Container Registry
3. Select your image
4. Configure:
   - HTTP Port: `8080`
   - Health Check: `/api/ping`
   - Environment Variables: Add from `.env.example`

### AWS ECS / Fargate

```bash
# Install AWS CLI
brew install awscli  # macOS

# Login to ECR
aws ecr get-login-password --region eu-central-1 | docker login --username AWS --password-stdin YOUR_ACCOUNT_ID.dkr.ecr.eu-central-1.amazonaws.com

# Create repository
aws ecr create-repository --repository-name autodetailhub --region eu-central-1

# Tag and push
docker tag autodetailhub:latest YOUR_ACCOUNT_ID.dkr.ecr.eu-central-1.amazonaws.com/autodetailhub:latest
docker push YOUR_ACCOUNT_ID.dkr.ecr.eu-central-1.amazonaws.com/autodetailhub:latest
```

## Development

### Local Development with Docker

```bash
# Start dev server
docker-compose up

# Rebuild after code changes
docker-compose up --build

# Run commands inside container
docker-compose exec app sh
```

### Hot Reload (Development)

For development with hot reload, mount the source code:

```yaml
# docker-compose.dev.yml
version: "3.8"

services:
  app:
    build:
      context: .
      target: builder
    ports:
      - "5173:5173"
    volumes:
      - .:/app
      - /app/node_modules
    environment:
      - NODE_ENV=development
    command: pnpm run dev
```

## Troubleshooting

### Container won't start

```bash
# Check logs
docker logs autodetailhub

# Check if port is already in use
lsof -i :8080

# Verify build completed
docker images | grep autodetailhub
```

### Health check failing

```bash
# Test health endpoint manually
docker exec autodetailhub curl http://localhost:8080/api/ping

# Check container health
docker inspect --format='{{.State.Health.Status}}' autodetailhub
```

### Out of memory

Increase Docker memory limits:

- Docker Desktop: Settings → Resources → Memory
- Docker CLI: `docker run -m 512m ...`

### Build is slow

```bash
# Use BuildKit for faster builds
DOCKER_BUILDKIT=1 docker build -t autodetailhub .

# Cache layers
docker build --build-arg BUILDKIT_INLINE_CACHE=1 -t autodetailhub .
```

## Monitoring

### View logs

```bash
# Follow logs
docker logs -f autodetailhub

# Last 100 lines
docker logs --tail 100 autodetailhub

# With timestamps
docker logs -t autodetailhub
```

### Resource usage

```bash
# Real-time stats
docker stats autodetailhub

# Detailed info
docker inspect autodetailhub
```

### Health status

```bash
# Check health
docker inspect --format='{{json .State.Health}}' autodetailhub | jq

# Continuous monitoring
watch -n 5 'docker inspect --format="{{.State.Health.Status}}" autodetailhub'
```

## Security

### Best Practices

1. **Don't run as root**
   - Dockerfile uses `node` user (not root)

2. **Use specific versions**
   - Base image: `node:22-alpine` (locked)
   - Dependencies: locked via `pnpm-lock.yaml`

3. **Minimal image**
   - Alpine Linux (~5MB base)
   - Only production dependencies
   - Multi-stage build

4. **Environment variables**
   - Never commit `.env` files
   - Use secrets management in production

5. **Regular updates**
   ```bash
   # Update base image
   docker pull node:22-alpine
   docker build --no-cache -t autodetailhub .
   ```

### Scan for vulnerabilities

```bash
# Using Docker Scout
docker scout cves autodetailhub

# Using Trivy
trivy image autodetailhub
```

## CI/CD Integration

### GitHub Actions

```yaml
# .github/workflows/docker.yml
name: Build and Push Docker Image

on:
  push:
    branches: [main]

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3

      - name: Set up Docker Buildx
        uses: docker/setup-buildx-action@v2

      - name: Login to Docker Hub
        uses: docker/login-action@v2
        with:
          username: ${{ secrets.DOCKER_USERNAME }}
          password: ${{ secrets.DOCKER_PASSWORD }}

      - name: Build and push
        uses: docker/build-push-action@v4
        with:
          context: .
          push: true
          tags: YOUR_USERNAME/autodetailhub:latest
          cache-from: type=gha
          cache-to: type=gha,mode=max
```

## Support

For issues:

- Check logs: `docker logs autodetailhub`
- Verify build: `docker build -t autodetailhub . --progress=plain`
- Test locally: `docker run -it --rm autodetailhub sh`
