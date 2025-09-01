# Plane Worker Redis Connection Issue - Detailed Investigation

## Issue Summary
Plane-worker shows Redis connection errors: `Cannot connect to redis://:**@linuxserver.lan:6379/3: Timeout connecting to server`

## Systematic Investigation Results

### Step 1: Environment Variable Check
**Command**: `docker exec plane-worker env | grep -E "REDIS|AMQP"`
**Finding**: Worker container has OLD environment variables:
```
REDIS_HOST=linuxserver.lan
REDIS_URL=redis://:rvSqetVQklW4AjSpxk4vX5vvc@linuxserver.lan:6379/3
```
**Status**: ❌ INCORRECT - Should be using 'redis' not 'linuxserver.lan'

### Step 2: Configuration File Check
**Command**: `grep -E "REDIS|AMQP" /home/administrator/projects/admin/secrets/plane.env`
**Finding**: Config file HAS been updated correctly:
```
REDIS_HOST=redis
REDIS_URL=redis://:rvSqetVQklW4AjSpxk4vX5vvc@redis:6379/3
```
**Status**: ✅ CORRECT

### Step 3: Container Creation Timeline
**Command**: `docker inspect plane-worker --format='{{.Created}}'`
**Finding**: 
- Container created: 2025-08-31T23:55:35Z
- Env file modified: 2025-08-31 20:12:21 EDT (00:12:21 UTC)
- Container was created AFTER env file change but still has old values
**Status**: ❌ Container has stale environment despite being created after config change

### Step 4: Network Connectivity Tests

#### Test 4a: DNS Resolution
**Command**: `docker exec plane-worker ping -c 1 linuxserver.lan`
**Result**: Resolves to 172.17.0.1 (Docker bridge)
**Status**: ✅ DNS works

#### Test 4b: Port Connectivity to linuxserver.lan
**Command**: `docker exec plane-worker nc -zv linuxserver.lan 6379 -w 2`
**Result**: Operation timed out
**Status**: ❌ CANNOT connect to linuxserver.lan:6379

#### Test 4c: Port Connectivity to redis container
**Command**: `docker exec plane-worker nc -zv redis 6379 -w 2`
**Result**: redis (172.30.0.2:6379) open
**Status**: ✅ CAN connect to redis:6379

### Step 5: Network Configuration
**Command**: `docker inspect plane-worker --format='{{range $key, $value := .NetworkSettings.Networks}}{{$key}} {{end}}'`
**Finding**: Worker is connected to: `plane-internal redis-net`
**Status**: ✅ Connected to correct networks

### Step 6: Redis Server Check
**Command**: `docker exec redis redis-cli -a rvSqetVQklW4AjSpxk4vX5vvc ping`
**Result**: PONG
**Status**: ✅ Redis is running and password is correct

### Step 7: Manual Connection Test
**Command**: `docker exec plane-worker python -c "import redis; r = redis.Redis(host='redis', ...); print(r.ping())"`
**Result**: Redis test: True
**Status**: ✅ Worker CAN connect to Redis when using 'redis' hostname

### Step 8: Port Conflict Check
**Command**: `netstat -tlnp | grep -E "6379|8001|3001"`
**Finding**: 
- 6379: Redis container
- 8001: plane-api
- 3001: plane-web
**Status**: ✅ No port conflicts

## Root Cause Analysis

### THE PROBLEM:
1. Container environment variables are baked in at container creation time
2. Even though we updated the env file, the running container still has OLD environment variables
3. `docker restart` does NOT reload environment variables
4. Worker is trying to connect to `linuxserver.lan:6379` which is not accessible from Docker containers
5. Redis is actually accessible via `redis:6379` on the redis-net network

### Why linuxserver.lan:6379 doesn't work:
- Redis is running in a Docker container, not directly on the host
- The Redis container exposes port 6379 to the host
- From inside Docker containers, `linuxserver.lan` resolves to 172.17.0.1 (Docker bridge)
- Docker bridge doesn't forward ports between containers
- Must use container-to-container networking via docker networks

## Solution Required

### Option 1: Recreate containers with new environment
```bash
docker stop plane-worker plane-beat plane-api
docker rm plane-worker plane-beat plane-api
./deploy-direct.sh  # This will recreate with new env values
```

### Option 2: Override environment at runtime
```bash
docker stop plane-worker
docker rm plane-worker
docker run -d \
  --name plane-worker \
  --env-file "/home/administrator/projects/admin/secrets/plane.env" \
  ... (rest of the command)
```

## Current State
- ❌ Worker has wrong Redis URL in environment
- ✅ Worker is connected to redis-net network
- ✅ Redis is accessible via 'redis' hostname
- ✅ Configuration file is correct
- ❌ Running containers need to be recreated to pick up new config

## Next Steps
1. Stop and remove existing containers
2. Redeploy using deploy-direct.sh
3. Verify new containers have correct environment variables
4. Confirm Redis connectivity works