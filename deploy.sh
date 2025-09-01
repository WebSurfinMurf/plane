#!/bin/bash

# Plane Deployment Script
# Deploys Plane project management platform with Traefik integration

set -e

# Configuration
PROJECT_NAME="plane"
NETWORK="traefik-proxy"
DOMAIN="plane.ai-servicers.com"
SECRETS_FILE="/home/administrator/projects/admin/secrets/plane.env"
DATA_DIR="/home/administrator/projects/data/plane"

# Container names
FRONTEND_CONTAINER="plane-frontend"
BACKEND_CONTAINER="plane-backend"
WORKER_CONTAINER="plane-worker"
BEAT_CONTAINER="plane-beat-worker"
MINIO_CONTAINER="plane-minio"

# Images (using latest stable versions)
FRONTEND_IMAGE="makeplane/plane-frontend:latest"
BACKEND_IMAGE="makeplane/plane-backend:latest"
WORKER_IMAGE="makeplane/plane-backend:latest"
BEAT_IMAGE="makeplane/plane-backend:latest"
MINIO_IMAGE="minio/minio:latest"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Plane Deployment Script${NC}"
echo -e "${BLUE}========================================${NC}"

# Check if secrets file exists
if [ ! -f "$SECRETS_FILE" ]; then
    echo -e "${RED}Error: Secrets file not found at $SECRETS_FILE${NC}"
    echo -e "${YELLOW}Please ensure plane.env exists in the secrets directory${NC}"
    exit 1
fi

# Create data directories
echo -e "\n${YELLOW}Creating data directories...${NC}"
mkdir -p $DATA_DIR/{uploads,logs,minio-data}
chmod -R 755 $DATA_DIR

# Function to stop and remove container if exists
remove_container() {
    local container_name=$1
    if docker ps -a | grep -q $container_name; then
        echo -e "${YELLOW}Removing existing container: $container_name${NC}"
        docker stop $container_name 2>/dev/null || true
        docker rm $container_name 2>/dev/null || true
    fi
}

# Stop and remove existing containers
echo -e "\n${YELLOW}Cleaning up existing containers...${NC}"
remove_container $FRONTEND_CONTAINER
remove_container $BACKEND_CONTAINER
remove_container $WORKER_CONTAINER
remove_container $BEAT_CONTAINER
remove_container $MINIO_CONTAINER

# Pull latest images
echo -e "\n${YELLOW}Pulling latest images...${NC}"
docker pull $FRONTEND_IMAGE
docker pull $BACKEND_IMAGE
docker pull $MINIO_IMAGE

# Deploy MinIO for object storage
echo -e "\n${YELLOW}Deploying MinIO storage...${NC}"
docker run -d \
  --name $MINIO_CONTAINER \
  --network $NETWORK \
  --env-file $SECRETS_FILE \
  -v $DATA_DIR/minio-data:/data \
  --restart unless-stopped \
  $MINIO_IMAGE server /data --console-address ":9001"

# Wait for MinIO to start
echo -e "${YELLOW}Waiting for MinIO to start...${NC}"
sleep 10

# Deploy Backend API
echo -e "\n${YELLOW}Deploying Plane Backend API...${NC}"
docker run -d \
  --name $BACKEND_CONTAINER \
  --network $NETWORK \
  --env-file $SECRETS_FILE \
  -e DJANGO_SETTINGS_MODULE=plane.settings.production \
  -v $DATA_DIR/uploads:/code/uploads \
  -v $DATA_DIR/logs:/code/logs \
  --add-host linuxserver.lan:172.22.0.1 \
  --restart unless-stopped \
  $BACKEND_IMAGE python manage.py runserver 0.0.0.0:8000

# Deploy Worker for background jobs
echo -e "\n${YELLOW}Deploying Plane Worker...${NC}"
docker run -d \
  --name $WORKER_CONTAINER \
  --network $NETWORK \
  --env-file $SECRETS_FILE \
  -e DJANGO_SETTINGS_MODULE=plane.settings.production \
  -v $DATA_DIR/uploads:/code/uploads \
  -v $DATA_DIR/logs:/code/logs \
  --add-host linuxserver.lan:172.22.0.1 \
  --restart unless-stopped \
  $WORKER_IMAGE celery -A plane worker -l info

