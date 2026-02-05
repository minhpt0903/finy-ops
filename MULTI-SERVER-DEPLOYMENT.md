# Multi-Server Deployment Configuration

## 🏗️ Architecture Overview

```
┌─────────────────┐
│  Jenkins Server │  ← Build & orchestrate deployments
│  (CI/CD Hub)    │
└────────┬────────┘
         │
         ├──────────────────────────┬────────────────────────────┐
         │                          │                            │
         ▼                          ▼                            ▼
┌─────────────────┐        ┌─────────────────┐        ┌─────────────────┐
│  Test Server    │        │  Prod Server    │        │  Registry       │
│  192.168.20.82  │        │  42.112.38.103  │        │ (Images)        │
│                 │        │                 │        │                 │
│  Branch: test   │        │  Branch: main   │        │                 │
│  Port: 9201     │        │  Port: 9200     │        │                 │
│  Profile: test  │        │  Profile: prod  │        │                 │
│  DB: DBTest     │        │  DB: DBLive     │        │                 │
└─────────────────┘        └─────────────────┘        └─────────────────┘
```

## 📊 Server Configuration Matrix

| Aspect | Test Server | Production Server |
|--------|-------------|-------------------|
| **IP Address** | 192.168.20.82 | 42.112.38.103 |
| **Git Branch** | `test` | `main` |
| **Spring Profile** | `test` | `prod` |
| **Application Port** | 9201 | 9200 |
| **Database** | DBTest | DBLive |
| **Kafka** | 42.112.38.103:9092 | 42.112.38.103:9092 |
| **Logging Level** | DEBUG | WARN |
| **Auto Deploy** | Yes | Yes (with approval) |
| **Health Check** | http://192.168.20.82:9201/actuator/health | http://42.112.38.103:9200/actuator/health |

## 🔧 Setup Requirements

### 1. Jenkins Server Setup

#### A. Install SSH Plugin
```bash
# In Jenkins:
Manage Jenkins → Manage Plugins → Available
Search: "SSH Agent Plugin"
Install and restart
```

#### B. Configure SSH Credentials
```bash
# Generate SSH key on Jenkins server (if not exists)
ssh-keygen -t rsa -b 4096 -C "jenkins@deploy" -f ~/.ssh/jenkins_deploy_key

# Copy public key to target servers
ssh-copy-id -i ~/.ssh/jenkins_deploy_key.pub deploy@192.168.20.82  # Test server
ssh-copy-id -i ~/.ssh/jenkins_deploy_key.pub deploy@42.112.38.103  # Prod server
```

#### C. Add Credentials to Jenkins
```
Jenkins → Manage Jenkins → Manage Credentials → Global → Add Credentials

Type: SSH Username with private key
ID: ssh-deploy-key
Username: deploy
Private Key: [Paste nội dung của ~/.ssh/jenkins_deploy_key]
Save
```

### 2. Test Server Setup (192.168.20.82)

```bash
# SSH vào test server
ssh root@192.168.20.82

# 1. Create deploy user
useradd -m -s /bin/bash deploy
usermod -aG wheel deploy

# 2. Install Podman
dnf install -y podman podman-docker

# 3. Configure Podman for deploy user
su - deploy
systemctl --user enable --now podman.socket
loginctl enable-linger deploy

# 4. Create config directory
sudo mkdir -p /opt/configs/test
sudo chown deploy:deploy /opt/configs/test

# 5. Test Podman
podman run --rm hello-world

# 6. Configure firewall
sudo firewall-cmd --permanent --add-port=9201/tcp
sudo firewall-cmd --reload
```

### 3. Production Server Setup (42.112.38.103)

```bash
# SSH vào production server
ssh root@42.112.38.103

# Same steps as test server
useradd -m -s /bin/bash deploy
usermod -aG wheel deploy

dnf install -y podman podman-docker

su - deploy
systemctl --user enable --now podman.socket
loginctl enable-linger deploy

sudo mkdir -p /opt/configs/production
sudo chown deploy:deploy /opt/configs/production

podman run --rm hello-world

sudo firewall-cmd --permanent --add-port=9200/tcp
sudo firewall-cmd --reload
```

### 4. Place Configuration Files on Servers

#### Test Server (192.168.20.82):
```bash
# SSH vào test server
ssh deploy@192.168.20.82

# Copy application-test.properties
cat > /opt/configs/test/application.properties << 'EOF'
# Copy content from spring-envs/test/application.properties
EOF
```

