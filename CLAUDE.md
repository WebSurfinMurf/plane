# Plane - Modern Project Management Platform

## Current Status: ✅ FULLY DEPLOYED AND OPERATIONAL

**Deployment Status**: Successfully deployed and user logged in
**Last Successful Deployment**: 2025-09-01 03:00
**Architecture**: Traefik → Nginx proxy → Web Frontend + API Backend
**Access URL**: `https://plane.ai-servicers.com/` (external only configuration)
**Admin Login**: Successfully tested and working

## Critical Deployment Facts (Verified)

### 1. Authentication Architecture
**FACT**: Plane frontend makes authentication requests to `/auth/` endpoints
**FACT**: The frontend (Next.js) does NOT proxy backend requests
**FACT**: An nginx proxy is REQUIRED to route `/auth/` and `/api/` to the backend
**FACT**: CSRF tokens are required for authentication - handled automatically by browser
**VERIFIED**: Without nginx proxy, authentication returns 404 errors
**VERIFIED**: Login works with proper CSRF configuration

### 2. Container Networking
**FACT**: Redis runs in a Docker container named `redis` on network `redis-net`
**FACT**: Plane containers MUST use hostname `redis` not `linuxserver.lan` for Redis access
**FACT**: PostgreSQL is accessible via `linuxserver.lan` on port 5432
**FACT**: MinIO is accessible via `linuxserver.lan` on port 9000
**VERIFIED**: Using `linuxserver.lan` for Redis causes connection timeouts

### 3. Environment Variable Behavior
**FACT**: Docker `restart` does NOT reload environment variables
**FACT**: Containers must be removed and recreated to pick up env file changes
**FACT**: The env file is at `/home/administrator/projects/admin/secrets/plane.env`
**VERIFIED**: Changed env vars require container recreation, not restart

### 4. Network Configuration
**FACT**: Plane services use multiple Docker networks:
- `plane-internal`: For inter-service communication
- `redis-net`: For Redis access
- `traefik-proxy`: For external access via Traefik
**FACT**: Traefik requires containers to be on `traefik-proxy` network
**VERIFIED**: Traefik defaults to wrong network if not properly configured

### 5. User Authentication
**FACT**: Admin user created with email `mmurphyemail@gmail.com`
**FACT**: Password is `Admin123!`
**FACT**: Local authentication is enabled (`ENABLE_EMAIL_PASSWORD=1`)
**FACT**: Keycloak/SSO is NOT configured (future enhancement)
**VERIFIED**: User successfully logged in via https://plane.ai-servicers.com/

### 6. URL Configuration for External-Only Access
**FACT**: All `NEXT_PUBLIC_*` environment variables are used by browser JavaScript
**FACT**: These URLs MUST be accessible from the user's browser
**FACT**: For external-only access, all URLs should use `https://plane.ai-servicers.com`
**CRITICAL**: `NEXT_PUBLIC_LIVE_BASE_URL` must be external URL, not internal Docker hostname
**VERIFIED**: Configuration works with all URLs pointing to external domain

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

### Critical Environment Variables

**Frontend (plane-web)**:
```bash
NEXT_PUBLIC_DEPLOY_URL=https://plane.ai-servicers.com
NEXT_PUBLIC_API_BASE_URL=https://plane.ai-servicers.com
NEXT_PUBLIC_LIVE_BASE_URL=https://plane.ai-servicers.com
```

**Backend (plane-api)**:
```bash
WEB_URL=https://plane.ai-servicers.com
CORS_ALLOWED_ORIGINS=https://plane.ai-servicers.com
CSRF_TRUSTED_ORIGINS=https://plane.ai-servicers.com
```

**Redis** (MUST use container hostname):
```bash
REDIS_HOST=redis  # NOT linuxserver.lan!
REDIS_URL=redis://:password@redis:6379/3
```

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

## Technical Implementation Details

