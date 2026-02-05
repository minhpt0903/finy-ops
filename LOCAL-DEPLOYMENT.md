# Local Deployment Guide (Jenkins + App cùng server)

## 🏗️ Architecture - Simplified

```
┌───────────────────────────────────────────────────┐
│  Single Server (192.168.20.82 hoặc 42.112.38.103) │
│                                                   │
│  ┌─────────────┐         ┌───────────────────┐  │
│  │  Jenkins    │────────▶│  Application      │  │
│  │  Container  │  deploy │  Container        │  │
│  │  Port: 8080 │  local  │  Port: 9200/9201  │  │
│  └─────────────┘         └───────────────────┘  │
│         │                         │              │
│         └──────────┬──────────────┘              │
│                    │                             │
│              Podman Network                      │
│                    │                             │
│         ┌──────────▼──────────┐                 │
│         │  Kafka              │                 │
│         │  Port: 9092         │                 │
│         └─────────────────────┘                 │
└───────────────────────────────────────────────────┘
```

## ✅ Lợi ích của Local Deployment

1. **Không cần SSH** - Deploy trực tiếp
2. **Không cần SCP** - Không transfer images
3. **Nhanh hơn** - Không qua network
4. **Đơn giản hơn** - Ít bước, ít lỗi
5. **Dễ debug** - Logs và status ngay trên server

## 🚀 Setup Instructions

### 1. Cấu trúc thư mục trên server

```bash
/opt/
├── jenkins_home/          # Jenkins data
├── kafka_data/            # Kafka data
├── kafka_logs/            # Kafka logs
└── configs/               # Application configs
    ├── test/
    │   └── application.properties
    └── production/
        └── application.properties
```

### 2. Tạo config directories

```bash
# Tạo directories
sudo mkdir -p /opt/configs/{test,production}
sudo chown -R 1000:1000 /opt/configs

# Copy configs
sudo cp spring-envs/test/application.properties /opt/configs/test/
sudo cp spring-envs/production/application.properties /opt/configs/production/
```

### 3. Start containers với podman-compose

```bash
cd /path/to/finy-ops

# Start Jenkins + Kafka
podman-compose up -d

# Verify containers
podman ps
```

Expected output:
```
CONTAINER ID  IMAGE                       PORTS                   NAMES
abc123...     jenkins/jenkins:lts-jdk17   0.0.0.0:8080->8080/tcp  jenkins
def456...     apache/kafka:3.8.1          0.0.0.0:9092->9092/tcp  kafka
ghi789...     provectuslabs/kafka-ui      0.0.0.0:8090->8090/tcp  kafka-ui
```

### 4. Setup Jenkins

#### A. Truy cập Jenkins UI

```
http://localhost:8080
```

#### B. Unlock Jenkins

```bash
# Get initial admin password
podman exec jenkins cat /var/jenkins_home/secrets/initialAdminPassword
```

#### C. Install Plugins

- Git Plugin
- Pipeline Plugin
- Podman Plugin (optional)
- Credentials Plugin

#### D. Create Pipeline Job

```
Jenkins Dashboard → New Item
Name: lendbiz-apigateway
Type: Pipeline
OK
```

**Configuration:**
```
Pipeline:
  Definition: Pipeline script from SCM
  SCM: Git
    Repository URL: https://your-repo.git
    Credentials: (add git credentials)
    Branch: */main
  Script Path: Jenkinsfile
```

**Save**

## 🎯 Build & Deploy Workflow

### Manual Build trong Jenkins UI

#### 1. Vào Jenkins Job
```
http://localhost:8080/job/lendbiz-apigateway
```

#### 2. Click "Build with Parameters"

#### 3. Select Parameters

**Deploy Test Environment:**
```
ENVIRONMENT: test
GIT_BRANCH: test
SKIP_TESTS: ☐
```
Click **Build** → Deploy to port **9201**

**Deploy Production:**
```
ENVIRONMENT: production
GIT_BRANCH: main
SKIP_TESTS: ☐
```
Click **Build** → Deploy to port **9200**

### What happens during build:

```
1. Jenkins checkout code từ Git
   ↓
2. Build với Gradle (./gradlew clean build)
   ↓
3. Run tests (nếu không skip)
   ↓
4. Build Podman image
   ↓
5. Stop old container (if exists)
   ↓
6. Start new container với configs
   ↓
7. Wait & health check
   ↓
8. ✓ Done! Application running
```

## 🔧 Container Management

### View running containers

