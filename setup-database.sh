#!/bin/bash

# Plane Database Setup Script
# Creates PostgreSQL database for Plane

set -e

# Configuration
DB_HOST="linuxserver.lan"
DB_PORT="5432"
DB_NAME="plane_db"
DB_USER="administrator"  # Using existing administrator user
DB_PASSWORD="Pass123qp"
ADMIN_USER="administrator"
ADMIN_PASSWORD="Pass123qp"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Plane Database Setup Script${NC}"
echo -e "${BLUE}========================================${NC}"

# Function to execute PostgreSQL commands
execute_psql() {
    local command=$1
    PGPASSWORD=$ADMIN_PASSWORD psql -h $DB_HOST -p $DB_PORT -U $ADMIN_USER -d postgres -c "$command"
}

# Check if database already exists
echo -e "\n${YELLOW}Checking if database exists...${NC}"
if PGPASSWORD=$ADMIN_PASSWORD psql -h $DB_HOST -p $DB_PORT -U $ADMIN_USER -d postgres -lqt | cut -d \| -f 1 | grep -qw $DB_NAME; then
    echo -e "${GREEN}✓ Database '$DB_NAME' already exists${NC}"
    
    # Ask user if they want to drop and recreate
    read -p "Do you want to drop and recreate the database? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo -e "${YELLOW}Dropping existing database...${NC}"
        execute_psql "DROP DATABASE IF EXISTS $DB_NAME;"
        
        # Also drop the user if exists
        execute_psql "DROP USER IF EXISTS $DB_USER;"
    else
        echo -e "${YELLOW}Keeping existing database${NC}"
        exit 0
    fi
fi

# Note: Using existing administrator user, no need to create user

# Create database
echo -e "\n${YELLOW}Creating database '$DB_NAME'...${NC}"
execute_psql "CREATE DATABASE $DB_NAME OWNER $DB_USER;"

# Grant all privileges
echo -e "${YELLOW}Granting privileges...${NC}"
execute_psql "GRANT ALL PRIVILEGES ON DATABASE $DB_NAME TO $DB_USER;"

# Connect to the new database and set up extensions
echo -e "${YELLOW}Setting up database extensions...${NC}"
PGPASSWORD=$ADMIN_PASSWORD psql -h $DB_HOST -p $DB_PORT -U $ADMIN_USER -d $DB_NAME <<EOF
-- Enable required extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pg_trgm";
CREATE EXTENSION IF NOT EXISTS "btree_gist";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- Grant schema permissions
GRANT ALL ON SCHEMA public TO $DB_USER;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO $DB_USER;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON SEQUENCES TO $DB_USER;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON FUNCTIONS TO $DB_USER;

-- Set search path
ALTER DATABASE $DB_NAME SET search_path TO public;
EOF

# Test connection with new user
echo -e "\n${YELLOW}Testing connection with new user...${NC}"
if PGPASSWORD=$DB_PASSWORD psql -h $DB_HOST -p $DB_PORT -U $DB_USER -d $DB_NAME -c "SELECT version();" > /dev/null 2>&1; then
    echo -e "${GREEN}✓ Database connection successful${NC}"
else
    echo -e "${RED}✗ Failed to connect with new user${NC}"
    exit 1
fi

# Run database migrations if backend container is running
if docker ps | grep -q plane-backend; then
    echo -e "\n${YELLOW}Running database migrations...${NC}"
    docker exec plane-backend python manage.py migrate
    echo -e "${GREEN}✓ Migrations completed${NC}"
    
    # Create MinIO bucket
    echo -e "\n${YELLOW}Creating MinIO bucket...${NC}"
    docker exec plane-backend python manage.py create_bucket || true
    
    # Collect static files
    echo -e "${YELLOW}Collecting static files...${NC}"
    docker exec plane-backend python manage.py collectstatic --noinput || true
else
    echo -e "\n${YELLOW}Backend container not running. Please run deploy.sh first, then run this script again.${NC}"
fi

echo -e "\n${GREEN}========================================${NC}"
echo -e "${GREEN}Database Setup Complete!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo -e "Database Details:"
echo -e "  Host:     ${BLUE}$DB_HOST${NC}"
echo -e "  Port:     ${BLUE}$DB_PORT${NC}"
echo -e "  Database: ${BLUE}$DB_NAME${NC}"
echo -e "  User:     ${BLUE}$DB_USER${NC}"
echo ""
echo -e "${YELLOW}Next Steps:${NC}"
echo "1. If not already done, run the deployment:"
echo "   ${BLUE}./deploy.sh${NC}"
echo ""
echo "2. Create your first admin user:"
echo "   ${BLUE}./create-admin.sh${NC}"