### Container Architecture
```
Internet → Traefik (443/80) → plane-proxy (nginx:3001)
                                    ├→ plane-web (Next.js:3000)
                                    └→ plane-api (Django:8000)
                                          ├→ PostgreSQL (5432)
                                          ├→ Redis (6379)
                                          └→ MinIO (9000)
                                    
plane-worker (Celery) → Redis
plane-beat (Scheduler) → Redis
```

### Nginx Proxy Routes
- `/` → `http://plane-web:3000` (Frontend)
- `/api/` → `http://plane-api:8000/api/` (API endpoints)
- `/auth/` → `http://plane-api:8000/auth/` (Authentication)
- `/spaces/` → `http://plane-api:8000/spaces/` (Spaces feature)

### Docker Networks
- `traefik-proxy`: External access, Traefik routing
- `plane-internal`: Inter-service communication
- `redis-net`: Redis access for all services

### Port Mappings
- 3001 → 80 (nginx proxy)
- 8001 → 8000 (API direct access)
- No external port for plane-web (accessed via proxy only)

## Files Created

### Active Scripts
- `/home/administrator/projects/plane/deploy-direct.sh` - ✅ **PRODUCTION** deployment script with external-only configuration
- `/home/administrator/projects/plane/create-admin.sh` - ✅ Admin user creation script

### Configuration
- `/home/administrator/projects/admin/secrets/plane.env` - Environment variables (external-only URLs)
- `/home/administrator/projects/plane/CLAUDE.md` - This comprehensive documentation
- `/tmp/plane-nginx.conf` - Nginx proxy configuration (auto-generated during deployment)

### Deprecated Files
- `/home/administrator/projects/plane/deploy.sh` - Original script (obsolete)
- `/home/administrator/projects/plane/deploy-compose.sh` - Docker Compose version (not used)
- `/home/administrator/projects/plane/docker-compose.yml` - Docker Compose config (not used)
- `/home/administrator/projects/plane/nginx.conf` - Old nginx config (replaced by inline)
- `/home/administrator/projects/plane/workernotes.md` - Troubleshooting notes (incorporated here)

## Notes

- Plane is actively developed with frequent updates
- Community Edition is fully featured including SSO
- Can be scaled horizontally by adding more workers
- Supports multiple workspaces in a single installation
- **Successfully Deployed**: 2025-08-31
- **Using**: stable image versions (not latest) for better stability
- **MinIO**: Connected to central MinIO service with dedicated service account

## Lessons Learned During Deployment

### 1. Authentication Flow Discovery
**PROBLEM**: Users could not log in - entering email did nothing
**ROOT CAUSE**: Frontend calls `/auth/email-check/` on its own port, not API port
**SOLUTION**: Nginx proxy required to route `/auth/*` requests to API backend
**LEARNING**: Plane's architecture assumes a reverse proxy for routing

### 2. Redis Connection Issues
**PROBLEM**: Worker showed "Cannot connect to redis://:**@linuxserver.lan:6379/3"
**ROOT CAUSE**: Redis runs in Docker container, not on host
**SOLUTION**: Use container name `redis` instead of `linuxserver.lan`
**LEARNING**: Container-to-container communication uses Docker network DNS

### 3. CSRF Token Failures
**PROBLEM**: "CSRF Verification Failed" after entering password
**ROOT CAUSE**: Django CSRF protection with proxy configuration
**SOLUTION**: Added `CSRF_TRUSTED_ORIGINS` to environment
**LEARNING**: Proxied Django apps need explicit trusted origins

### 4. Traefik Routing Issues
**PROBLEM**: plane.linuxserver.lan and plane.ai-servicers.com stopped working
**ROOT CAUSE**: Traefik couldn't find containers on correct network
**SOLUTION**: Ensure proxy container starts on `traefik-proxy` network
**LEARNING**: Docker network order matters for Traefik discovery

### 5. URL Configuration Confusion
**PROBLEM**: CSRF failures when switching between internal/external URLs
**ROOT CAUSE**: Mixed URL configuration (some internal, some external)
**SOLUTION**: Configure for external-only access with all URLs pointing to `https://plane.ai-servicers.com`
**LEARNING**: `NEXT_PUBLIC_*` variables are used by browser, must be externally accessible

