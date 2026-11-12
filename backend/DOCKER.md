# LabGo Backend Docker Deployment Guide

This guide covers deploying the LabGo backend using Docker and Docker Compose.

## Prerequisites

- Docker 20.10+
- Docker Compose 2.0+

## Quick Start

### 1. Build and Run with Docker Compose

```bash
cd backend
docker-compose up -d
```

### 2. Check Container Status

```bash
docker-compose ps
docker-compose logs -f backend
```

### 3. Stop the Container

```bash
docker-compose down
```

## Configuration

### Environment Variables

Create a `.env` file in the backend directory (use `.env.example` as template):

```bash
cp .env.example .env
```

Required variables:
- `MONGODB_URI` - MongoDB connection string
- `JWT_SECRET` - Secret key for JWT tokens
- `R2_ACCOUNT_ID` - Cloudflare R2 account ID
- `R2_ACCESS_KEY_ID` - Cloudflare R2 access key
- `R2_SECRET_ACCESS_KEY` - Cloudflare R2 secret key
- `R2_BUCKET_NAME` - Cloudflare R2 bucket name
- `R2_ENDPOINT` - Cloudflare R2 endpoint URL

Optional variables:
- `NODE_ENV` - Environment (development/production)
- `PORT` - Server port (default: 3000)
- `OTP_API_KEY` - SMS OTP service API key
- `TELEGRAM_BOT_TOKEN` - Telegram bot token for notifications

## Docker Commands

### Build Image Only

```bash
docker build -t labgo-backend .
```

### Run Container with Custom Port

```bash
docker run -d \
  --name labgo-backend \
  -p 3000:8080 \
  --env-file .env \
  labgo-backend
```

### Run Container with Environment Variables

```bash
docker run -d \
  --name labgo-backend \
  -p 3000:3000 \
  -e MONGODB_URI="mongodb://..." \
  -e JWT_SECRET="your-secret" \
  -e R2_ACCOUNT_ID="your-account-id" \
  labgo-backend
```

### View Logs

```bash
# All logs
docker logs labgo-backend

# Follow logs
docker logs -f labgo-backend

# Last 100 lines
docker logs --tail 100 labgo-backend
```

### Access Container Shell

```bash
docker exec -it labgo-backend sh
```

## Production Deployment

### Build Production Image

```bash
docker build -t labgo-backend:latest .
```

### Tag for Registry

```bash
docker tag labgo-backend:latest registry.example.com/labgo-backend:latest
```

### Push to Registry

```bash
docker push registry.example.com/labgo-backend:latest
```

### Pull and Run on Production Server

```bash
docker pull registry.example.com/labgo-backend:latest
docker run -d \
  --name labgo-backend \
  --restart unless-stopped \
  -p 3000:3000 \
  --env-file .env \
  -v labgo-uploads:/app/uploads \
  registry.example.com/labgo-backend:latest
```

## Health Check

The container includes a health check endpoint:

```bash
curl http://localhost:3000/api/health
```

Response:
```json
{
  "status": "ok",
  "timestamp": "2024-01-21T12:00:00.000Z",
  "uptime": 123.456,
  "environment": "production"
}
```

## Volumes

- `uploads-data` - Persist uploaded files
- `logs-data` - Application logs

## Troubleshooting

### Container Won't Start

```bash
# Check logs
docker-compose logs backend

# Check environment variables
docker-compose config
```

### Database Connection Issues

1. Verify `MONGODB_URI` is correct
2. Check network connectivity to MongoDB host
3. Ensure MongoDB port is accessible

### File Upload Issues

1. Check R2 credentials in environment variables
2. Verify R2 bucket exists and is accessible
3. Check container logs for R2 errors

## Security Notes

1. **Never commit `.env` files** to version control
2. Use strong, unique `JWT_SECRET` in production
3. Rotate credentials regularly
4. Use secrets management (Docker Secrets, AWS Secrets Manager, etc.)
5. Enable HTTPS/TLS in production
6. Run containers as non-root user (already configured in Dockerfile)

## Docker Compose Override

Create `docker-compose.override.yml` for local development:

```yaml
version: '3.8'

services:
  backend:
    environment:
      - NODE_ENV=development
    volumes:
      - ./routes:/app/routes
      - ./models:/app/models
    command: npm run dev
```

This override will:
- Set development mode
- Mount source code for live reloading
- Use nodemon instead of node
