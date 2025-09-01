# Plane - Modern Project Management Platform

## Current Status: ✅ DEPLOYED - All Services Running

**Deployment Status**: Successfully deployed with all services operational
**MinIO**: Connected to central MinIO service at linuxserver.lan:9000
**Redis**: Connected via `redis` hostname (container-to-container networking)
**Last Deployment**: 2025-09-01 00:27
**Access URLs**:
- Web Interface: `http://localhost:3001` or `http://linuxserver.lan:3001`
- API: `http://localhost:8001` or `http://linuxserver.lan:8001`

## Project Overview
Plane is an open-source project management tool that serves as an alternative to Jira and Linear. It offers a modern, clean interface with powerful features for agile project management.

**Key Features:**
- Issues tracking with custom fields and states
- Cycles (Sprints) management
- Modules for feature grouping
- Project pages for documentation
- Analytics and insights
- **Free OIDC/OAuth support** (including Keycloak)

## Architecture

Plane consists of multiple services:
- **Frontend (Web)**: Next.js application
- **Backend (API)**: Django REST API
- **Worker**: Background job processor (Celery)
- **Beat Scheduler**: Cron job scheduler
- **Database**: PostgreSQL
- **Cache/Queue**: Redis
- **Object Storage**: MinIO or S3-compatible storage

## Installation Plan

### Phase 1: Infrastructure Preparation
1. Create PostgreSQL database and user
2. Configure Redis database allocation
3. Set up data directories for uploads and storage

### Phase 2: Core Services Deployment
1. Deploy Plane API service
2. Deploy Plane Web frontend
3. Deploy Worker service for background jobs
4. Deploy Beat scheduler for cron tasks
5. Deploy MinIO for object storage (or use existing S3)

### Phase 3: Traefik Integration
1. Configure routing for web interface
2. Set up API endpoint routing
3. Configure WebSocket support for real-time updates

### Phase 4: Initial Configuration
1. Run database migrations
2. Create superuser account
3. Configure workspace settings
4. Set up email configuration (optional)

### Phase 5: Keycloak Integration (Later)
1. Configure OIDC provider settings
2. Set up group mappings
3. Test SSO authentication

## Resource Requirements

### Minimum Requirements
- **CPU**: 2 cores
- **RAM**: 4GB
- **Storage**: 10GB for application + data

### Services to Deploy
- plane-frontend (Next.js)
- plane-backend (Django API)
- plane-worker (Celery worker)
- plane-beat-worker (Scheduler)
- plane-minio (Object storage) - optional if using external S3

## Using Existing Infrastructure

### PostgreSQL ✅ READY
- **Host**: linuxserver.lan
- **Port**: 5432
- **Database**: plane_db (CREATED)
- **User**: administrator (using existing user)
- **Password**: Pass123qp

### Redis ✅ READY
- **Host**: redis (container name when accessing from Docker containers)
- **Port**: 6379
- **Database**: 3 (dedicated for Plane)
- **Password**: rvSqetVQklW4AjSpxk4vX5vvc
- **CRITICAL**: Plane containers MUST use hostname `redis` not `linuxserver.lan`
- **Network**: All Plane containers must be connected to `redis-net` network

### MinIO ⚠️ REQUIRED
- **Status**: Not yet deployed as central service
- **Requirement**: Should be deployed like PostgreSQL/Redis for shared use
- **Current Plan**: Deploy MinIO separately, then resume Plane deployment

### Traefik
- **Domain**: plane.ai-servicers.com
- **Network**: traefik-proxy
- **HTTPS**: Via Let's Encrypt

## Environment Configuration

Key environment variables needed:
- Database connection strings
- Redis configuration
- Secret keys for Django
- JWT secrets
- Storage configuration
- Email settings (optional)

## Deployment Strategy

Using Docker Compose for orchestration:
1. Single `docker-compose.yml` for all services
2. External networks for Traefik integration
3. Named volumes for persistent data
4. Health checks for service reliability

## Security Considerations

1. **Secrets Management**: All sensitive data in `/home/administrator/projects/admin/secrets/plane.env`
2. **Network Isolation**: Internal services on private networks
3. **HTTPS Only**: Enforced via Traefik
4. **Database Security**: Dedicated user with minimal privileges
5. **File Uploads**: Stored in MinIO with access controls

## Backup Strategy

Critical data to backup:
- PostgreSQL database (plane_db)
- Uploaded files in MinIO/storage
- Environment configuration
- User-generated content

## Monitoring Points

- API response times
- Worker queue length
- Database connections
- Storage usage
- Error rates in logs

## Migration from Other Tools

Plane supports importing from:
- GitHub Issues
- Jira
- Linear
- Trello (via CSV)

## Current Deployment Status