#### Production Server (42.112.38.103):
```bash
# SSH vào production server
ssh deploy@42.112.38.103

# Copy application-prod.properties
cat > /opt/configs/production/application.properties << 'EOF'
# Copy content from spring-envs/production/application.properties
EOF
```

## 🚀 Deployment Flow

### Branch `test` → Test Server (192.168.20.82)

```bash
# Developer pushes to test branch
git checkout test
git push origin test

# Jenkins automatically:
# 1. Detects push to test branch
# 2. Builds with profile=test
# 3. Creates image: lendbiz-apigateway:test-123
# 4. Exports image to tar
# 5. SCPs tar to Test Server (192.168.20.82)
# 6. SSH to Test Server
# 7. Loads image on Test Server
# 8. Stops old container
# 9. Starts new container on port 9201
# 10. Runs health check
```

### Branch `main` → Production Server (42.112.38.103)

```bash
# After testing, merge to main
git checkout main
git merge test
git push origin main

# Jenkins automatically:
# 1. Detects push to main branch
# 2. Builds with profile=prod
# 3. Creates image: lendbiz-apigateway:production-123
# 4. Exports image to tar
# 5. SCPs tar to Production Server (42.112.38.103)
# 6. SSH to Production Server
# 7. Loads image on Production Server
# 8. Stops old container (gracefully)
# 9. Starts new container on port 9200
# 10. Runs health check
# 11. Sends notification
```

## 🔐 Security Configuration

### 1. SSH Key Management

```bash
# On Jenkins server, restrict key permissions
chmod 600 ~/.ssh/jenkins_deploy_key
chmod 644 ~/.ssh/jenkins_deploy_key.pub

# Test SSH connectivity
ssh -i ~/.ssh/jenkins_deploy_key deploy@192.168.20.82 'echo "Test server OK"'
ssh -i ~/.ssh/jenkins_deploy_key deploy@42.112.38.103 'echo "Prod server OK"'
```

### 2. Sudoless Deployment

Deploy user chỉ cần quyền:
- ✅ Chạy Podman (rootless)
- ✅ Đọc/ghi trong `/opt/configs/{environment}/`
- ✅ Đọc/ghi trong `/tmp/`
- ❌ KHÔNG cần sudo

### 3. Network Security

#### Test Server Firewall:
```bash
sudo firewall-cmd --permanent --add-service=ssh
sudo firewall-cmd --permanent --add-port=9201/tcp
sudo firewall-cmd --permanent --add-rich-rule='rule family="ipv4" source address="JENKINS_IP" port port="22" protocol="tcp" accept'
sudo firewall-cmd --reload
```

#### Production Server Firewall:
```bash
sudo firewall-cmd --permanent --add-service=ssh
sudo firewall-cmd --permanent --add-port=9200/tcp
sudo firewall-cmd --permanent --add-rich-rule='rule family="ipv4" source address="JENKINS_IP" port port="22" protocol="tcp" accept'
sudo firewall-cmd --reload
```

## 📝 Manual Deployment (Emergency)

### Deploy to Test Server manually:

```bash
# On Jenkins server
cd /path/to/project
./gradlew clean build -Pspring.profiles.active=test

# Build image
podman build -t lendbiz-apigateway:test-manual .

# Export and transfer
podman save lendbiz-apigateway:test-manual -o /tmp/app.tar
scp /tmp/app.tar deploy@192.168.20.82:/tmp/

# Deploy on Test Server
ssh deploy@192.168.20.82 << 'EOF'
podman load -i /tmp/app.tar
podman stop lendbiz-apigateway-test || true
podman rm lendbiz-apigateway-test || true
podman run -d --name lendbiz-apigateway-test \
  --network podman \
  -e SPRING_PROFILES_ACTIVE=test \
  -p 9201:9200 \
  -v /opt/configs/test:/config:ro \
  --restart unless-stopped \
  lendbiz-apigateway:test-manual
EOF
```

### Deploy to Production Server manually:

```bash
# Same as above but:
# - Profile: prod
# - Server: 42.112.38.103
# - Port: 9200
# - Config: /opt/configs/production
```

## 🔍 Verification & Testing

### Test Server Health Check:
```bash
# From anywhere
curl http://192.168.20.82:9201/actuator/health

# Expected response:
# {"status":"UP"}
```

### Production Server Health Check:
```bash
curl http://42.112.38.103:9200/actuator/health
```