## Assumptions Made

### Current Assumptions
1. **ASSUMPTION**: Users will access Plane via the configured domains
2. **ASSUMPTION**: PostgreSQL and Redis will remain available on current hosts
3. **ASSUMPTION**: MinIO central service will remain stable
4. **ASSUMPTION**: Current resource allocation (2 workers, 4 concurrency) is sufficient
5. **ASSUMPTION**: Email notifications are not required (SMTP not configured)

### Unverified Assumptions
1. **UNTESTED**: Performance under load with multiple users
2. **UNTESTED**: Backup and restore procedures
3. **UNTESTED**: Upgrade path to newer Plane versions
4. **UNTESTED**: Integration with external authentication providers

## Next Steps

### Immediate (Required for Production)
1. **Change Admin Password**: Current password is `Admin123!` (insecure)
2. **Configure SMTP**: Email notifications currently disabled
3. **SSL Certificate**: Ensure Let's Encrypt renewal is automated
4. **Backup Strategy**: Implement PostgreSQL and MinIO backup procedures

### Short Term Enhancements
1. **Keycloak Integration**: Configure SSO for centralized authentication
2. **Resource Monitoring**: Add Prometheus metrics for Plane services
3. **Log Aggregation**: Centralize logs from all Plane containers
4. **Health Checks**: Implement proper health check endpoints

### Long Term Improvements
1. **High Availability**: Deploy multiple API/Worker instances
2. **Database Replication**: Set up PostgreSQL streaming replication
3. **CDN Integration**: Serve static assets via CDN
4. **Kubernetes Migration**: Move from Docker to K8s for orchestration

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
# Deploy/redeploy Plane (ALWAYS use the script!)
cd /home/administrator/projects/plane
./deploy-direct.sh

# Check status
docker ps | grep plane

# View logs
docker logs plane-api --tail 50
docker logs plane-web --tail 50
docker logs plane-proxy --tail 50
docker logs plane-worker --tail 50
docker logs plane-beat --tail 50

# Verify environment variables
docker exec plane-web env | grep NEXT_PUBLIC
docker exec plane-api env | grep -E "CSRF|CORS|WEB_URL"
docker exec plane-worker env | grep REDIS

# Create admin user (if needed)
./create-admin.sh
```

## Working Configuration Summary

**Key Requirements for Successful Deployment**:
1. Use `deploy-direct.sh` script - NEVER run docker commands directly
2. All `NEXT_PUBLIC_*` URLs must point to `https://plane.ai-servicers.com`
3. Redis hostname must be `redis` (container name), not `linuxserver.lan`
4. CSRF_TRUSTED_ORIGINS must include `https://plane.ai-servicers.com`
5. Nginx proxy is REQUIRED to route `/auth/` and `/api/` to backend
6. Container recreation (not restart) required for env variable changes

## Troubleshooting Guide

### Problem: Cannot log in - email submission does nothing
**Check**: `curl -X POST http://plane.linuxserver.lan/auth/email-check/ -H "Content-Type: application/json" -d '{"email":"test@example.com"}'`
**Expected**: JSON response, not 404
**Fix**: Ensure nginx proxy is running and routing `/auth/` to API

### Problem: Worker timeout errors
**Check**: `docker logs plane-worker | grep "Cannot connect"`
**Fix**: Verify Redis connection using container name `redis`
**Verify**: `docker exec plane-worker nc -zv redis 6379`

### Problem: 504 Gateway Timeout
**Check**: `docker ps | grep plane`
**Fix**: Ensure all containers are running, especially plane-proxy
**Verify**: `docker exec plane-proxy curl -I http://plane-web:3000`

### Problem: CSRF verification failed
**Check**: `docker exec plane-api env | grep CSRF`
**Fix**: Add your domain to CSRF_TRUSTED_ORIGINS in env file
**Note**: Must recreate container after env changes

### Problem: "Plane didn't start up" error
**Check**: `curl http://linuxserver.lan:8001/api/instances/`
**Fix**: Ensure API is accessible and returning 200 OK
**Verify**: Database migrations completed successfully