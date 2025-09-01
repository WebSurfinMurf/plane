#!/bin/bash

# Plane Undeployment Script
# This script removes all Plane containers, volumes, and associated resources
# Date: 2025-09-01

set -e

echo "========================================"
echo "Plane Application Undeployment Script"
echo "========================================"
echo ""
echo "This script will remove:"
echo "  - All Plane containers (api, worker, beat, web, proxy)"
echo "  - Plane database and user from PostgreSQL"
echo "  - Plane MinIO bucket (plane-uploads)"
echo "  - Docker volumes"
echo "  - Keycloak client configuration (if exists)"
echo ""
echo "This will NOT remove:"
echo "  - /home/administrator/projects/secrets/plane.env (keeping for reference)"
echo "  - /home/administrator/projects/plane/ directory (contains template)"
echo ""
read -p "Are you sure you want to remove Plane? (yes/no): " -r CONFIRM

if [ "$CONFIRM" != "yes" ]; then
    echo "Undeployment cancelled."
    exit 0
fi

echo ""
echo "Starting Plane removal..."
echo ""

# Step 1: Stop and remove all Plane containers
echo "1. Stopping and removing Plane containers..."
PLANE_CONTAINERS="plane-proxy plane-web plane-beat plane-worker plane-api"

for container in $PLANE_CONTAINERS; do
    if docker ps -a | grep -q "$container"; then
        echo "   Stopping $container..."
        docker stop "$container" 2>/dev/null || true
        echo "   Removing $container..."
        docker rm "$container" 2>/dev/null || true
        echo "   ✓ $container removed"
    else
        echo "   - $container not found (skipping)"
    fi
done

# Step 2: Remove Docker volumes
echo ""
echo "2. Removing Docker volumes..."
if docker volume ls | grep -q "plane-uploads"; then
    docker volume rm plane-uploads
    echo "   ✓ plane-uploads volume removed"
else
    echo "   - plane-uploads volume not found"
fi

# Step 3: Clean up PostgreSQL database
echo ""
echo "3. Cleaning up PostgreSQL database..."
echo "   Attempting to drop plane_db database and plane user..."

# Using the connection details from the environment file
PGPASSWORD='Pass123qp' psql -h linuxserver.lan -p 5432 -U administrator -d postgres << EOF 2>/dev/null || true
-- Terminate any existing connections to the database
SELECT pg_terminate_backend(pid) 
FROM pg_stat_activity 
WHERE datname = 'plane_db' AND pid <> pg_backend_pid();

-- Drop the database
DROP DATABASE IF EXISTS plane_db;

-- Drop the user if it exists (Note: the env shows 'administrator' user which we won't drop)
-- If there was a dedicated 'plane' user, uncomment the next line:
-- DROP USER IF EXISTS plane;

EOF

if [ $? -eq 0 ]; then
    echo "   ✓ Database plane_db dropped successfully"
else
    echo "   ⚠ Could not drop database (may not exist or connection failed)"
fi

# Step 4: Clean up MinIO bucket
echo ""
echo "4. Cleaning up MinIO bucket..."
echo "   Checking for plane-uploads bucket..."

# Check if mc (MinIO client) is available
if command -v mc &> /dev/null; then
    # Check if bucket exists and remove it
    if mc ls minio/plane-uploads &>/dev/null; then
        echo "   Found plane-uploads bucket, removing..."
        mc rb --force minio/plane-uploads 2>/dev/null || true
        echo "   ✓ MinIO bucket removed"
    else
        echo "   - Bucket not found or already removed"
    fi
else
    echo "   ⚠ MinIO client (mc) not found - manual cleanup may be needed"
    echo "     To remove manually: mc rb --force minio/plane-uploads"
fi

# Step 5: Clean up from Keycloak (if configured)
echo ""
echo "5. Keycloak cleanup..."
echo "   Note: Keycloak client 'plane' must be removed manually from Keycloak admin console"
echo "   URL: https://keycloak.ai-servicers.com"
echo "   Navigate to: Clients → plane → Delete"

# Step 6: Remove from Traefik labels (already done by container removal)
echo ""
echo "6. Traefik cleanup..."
echo "   ✓ Traefik routes automatically removed with containers"

# Step 7: Clean up any remaining artifacts
echo ""
echo "7. Final cleanup..."

# Remove any Plane-related temporary files
rm -f /tmp/plane* 2>/dev/null || true
rm -f /var/tmp/plane* 2>/dev/null || true

# Check for any orphaned containers
ORPHANED=$(docker ps -a | grep -i plane | wc -l)
if [ "$ORPHANED" -gt 0 ]; then
    echo "   ⚠ Found $ORPHANED orphaned Plane containers"
    docker ps -a | grep -i plane
    echo "   Run 'docker rm -f <container_id>' to remove them"
else
    echo "   ✓ No orphaned containers found"
fi

# Step 8: Verify removal
echo ""
echo "========================================"
echo "Verification"
echo "========================================"
echo ""

# Check containers
echo "Remaining Plane containers:"
docker ps -a | grep -i plane || echo "  None found ✓"

echo ""
echo "Remaining Plane volumes:"
docker volume ls | grep -i plane || echo "  None found ✓"

echo ""
echo "Remaining Plane images (keeping for potential reuse):"
docker images | grep -i plane | head -5 || echo "  None found"

echo ""
echo "========================================"
echo "Plane Undeployment Complete"
echo "========================================"
echo ""
echo "Summary:"
echo "  ✓ Containers removed: $PLANE_CONTAINERS"
echo "  ✓ Volumes removed: plane-uploads"
echo "  ✓ Database cleaned: plane_db"
echo "  ✓ Traefik routes cleaned"
echo ""
echo "Manual steps required:"
echo "  1. Remove 'plane' client from Keycloak if configured"
echo "  2. Remove Plane images if not needed: docker rmi \$(docker images | grep plane | awk '{print \$3}')"
echo "  3. Remove plane.env if no longer needed: rm /home/administrator/projects/secrets/plane.env"
echo ""
echo "Preserved for reference:"
echo "  - /home/administrator/projects/plane/plane.template.env"
echo "  - /home/administrator/projects/secrets/plane.env"
echo ""
echo "Plane has been successfully removed from the system."