```bash
podman ps

# Expect to see:
# - jenkins
# - kafka
# - kafka-ui
# - lendbiz-apigateway-test (nếu đã deploy test)
# - lendbiz-apigateway-production (nếu đã deploy production)
```

### View application logs

```bash
# Test environment logs
podman logs -f lendbiz-apigateway-test

# Production logs
podman logs -f lendbiz-apigateway-production

# Last 100 lines
podman logs --tail 100 lendbiz-apigateway-production
```

### Stop/Start containers

```bash
# Stop application
podman stop lendbiz-apigateway-test

# Start again
podman start lendbiz-apigateway-test

# Restart
podman restart lendbiz-apigateway-test
```

### Check container details

```bash
# Inspect container
podman inspect lendbiz-apigateway-test

# Check resources
podman stats lendbiz-apigateway-test

# Execute command in container
podman exec -it lendbiz-apigateway-test bash
```

## 🔍 Verification & Testing

### 1. Health Checks

```bash
# Test environment (port 9201)
curl http://localhost:9201/actuator/health

# Production environment (port 9200)
curl http://localhost:9200/actuator/health

# Expected response:
{"status":"UP"}
```

### 2. Application Info

```bash
# Test
curl http://localhost:9201/actuator/info

# Production
curl http://localhost:9200/actuator/info
```

### 3. Environment Variables

```bash
# Check env vars in container
podman exec lendbiz-apigateway-test env | grep SPRING

# Should show:
# SPRING_PROFILES_ACTIVE=test
# SPRING_KAFKA_BOOTSTRAP_SERVERS=42.112.38.103:9092
```

### 4. Network Connectivity

```bash
# Check Kafka connectivity from app container
podman exec lendbiz-apigateway-test curl -s kafka:9092

# Check app can access external Kafka
podman exec lendbiz-apigateway-test curl -s 42.112.38.103:9092
```

### 5. Config Files

```bash
# Verify config mounted correctly
podman exec lendbiz-apigateway-test ls -la /config

# View config content
podman exec lendbiz-apigateway-test cat /config/application.properties
```

## 🚨 Troubleshooting

### Issue 1: Container won't start

**Check logs:**
```bash
podman logs lendbiz-apigateway-test

# Common issues:
# - Port already in use
# - Config file not found
# - Database connection failed
```

**Solution:**
```bash
# Check port usage
ss -tulpn | grep 9201

# Kill process using port
sudo fuser -k 9201/tcp

# Rebuild and restart
podman stop lendbiz-apigateway-test
podman rm lendbiz-apigateway-test
# Then build again in Jenkins
```

### Issue 2: Health check fails

**Symptom:**
```bash
curl http://localhost:9201/actuator/health
# Connection refused or 404
```

**Debug:**
```bash
# Check if container is running
podman ps | grep lendbiz-apigateway-test

# Check app logs
podman logs --tail 50 lendbiz-apigateway-test

# Check if Spring Boot started
podman logs lendbiz-apigateway-test | grep "Started"
# Should see: "Started Application in X.XXX seconds"
```

**Common causes:**
- Application still starting up (wait 30s)
- Wrong Spring profile loaded
- Database connection failed
- Port binding failed

### Issue 3: Old container still running

**Symptom:**
```bash
Error: name "lendbiz-apigateway-test" is already in use
```

**Solution:**
```bash
# Force stop and remove
podman stop lendbiz-apigateway-test --force
podman rm lendbiz-apigateway-test --force

# Then deploy again
```

### Issue 4: Config not loaded

**Symptom:** Application using wrong database or settings

**Check:**
```bash
# Verify config mount
podman inspect lendbiz-apigateway-test | grep -A 10 Mounts

# Should show: /opt/configs/test:/config:ro

# Check config content
podman exec lendbiz-apigateway-test cat /config/application.properties
```

**Solution:**
```bash
# Recreate config
sudo cp spring-envs/test/application.properties /opt/configs/test/
sudo chown 1000:1000 /opt/configs/test/application.properties
sudo chmod 644 /opt/configs/test/application.properties

# Restart container
podman restart lendbiz-apigateway-test
```

### Issue 5: Podman network issues

**Symptom:** Container can't connect to Kafka or other containers

**Debug:**
```bash
# Check network
podman network ls

# Inspect network
podman network inspect podman

# Check which containers in network
podman ps --format "{{.Names}}\t{{.Networks}}"
```

**Solution:**
```bash
# Recreate network (if needed)
podman network rm podman
podman network create podman

# Restart all containers
podman stop jenkins kafka kafka-ui
podman start jenkins kafka kafka-ui
```