### Check Container Status on Server:
```bash
# SSH to server
ssh deploy@192.168.20.82  # or 42.112.38.103

# Check running containers
podman ps

# View logs
podman logs -f lendbiz-apigateway-test    # or lendbiz-apigateway-production

# Check resources
podman stats lendbiz-apigateway-test
```

## 🚨 Troubleshooting

### Issue: SSH Connection Failed

```bash
# Test SSH from Jenkins
ssh -v deploy@192.168.20.82

# Common fixes:
# 1. Check firewall
sudo firewall-cmd --list-all | grep ssh

# 2. Check SSH service
sudo systemctl status sshd

# 3. Check SSH config
cat /etc/ssh/sshd_config | grep PubkeyAuthentication
# Should be: PubkeyAuthentication yes
```

### Issue: Permission Denied (podman)

```bash
# On target server as deploy user
loginctl enable-linger deploy
systemctl --user status podman.socket

# Test podman
podman run --rm hello-world
```

### Issue: Image Transfer Failed

```bash
# Check disk space on target server
df -h

# Check /tmp space
df -h /tmp

# Cleanup old images
podman image prune -a
```

### Issue: Container Won't Start

```bash
# Check logs
podman logs lendbiz-apigateway-test

# Check port
ss -tulpn | grep 9201

# Check SELinux (if enforcing)
sudo ausearch -m avc -ts recent | grep podman
```

## 📊 Monitoring

### Setup Monitoring on Each Server

```bash
# Install monitoring agent (example: Prometheus Node Exporter)
# On each server:
podman run -d \
  --name node-exporter \
  --network podman \
  -p 9100:9100 \
  prom/node-exporter
```

### Container Health Monitoring Script

```bash
#!/bin/bash
# health-monitor.sh - Run on each server via cron

CONTAINER_NAME="lendbiz-apigateway-test"  # or lendbiz-apigateway-production
PORT=9201  # or 9200

# Check container is running
if ! podman ps | grep -q $CONTAINER_NAME; then
    echo "ALERT: Container $CONTAINER_NAME is not running!"
    # Send alert (email, Slack, etc.)
    exit 1
fi

# Check health endpoint
HEALTH=$(curl -s http://localhost:${PORT}/actuator/health | jq -r '.status')
if [ "$HEALTH" != "UP" ]; then
    echo "ALERT: Application health check failed: $HEALTH"
    exit 1
fi

echo "OK: Container healthy"
```

## 📚 Best Practices

1. ✅ **Always test on Test Server first** - Never deploy directly to production
2. ✅ **Use SSH keys, not passwords** - More secure
3. ✅ **Keep configs in /opt/configs/** - Separate from application
4. ✅ **Monitor both servers** - Set up alerts
5. ✅ **Regular backups** - Database and configs
6. ✅ **Tag images properly** - `environment-buildnumber`
7. ✅ **Document changes** - Keep deployment log
8. ✅ **Have rollback plan** - Keep previous images

## 🔄 Rollback Procedure

### Test Server:
```bash
ssh deploy@192.168.20.82
podman stop lendbiz-apigateway-test
podman rm lendbiz-apigateway-test
podman run -d --name lendbiz-apigateway-test \
  lendbiz-apigateway:test-122  # Previous build
```

### Production Server:
```bash
ssh deploy@42.112.38.103
podman stop lendbiz-apigateway-production
podman rm lendbiz-apigateway-production
podman run -d --name lendbiz-apigateway-production \
  lendbiz-apigateway:production-122  # Previous build
```

## 📝 Deployment Checklist

### Before Every Deployment:

- [ ] Code reviewed and approved
- [ ] Tests passing
- [ ] Tested on Test Server successfully
- [ ] Database migrations ready
- [ ] Configs updated on target server
- [ ] Backup completed
- [ ] Rollback plan ready
- [ ] Team notified
- [ ] Maintenance window scheduled (if needed)

### After Deployment:

- [ ] Health check passing
- [ ] Logs reviewed (first 5 minutes)
- [ ] Performance metrics normal
- [ ] User acceptance testing (UAT)
- [ ] Documentation updated
- [ ] Team notified of success

## 📞 Contact & Support

- **Jenkins Issues**: DevOps team
- **Test Server**: test-support@company.com
- **Production Server**: production-oncall@company.com
- **Emergency Hotline**: +84-xxx-xxx-xxx

---

**Last Updated**: 2026-02-05  
**Maintained By**: DevOps Team
