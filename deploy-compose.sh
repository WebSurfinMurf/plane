#!/bin/bash

# Plane Deployment Script using Docker Compose
# Deploys Plane project management platform

set -e

# Configuration
PROJECT_DIR="/home/administrator/projects/plane"
SECRETS_FILE="/home/administrator/projects/admin/secrets/plane.env"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Plane Docker Compose Deployment${NC}"
echo -e "${BLUE}========================================${NC}"

# Check if secrets file exists
if [ ! -f "$SECRETS_FILE" ]; then
    echo -e "${RED}Error: Secrets file not found at $SECRETS_FILE${NC}"
    exit 1
fi

# Navigate to project directory
cd $PROJECT_DIR

# Stop existing deployment if any
echo -e "\n${YELLOW}Stopping existing deployment...${NC}"
docker-compose down 2>/dev/null || true

# Pull latest images
echo -e "\n${YELLOW}Pulling latest images...${NC}"
docker-compose pull

# Start services
echo -e "\n${YELLOW}Starting Plane services...${NC}"
docker-compose up -d

# Wait for services to start
echo -e "\n${YELLOW}Waiting for services to initialize...${NC}"
sleep 30

# Check service status
echo -e "\n${YELLOW}Checking service status...${NC}"
docker-compose ps

# Run migrations
echo -e "\n${YELLOW}Running database migrations...${NC}"
docker-compose exec -T plane-api python manage.py migrate || echo "Migrations may have already run"

# Create MinIO bucket
echo -e "\n${YELLOW}Setting up MinIO bucket...${NC}"
docker-compose exec -T plane-api python manage.py create_bucket 2>/dev/null || echo "Bucket may already exist"

# Display status
echo -e "\n${GREEN}========================================${NC}"
echo -e "${GREEN}Deployment Complete!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo -e "Service Status:"
docker-compose ps
echo ""
echo -e "Access Plane at: ${YELLOW}https://plane.ai-servicers.com${NC}"
echo ""
echo -e "${YELLOW}MinIO Console:${NC}"
echo "  URL: http://$(hostname -I | awk '{print $1}'):9001"
echo "  Username: planeadmin"
echo "  Password: Check plane.env file"
echo ""
echo -e "${YELLOW}Useful Commands:${NC}"
echo "  docker-compose logs -f          # View all logs"
echo "  docker-compose logs -f plane-api # View API logs"
echo "  docker-compose restart           # Restart all services"
echo "  docker-compose down              # Stop all services"
echo ""
echo -e "${YELLOW}Next Steps:${NC}"
echo "1. Create your first admin user:"
echo "   ${BLUE}./create-admin.sh${NC}"