### Completed Steps
1. ✅ Created project directory structure
2. ✅ Generated environment configuration (`/home/administrator/projects/admin/secrets/plane.env`)
3. ✅ Created PostgreSQL database `plane_db`
4. ✅ Set up database extensions and permissions
5. ✅ Created deployment scripts:
   - `deploy.sh` - Initial deployment script (needs fixes)
   - `deploy-compose.sh` - Docker Compose based deployment
   - `setup-database.sh` - Database initialization
   - `create-admin.sh` - Admin user creation

### Discovered Issues
1. **Container Commands**: Plane images don't include `/bin/takeoff` or similar scripts
   - Backend needs: `python manage.py runserver` or `gunicorn`
   - Worker needs: `celery -A plane worker`
   - Beat needs: `celery -A plane beat`

2. **Image Versions**: Using `makeplane/plane-*:latest` instead of `:stable`

3. **MinIO Dependency**: Plane requires object storage for file uploads
   - Should be deployed as central service
   - Similar to how PostgreSQL and Redis are shared

### Next Steps
1. **Deploy MinIO as central service** (separate project)
2. Update Plane configuration to use central MinIO
3. Resume Plane deployment using docker-compose
4. Run database migrations
5. Create admin user
6. Configure Keycloak integration (later phase)

## Post-Installation Tasks

1. Configure workspace settings
2. Set up projects and teams
3. Define issue types and workflows
4. Configure integrations (GitHub, Slack, etc.)
5. Import existing data if migrating

## Useful Resources

- **Official Docs**: https://docs.plane.so
- **GitHub**: https://github.com/makeplane/plane
- **Docker Hub**: https://hub.docker.com/u/makeplane
- **Community**: https://discord.com/invite/A92xrEGCge

## MinIO Central Service Requirements

### Why Central MinIO?
- Multiple applications need object storage (Plane, potentially others)
- Better resource utilization with shared service
- Centralized backup and management
- Consistent S3-compatible API for all applications

### MinIO Deployment Plan
1. Deploy MinIO on linuxserver.lan (like PostgreSQL/Redis)
2. Create separate buckets for each application
3. Use IAM policies for access control
4. Configure with Traefik for web console access

### MinIO Configuration for Plane
```env
# Once MinIO is deployed centrally, update plane.env:
USE_MINIO=1
AWS_REGION=us-east-1
AWS_ACCESS_KEY_ID=plane-access-key
AWS_SECRET_ACCESS_KEY=plane-secret-key
AWS_S3_ENDPOINT_URL=http://linuxserver.lan:9000
AWS_S3_BUCKET_NAME=plane-uploads
```

## Files Created

### Scripts
- `/home/administrator/projects/plane/deploy-direct.sh` - ✅ **WORKING** deployment script using stable images
- `/home/administrator/projects/plane/deploy.sh` - Original deployment script (deprecated)
- `/home/administrator/projects/plane/deploy-compose.sh` - Docker Compose deployment (requires docker-compose)
- `/home/administrator/projects/plane/setup-database.sh` - Database setup
- `/home/administrator/projects/plane/create-admin.sh` - Admin user creation
- `/home/administrator/projects/plane/docker-compose.yml` - Docker Compose configuration (updated for central MinIO)

### Configuration
- `/home/administrator/projects/admin/secrets/plane.env` - Environment variables
- `/home/administrator/projects/plane/CLAUDE.md` - This documentation

## Notes

- Plane is actively developed with frequent updates
- Community Edition is fully featured including SSO
- Can be scaled horizontally by adding more workers
- Supports multiple workspaces in a single installation
- **Successfully Deployed**: 2025-08-31
- **Using**: stable image versions (not latest) for better stability
- **MinIO**: Connected to central MinIO service with dedicated service account

## CRITICAL: Plane Worker Redis Configuration

### ⚠️ IMPORTANT - NEVER BREAK THIS AGAIN
1. **Redis Hostname**: Plane containers MUST use `redis` as hostname, NOT `linuxserver.lan`
2. **Environment Variables**: Changes to `/home/administrator/projects/admin/secrets/plane.env` require container RECREATION, not just restart
3. **Docker Restart vs Recreate**: 
   - `docker restart` does NOT reload environment variables
   - Must use `docker rm` then redeploy to pick up new env vars
4. **Network Requirements**: All Plane containers must be connected to `redis-net` network
5. **Verification Command**: Always check with `docker exec plane-worker env | grep REDIS`

### Common Issues and Solutions
- **Worker timeout errors**: Usually Redis connection issues
- **"Cannot connect to redis://...@linuxserver.lan:6379"**: Wrong hostname, should be `redis`
- **Environment not updating**: Containers need recreation, not restart

## Deployment Commands

```bash
# Deploy/redeploy Plane
cd /home/administrator/projects/plane
./deploy-direct.sh

# Check status
docker ps | grep plane

# View logs
docker logs plane-api --tail 50
docker logs plane-web --tail 50
docker logs plane-worker --tail 50

# Verify Redis connection
docker exec plane-worker env | grep REDIS
docker logs plane-worker | grep "Connected to redis"

# Create admin user (after deployment)
./create-admin.sh
```