# Deploy Beat scheduler for cron jobs
echo -e "\n${YELLOW}Deploying Plane Beat Scheduler...${NC}"
docker run -d \
  --name $BEAT_CONTAINER \
  --network $NETWORK \
  --env-file $SECRETS_FILE \
  -e DJANGO_SETTINGS_MODULE=plane.settings.production \
  --add-host linuxserver.lan:172.22.0.1 \
  --restart unless-stopped \
  $BEAT_IMAGE celery -A plane beat -l info

# Deploy Frontend with Traefik labels
echo -e "\n${YELLOW}Deploying Plane Frontend...${NC}"
docker run -d \
  --name $FRONTEND_CONTAINER \
  --network $NETWORK \
  --env-file $SECRETS_FILE \
  -e NEXT_PUBLIC_API_BASE_URL=https://$DOMAIN \
  --label "traefik.enable=true" \
  --label "traefik.docker.network=$NETWORK" \
  --label "traefik.http.routers.$PROJECT_NAME.rule=Host(\`$DOMAIN\`)" \
  --label "traefik.http.routers.$PROJECT_NAME.entrypoints=websecure" \
  --label "traefik.http.routers.$PROJECT_NAME.tls=true" \
  --label "traefik.http.routers.$PROJECT_NAME.tls.certresolver=letsencrypt" \
  --label "traefik.http.services.$PROJECT_NAME.loadbalancer.server.port=3000" \
  --label "traefik.http.routers.$PROJECT_NAME-api.rule=Host(\`$DOMAIN\`) && PathPrefix(\`/api\`)" \
  --label "traefik.http.routers.$PROJECT_NAME-api.entrypoints=websecure" \
  --label "traefik.http.routers.$PROJECT_NAME-api.tls=true" \
  --label "traefik.http.routers.$PROJECT_NAME-api.service=$PROJECT_NAME-api" \
  --label "traefik.http.services.$PROJECT_NAME-api.loadbalancer.server.url=http://$BACKEND_CONTAINER:8000" \
  --label "traefik.http.routers.$PROJECT_NAME.middlewares=$PROJECT_NAME-headers" \
  --label "traefik.http.middlewares.$PROJECT_NAME-headers.headers.stsSeconds=31536000" \
  --label "traefik.http.middlewares.$PROJECT_NAME-headers.headers.stsIncludeSubdomains=true" \
  --label "traefik.http.middlewares.$PROJECT_NAME-headers.headers.stsPreload=true" \
  --restart unless-stopped \
  $FRONTEND_IMAGE

# Wait for services to start
echo -e "\n${YELLOW}Waiting for services to start...${NC}"
sleep 20

# Check container status
echo -e "\n${YELLOW}Checking container status...${NC}"
containers=($FRONTEND_CONTAINER $BACKEND_CONTAINER $WORKER_CONTAINER $BEAT_CONTAINER $MINIO_CONTAINER)
all_running=true

for container in "${containers[@]}"; do
    if docker ps | grep -q $container; then
        echo -e "${GREEN}✓ $container is running${NC}"
    else
        echo -e "${RED}✗ $container failed to start${NC}"
        all_running=false
    fi
done

if [ "$all_running" = false ]; then
    echo -e "\n${RED}Some containers failed to start. Checking logs...${NC}"
    for container in "${containers[@]}"; do
        if ! docker ps | grep -q $container; then
            echo -e "\n${YELLOW}Logs for $container:${NC}"
            docker logs $container --tail 20 2>&1 || echo "Container not found"
        fi
    done
    exit 1
fi

# Display status
echo -e "\n${GREEN}========================================${NC}"
echo -e "${GREEN}Deployment Complete!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo -e "Container Status:"
docker ps --filter name=plane --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
echo ""
echo -e "Access Plane at: ${YELLOW}https://$DOMAIN${NC}"
echo ""
echo -e "${YELLOW}Next Steps:${NC}"
echo "1. Run the setup script to initialize the database:"
echo "   ${BLUE}./setup-database.sh${NC}"
echo ""
echo "2. Create your first workspace and admin user"
echo ""
echo -e "${YELLOW}Useful Commands:${NC}"
echo "  docker logs -f $BACKEND_CONTAINER     # View backend logs"
echo "  docker logs -f $FRONTEND_CONTAINER    # View frontend logs"
echo "  docker logs -f $WORKER_CONTAINER      # View worker logs"
echo "  docker restart plane-*                # Restart all Plane containers"
echo ""
echo -e "${YELLOW}MinIO Console:${NC}"
echo "  URL: http://$(hostname -I | awk '{print $1}'):9001"
echo "  Username: planeadmin"
echo "  Password: Check plane.env file"