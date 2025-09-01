#!/bin/bash

# Plane Direct Docker Deployment Script
# Deploys Plane without requiring docker-compose

set -e

# Configuration
SECRETS_FILE="/home/administrator/projects/admin/secrets/plane.env"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Plane Direct Docker Deployment${NC}"
echo -e "${BLUE}========================================${NC}"

# Check if secrets file exists
if [ ! -f "$SECRETS_FILE" ]; then
    echo -e "${RED}Error: Secrets file not found at $SECRETS_FILE${NC}"
    exit 1
fi

# Create plane-internal network if it doesn't exist
echo -e "\n${YELLOW}Creating internal network...${NC}"
docker network create plane-internal 2>/dev/null || echo "Network plane-internal already exists"

# Stop existing containers
echo -e "\n${YELLOW}Stopping existing Plane containers...${NC}"
docker stop plane-api plane-web plane-worker plane-beat 2>/dev/null || true
docker rm plane-api plane-web plane-worker plane-beat 2>/dev/null || true

# Deploy Plane API
echo -e "\n${YELLOW}Deploying Plane API...${NC}"
docker run -d \
  --name plane-api \
  --restart unless-stopped \
  --env-file "$SECRETS_FILE" \
  --network plane-internal \
  --network-alias plane-api \
  -p 8001:8000 \
  -v plane-uploads:/code/uploads \
  --add-host="linuxserver.lan:host-gateway" \
  --label "traefik.enable=true" \
  --label "traefik.docker.network=traefik-proxy" \
  --label "traefik.http.routers.plane-api.rule=Host(\`plane.ai-servicers.com\`) && PathPrefix(\`/api\`)" \
  --label "traefik.http.routers.plane-api.entrypoints=websecure" \
  --label "traefik.http.routers.plane-api.tls=true" \
  --label "traefik.http.routers.plane-api.tls.certresolver=letsencrypt" \
  --label "traefik.http.routers.plane-api.service=plane-api-service" \
  --label "traefik.http.routers.plane-api-local.rule=Host(\`plane.linuxserver.lan\`) && PathPrefix(\`/api\`)" \
  --label "traefik.http.routers.plane-api-local.entrypoints=web" \
  --label "traefik.http.routers.plane-api-local.service=plane-api-service" \
  --label "traefik.http.services.plane-api-service.loadbalancer.server.port=8000" \
  makeplane/plane-backend:stable \
  sh -c "python manage.py migrate && gunicorn -w 2 -b 0.0.0.0:8000 --timeout 120 --log-level debug --access-logfile - --error-logfile - plane.wsgi:application"

# Connect API to traefik and redis networks
docker network connect traefik-proxy plane-api 2>/dev/null || echo "plane-api already connected to traefik-proxy"
docker network connect redis-net plane-api 2>/dev/null || echo "plane-api already connected to redis-net"

# Deploy Plane Worker
echo -e "\n${YELLOW}Deploying Plane Worker...${NC}"
docker run -d \
  --name plane-worker \
  --restart unless-stopped \
  --env-file "$SECRETS_FILE" \
  --network plane-internal \
  -v plane-uploads:/code/uploads \
  --add-host="linuxserver.lan:host-gateway" \
  makeplane/plane-backend:stable \
  celery -A plane worker -l info --concurrency=4

# Connect Worker to redis network
docker network connect redis-net plane-worker 2>/dev/null || echo "plane-worker already connected to redis-net"

# Deploy Plane Beat Scheduler
echo -e "\n${YELLOW}Deploying Plane Beat Scheduler...${NC}"
docker run -d \
  --name plane-beat \
  --restart unless-stopped \
  --env-file "$SECRETS_FILE" \
  --network plane-internal \
  --add-host="linuxserver.lan:host-gateway" \
  makeplane/plane-backend:stable \
  celery -A plane beat -l info

# Connect Beat to redis network
docker network connect redis-net plane-beat 2>/dev/null || echo "plane-beat already connected to redis-net"

# Deploy Plane Web Frontend (using deploy image)
echo -e "\n${YELLOW}Deploying Plane Web Frontend...${NC}"
docker run -d \
  --name plane-web \
  --restart unless-stopped \
  --network traefik-proxy \
  --network-alias plane-web \
  -p 3001:3000 \
  -e NEXT_PUBLIC_ENABLE_OAUTH=0 \
  -e NEXT_PUBLIC_DEPLOY_URL=http://linuxserver.lan:3001 \
  -e NEXT_PUBLIC_API_BASE_URL=http://linuxserver.lan:8001 \
  -e NEXT_PUBLIC_LIVE_BASE_URL=http://plane-api:8000 \
  -e NEXT_PUBLIC_GOD_MODE=1 \
  -e HOSTNAME=0.0.0.0 \
  -e NODE_ENV=development \
  -e DEBUG=true \
  --label "traefik.enable=true" \
  --label "traefik.docker.network=traefik-proxy" \
  --label "traefik.http.routers.plane.rule=Host(\`plane.ai-servicers.com\`)" \
  --label "traefik.http.routers.plane.entrypoints=websecure" \
  --label "traefik.http.routers.plane.tls=true" \
  --label "traefik.http.routers.plane.tls.certresolver=letsencrypt" \
  --label "traefik.http.routers.plane.service=plane-service" \
  --label "traefik.http.routers.plane-local.rule=Host(\`plane.linuxserver.lan\`)" \
  --label "traefik.http.routers.plane-local.entrypoints=web" \
  --label "traefik.http.routers.plane-local.service=plane-service" \
  --label "traefik.http.services.plane-service.loadbalancer.server.port=3000" \
  makeplane/plane-frontend:stable

# Connect Web to internal network for API access
docker network connect plane-internal plane-web 2>/dev/null || echo "plane-web already connected to plane-internal"

# Wait for services to start
echo -e "\n${YELLOW}Waiting for services to initialize...${NC}"
sleep 30

# Check service status
echo -e "\n${YELLOW}Checking service status...${NC}"
echo "API:    $(docker ps --filter name=plane-api --format 'table {{.Status}}' | tail -n 1)"
echo "Web:    $(docker ps --filter name=plane-web --format 'table {{.Status}}' | tail -n 1)"
echo "Worker: $(docker ps --filter name=plane-worker --format 'table {{.Status}}' | tail -n 1)"
echo "Beat:   $(docker ps --filter name=plane-beat --format 'table {{.Status}}' | tail -n 1)"

# Display completion message
echo -e "\n${GREEN}========================================${NC}"
echo -e "${GREEN}Deployment Complete!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo -e "Access Plane at: ${YELLOW}https://plane.ai-servicers.com${NC}"
echo ""
echo -e "${YELLOW}Check logs:${NC}"
echo "  docker logs plane-api --tail 50"
echo "  docker logs plane-web --tail 50"
echo "  docker logs plane-worker --tail 50"
echo ""
echo -e "${YELLOW}Next Steps:${NC}"
echo "1. Wait for migrations to complete (check API logs)"
echo "2. Create your first admin user:"
echo "   ${BLUE}./create-admin.sh${NC}"