### Issue 6: Jenkins can't access Podman

**Symptom:**
```
podman: command not found
```

**Solution:**

Check if Jenkins runs as correct user:
```bash
# Option 1: Jenkins with rootless Podman
# Add Jenkins user to correct permissions
sudo usermod -aG users jenkins

# Option 2: Jenkins as root (not recommended)
# Or configure Jenkins to use sudo
```

In Jenkinsfile, might need:
```groovy
sh "sudo podman stop ${containerName}"
```

## 📊 Monitoring

### Real-time monitoring script

Create `/opt/scripts/monitor.sh`:

```bash
#!/bin/bash
# monitor.sh - Monitor all containers

while true; do
    clear
    echo "=== Container Status ==="
    podman ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
    
    echo -e "\n=== Resource Usage ==="
    podman stats --no-stream --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}"
    
    echo -e "\n=== Health Checks ==="
    for env in test production; do
        container="lendbiz-apigateway-$env"
        if podman ps --format "{{.Names}}" | grep -q "$container"; then
            port=$([ "$env" = "test" ] && echo 9201 || echo 9200)
            health=$(curl -sf http://localhost:$port/actuator/health 2>/dev/null)
            if [ $? -eq 0 ]; then
                echo "✓ $env ($port): UP"
            else
                echo "✗ $env ($port): DOWN"
            fi
        fi
    done
    
    sleep 5
done
```

Run it:
```bash
chmod +x /opt/scripts/monitor.sh
/opt/scripts/monitor.sh
```

### Log aggregation

```bash
# View all application logs together
podman logs -f lendbiz-apigateway-test 2>&1 | tee -a /var/log/app-test.log &
podman logs -f lendbiz-apigateway-production 2>&1 | tee -a /var/log/app-prod.log &
```

## 🔐 Security Notes

### File Permissions

```bash
# Jenkins should own Jenkins home
sudo chown -R 1000:1000 /opt/jenkins_home

# App configs should be read-only for container
sudo chown -R root:root /opt/configs
sudo chmod -R 644 /opt/configs/**/*.properties

# Kafka data
sudo chown -R 1000:1000 /opt/kafka_data /opt/kafka_logs
```

### SELinux Context (if enforcing)

```bash
# Check SELinux
getenforce

# If Enforcing, set proper contexts
sudo semanage fcontext -a -t container_file_t "/opt/configs(/.*)?"
sudo restorecon -Rv /opt/configs

sudo semanage fcontext -a -t container_file_t "/opt/jenkins_home(/.*)?"
sudo restorecon -Rv /opt/jenkins_home
```

### Firewall

```bash
# Open required ports
sudo firewall-cmd --permanent --add-port=8080/tcp  # Jenkins
sudo firewall-cmd --permanent --add-port=9092/tcp  # Kafka
sudo firewall-cmd --permanent --add-port=9200/tcp  # App Production
sudo firewall-cmd --permanent --add-port=9201/tcp  # App Test
sudo firewall-cmd --reload
```

## 📝 Quick Reference

### Common Commands

```bash
# Deploy test
# → Go to Jenkins UI → Build with Parameters → ENVIRONMENT=test

# Deploy production
# → Go to Jenkins UI → Build with Parameters → ENVIRONMENT=production

# View test logs
podman logs -f lendbiz-apigateway-test

# View production logs
podman logs -f lendbiz-apigateway-production

# Restart test app
podman restart lendbiz-apigateway-test

# Check health
curl http://localhost:9201/actuator/health  # Test
curl http://localhost:9200/actuator/health  # Production

# View all containers
podman ps -a

# Clean up stopped containers
podman container prune -f

# Clean up unused images
podman image prune -a -f
```

### Port Reference

| Service | Port | URL |
|---------|------|-----|
| Jenkins | 8080 | http://localhost:8080 |
| Kafka | 9092 | localhost:9092 |
| Kafka UI | 8090 | http://localhost:8090 |
| App Test | 9201 | http://localhost:9201 |
| App Production | 9200 | http://localhost:9200 |

### Directory Structure

```
/opt/
├── jenkins_home/          # Jenkins workspace & jobs
├── kafka_data/            # Kafka topic data
├── kafka_logs/            # Kafka logs
├── configs/
│   ├── test/
│   │   └── application.properties
│   └── production/
│       └── application.properties
└── scripts/
    └── monitor.sh         # Monitoring script
```

---

**Last Updated**: 2026-02-05  
**Deployment Mode**: Single Server (Simplified - No SSH)
