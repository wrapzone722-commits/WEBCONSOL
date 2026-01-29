# Deployment Guide

This guide covers deploying AutoDetailHub to various platforms.

## DigitalOcean App Platform

### Quick Deploy

[![Deploy to DO](https://www.deploytodo.com/do-btn-blue.svg)](https://cloud.digitalocean.com/apps/new?repo=https://github.com/YOUR_USERNAME/YOUR_REPO/tree/main)

### Manual Setup

1. **Create a new App on DigitalOcean**
   - Go to [DigitalOcean Apps](https://cloud.digitalocean.com/apps)
   - Click "Create App"
   - Connect your GitHub repository

2. **Configure the App**
   - The app will auto-detect the configuration from `.do/app.yaml`
   - Or manually set:
     - Build Command: `pnpm install && pnpm run build`
     - Run Command: `pnpm start`
     - HTTP Port: `8080`

3. **Set Environment Variables**

   ```
   NODE_ENV=production
   PORT=8080
   ```

4. **Deploy**
   - Click "Create Resources"
   - Wait for the build and deployment to complete
   - Your app will be available at `https://YOUR_APP_NAME.ondigitalocean.app`

### Using Docker

If you prefer Docker deployment:

```bash
# Build the image
docker build -t autodetailhub .

# Run locally
docker run -p 8080:8080 autodetailhub

# Push to registry
docker tag autodetailhub registry.digitalocean.com/YOUR_REGISTRY/autodetailhub
docker push registry.digitalocean.com/YOUR_REGISTRY/autodetailhub
```

## Netlify (Serverless)

Already configured via `netlify.toml`:

```bash
# Install Netlify CLI
npm install -g netlify-cli

# Deploy
netlify deploy --prod
```

## Vercel

```bash
# Install Vercel CLI
npm install -g vercel

# Deploy
vercel --prod
```

## Railway

1. Create new project on [Railway](https://railway.app)
2. Connect your GitHub repository
3. Railway will auto-detect the build commands
4. Set environment variables:
   - `NODE_ENV=production`
   - `PORT=8080`

## Render

1. Create new Web Service on [Render](https://render.com)
2. Connect your GitHub repository
3. Configure:
   - Build Command: `pnpm install && pnpm run build`
   - Start Command: `pnpm start`
   - Environment: `Node`
4. Add environment variables

## Local Production Build

Test production build locally:

```bash
# Build
pnpm run build

# Start production server
pnpm start

# Visit http://localhost:3000
```

## Environment Variables

Required:

- `NODE_ENV` - Set to `production`
- `PORT` - Server port (default: 3000)

Optional:

- `PING_MESSAGE` - Custom ping response message

## Health Checks

The app exposes a health check endpoint:

- **Endpoint**: `/api/ping`
- **Method**: GET
- **Response**: `{"message": "ping"}`

## Database Setup (Future)

Currently, the app uses localStorage for persistence. For production:

1. **Add PostgreSQL database** (recommended: Supabase, Neon)
2. **Set DATABASE_URL** environment variable
3. **Run migrations** (when implemented)

## Monitoring

Recommended monitoring setup:

- **Uptime**: UptimeRobot, Pingdom
- **Errors**: Sentry
- **Analytics**: Google Analytics, Plausible

## Scaling

For DigitalOcean App Platform:

- Start with `basic-xxs` instance
- Scale up as needed:
  - `basic-xs`: 512MB RAM
  - `basic-s`: 1GB RAM
  - `basic-m`: 2GB RAM

## Backup Strategy

1. **Export data regularly** via Settings → Резервная копия
2. **Store backups** in secure location
3. **Test restore** procedure periodically

## Security Checklist

- [ ] Use HTTPS (enabled by default on all platforms)
- [ ] Set strong authentication (when implemented)
- [ ] Keep dependencies updated
- [ ] Monitor for security vulnerabilities
- [ ] Use environment variables for secrets
- [ ] Enable CORS only for trusted domains

## Support

For deployment issues:

- Check logs in your platform dashboard
- Review [troubleshooting guide](./TROUBLESHOOTING.md)
- Contact support via GitHub Issues
