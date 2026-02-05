# Deployment Guide - Branch-Based Deployment

## 📋 Overview

Hệ thống tự động deploy dựa trên Git branch:

| Branch | Environment | Profile | Port | Database | URL |
|--------|------------|---------|------|----------|-----|
| `main` | Production | `prod` | 9200 | DBLive | https://api.finy.vn |
| `test` | Test | `test` | 9201 | DBTest | https://test-api.finy.vn |

## 🚀 Quick Deployment

### Deploy lên Test

```bash
# 1. Merge code vào branch test
git checkout test
git merge develop
git push origin test

# 2. Jenkins tự động:
# - Detect branch = test
# - Build với profile test
# - Deploy lên test server port 9201
# - Run health checks
```

### Deploy lên Production

```bash
# 1. Test OK trên test environment
# 2. Merge vào main
git checkout main
git merge test
git push origin main

# 3. Jenkins tự động:
# - Detect branch = main
# - Build với profile prod
# - Deploy lên production port 9200
# - Run smoke tests
```

## 🔧 Jenkins Configuration

### 1. Tạo Multibranch Pipeline

```groovy
// Jenkins UI:
New Item → Multibranch Pipeline
Name: lendbiz-apigateway

// Configuration:
Branch Sources:
  - Git: https://github.com/your-org/lendbiz-apigateway.git
  - Credentials: github-token
  - Discover branches: All branches

Build Configuration:
  - Mode: by Jenkinsfile
  - Script Path: Jenkinsfile

Scan Multibranch Pipeline Triggers:
  - Periodically: 5 minutes
```

### 2. Branch-Specific Behaviors

Jenkins tự động:

**Branch `test`:**
- Profile: `test`
- Build artifact: `lendbiz-apigateway:test-latest`
- Deploy port: `9201`
- Auto-deploy: Yes
- Notifications: Slack #test-deployments

**Branch `main`:**
- Profile: `prod`
- Build artifact: `lendbiz-apigateway:production-latest`
- Deploy port: `9200`
- Auto-deploy: Yes (với approval nếu cần)
- Notifications: Slack #production-deployments + Email

## 📁 Project Structure

```
your-spring-project/
├── src/
│   └── main/
│       ├── java/
│       └── resources/
│           ├── application.properties           # Common config
│           ├── application-prod.properties      # Production overrides
│           ├── application-test.properties      # Test overrides
│           └── db/
│               └── migration/
│                   ├── production/              # Production DB migrations
│                   │   ├── V1.0.0__init.sql
│                   │   └── V1.0.1__add_tables.sql
│                   └── test/                    # Test DB migrations
│                       ├── V1.0.0__init.sql
│                       └── V1.0.1__add_tables.sql
├── build.gradle
├── settings.gradle
├── Dockerfile
├── Jenkinsfile
└── README.md
```

## 🔐 Configuration Management

### application.properties (Common)

```properties
# Shared configuration
spring.application.name=lendbiz-apigateway
server.servlet.context-path=/
jasypt.encryptor.password=lendbiZ@2023
jasypt.encryptor.algorithm=PBEWithMD5AndDES
```

### application-prod.properties

```properties
spring.profiles.active=prod
server.port=9200

# Production Database
spring.datasource.url=jdbc:oracle:thin:@prod-db:1521/PROD
spring.datasource.username=ENC(C8kqb6zJ2hpV/LuQZFDeUA==)
spring.datasource.password=ENC(QwYy7AugLrAHQYJ+ZDvOQPjJ2I+/KDQw)

# Production Kafka
spring.kafka.bootstrap-servers=42.112.38.103:9092
spring.kafka.producer.acks=all
spring.kafka.producer.retries=3

# Flyway
spring.flyway.locations=classpath:db/migration/production

# Logging
logging.level.root=warn
logging.level.com.technology.apigateway=info
spring.jpa.show-sql=false

# External services
econtract-gateway.url=https://econtract.finy.vn
```

### application-test.properties

```properties
spring.profiles.active=test
server.port=9200

# Test Database
spring.datasource.url=jdbc:oracle:thin:@test-db:1521/TEST
spring.datasource.username=ENC(nwtguNr2R6NJLqQzx0mpK2pYDTMCm5xI)
spring.datasource.password=ENC(WD+WD9iNhvaJkBJrpfI/vaKBAKskDxV9)

# Test Kafka
spring.kafka.bootstrap-servers=42.112.38.103:9092

# Flyway
spring.flyway.locations=classpath:db/migration/test

# Logging (more verbose)
logging.level.root=debug
logging.level.com.technology.apigateway=debug
spring.jpa.show-sql=true

# External services
econtract-gateway.url=https://econtracttest.finy.vn
```

## 🔄 Deployment Workflow

### Scenario 1: Feature Development

```bash
# 1. Create feature branch
git checkout -b feature/add-new-api

# 2. Develop & commit
git add .
git commit -m "Add new API endpoint"

# 3. Deploy to test for QA
git checkout test
git merge feature/add-new-api
git push origin test
# → Jenkins auto-deploys to test environment

# 4. QA team tests on https://test-api.finy.vn:9201

# 5. If approved, deploy to production
git checkout main
git merge test
git push origin main
# → Jenkins auto-deploys to production
```

### Scenario 2: Hotfix

```bash
# 1. Create hotfix from main
git checkout -b hotfix/security-patch main

# 2. Fix the issue
git commit -am "Security patch for CVE-2026-1234"

# 3. Test on test environment
git checkout test
git merge hotfix/security-patch
git push origin test
# → Quick test

# 4. Deploy to production ASAP
git checkout main
git merge hotfix/security-patch
git push origin main
# → Production deployment
```

### Scenario 3: Rollback

```bash
# Option 1: Revert commit
git checkout main
git revert HEAD
git push origin main
# → Jenkins deploys previous version

# Option 2: Manual container rollback
podman stop lendbiz-apigateway-production
podman rm lendbiz-apigateway-production
podman run -d --name lendbiz-apigateway-production \
  lendbiz-apigateway:production-123  # Previous build number
```

## 🎯 Deployment Checklist

### Pre-Deployment (Test)

- [ ] Code reviewed and approved
- [ ] Unit tests passing
- [ ] Integration tests passing
- [ ] No security vulnerabilities (dependency check)
- [ ] Flyway migrations tested
- [ ] Configuration verified

### Pre-Deployment (Production)

- [ ] Tested successfully on test environment
- [ ] QA approval obtained
- [ ] Database backup completed
- [ ] Rollback plan prepared
- [ ] Monitoring alerts configured
- [ ] Stakeholders notified
- [ ] Change ticket created

### Post-Deployment

- [ ] Health check passing
- [ ] Smoke tests completed
- [ ] Logs monitored (first 15 minutes)
- [ ] Performance metrics normal
- [ ] Error rates acceptable
- [ ] Database connections healthy
- [ ] Kafka connectivity verified

## 📊 Monitoring

### Health Checks

```bash
# Test environment
curl http://test-server:9201/actuator/health
curl http://test-server:9201/actuator/info

# Production environment
curl http://production-server:9200/actuator/health
curl http://production-server:9200/actuator/info
```

### Application Metrics

```bash
# Metrics endpoint
curl http://localhost:9200/actuator/metrics

# Specific metrics
curl http://localhost:9200/actuator/metrics/jvm.memory.used
curl http://localhost:9200/actuator/metrics/http.server.requests
```

### Container Logs

```bash
# Follow logs
podman logs -f lendbiz-apigateway-production
podman logs -f lendbiz-apigateway-test

# Last 100 lines
podman logs --tail 100 lendbiz-apigateway-production

# Filter errors
podman logs lendbiz-apigateway-production | grep ERROR
```

## 🔍 Verification Scripts

### verify-deployment.sh

```bash
#!/bin/bash
# Verify deployment success

ENVIRONMENT=$1  # test or production
PORT=$2         # 9201 or 9200

echo "Verifying ${ENVIRONMENT} deployment on port ${PORT}..."

# Health check
echo "1. Health check..."
HEALTH=$(curl -s http://localhost:${PORT}/actuator/health | jq -r '.status')
if [ "$HEALTH" != "UP" ]; then
    echo "❌ Health check failed: $HEALTH"
    exit 1
fi
echo "✅ Health check passed"

# Check active profile
echo "2. Checking active profile..."
PROFILE=$(curl -s http://localhost:${PORT}/actuator/env | jq -r '.activeProfiles[0]')
if [ "$ENVIRONMENT" == "production" ] && [ "$PROFILE" != "prod" ]; then
    echo "❌ Wrong profile: $PROFILE (expected: prod)"
    exit 1
fi
if [ "$ENVIRONMENT" == "test" ] && [ "$PROFILE" != "test" ]; then
    echo "❌ Wrong profile: $PROFILE (expected: test)"
    exit 1
fi
echo "✅ Profile correct: $PROFILE"

# Database connectivity
echo "3. Checking database..."
DB_STATUS=$(curl -s http://localhost:${PORT}/actuator/health | jq -r '.components.db.status')
if [ "$DB_STATUS" != "UP" ]; then
    echo "❌ Database not connected"
    exit 1
fi
echo "✅ Database connected"

# Kafka connectivity
echo "4. Checking Kafka..."
KAFKA_STATUS=$(curl -s http://localhost:${PORT}/actuator/health | jq -r '.components.kafka.status // "UNKNOWN"')
if [ "$KAFKA_STATUS" == "UNKNOWN" ]; then
    echo "⚠️  Kafka status unknown (might not be critical)"
else
    echo "✅ Kafka status: $KAFKA_STATUS"
fi

echo ""
echo "✅ Deployment verification passed!"
```

### Usage:

```bash
# Verify test deployment
./verify-deployment.sh test 9201

# Verify production deployment
./verify-deployment.sh production 9200
```

## 🚨 Troubleshooting

### Issue: Build fails on Jenkins

```bash
# Check Jenkins logs
# Jenkins → Job → Console Output

# Common issues:
# 1. Gradle wrapper permissions
chmod +x gradlew
git add gradlew
git commit --amend --no-edit
git push -f

# 2. Missing Gradle config
# Ensure Gradle-8.5 configured in Jenkins

# 3. Test failures
./gradlew test --info
```

### Issue: Container won't start

```bash
# Check container logs
podman logs lendbiz-apigateway-production

# Common issues:
# 1. Port already in use
podman ps -a | grep 9200
podman stop <container-id>

# 2. Wrong profile
podman inspect lendbiz-apigateway-production | jq '.[0].Config.Env'

# 3. Database connection failed
# Check encrypted credentials
# Check database availability
nc -zv db-server 1521
```

### Issue: Wrong profile active

```bash
# 1. Check environment variable
podman inspect lendbiz-apigateway-production | \
  jq '.[0].Config.Env[] | select(contains("SPRING_PROFILES_ACTIVE"))'

# 2. Recreate container with correct profile
podman stop lendbiz-apigateway-production
podman rm lendbiz-apigateway-production
podman run -d --name lendbiz-apigateway-production \
  -e SPRING_PROFILES_ACTIVE=prod \
  -p 9200:9200 \
  lendbiz-apigateway:production-latest
```

## 📞 Support

### Escalation Path

1. **L1 Support**: Check logs, restart container
2. **L2 Support**: Analyze metrics, check database/kafka
3. **L3 Support (Dev Team)**: Code issues, hotfixes

### Contact

- Test Environment Issues: #dev-support
- Production Issues: #production-alerts
- On-call: +84-xxx-xxx-xxx

## 📚 References

- [Spring Boot Documentation](https://docs.spring.io/spring-boot/docs/2.7.8/reference/html/)
- [Jenkins Pipeline Syntax](https://www.jenkins.io/doc/book/pipeline/syntax/)
- [Podman Documentation](https://docs.podman.io/)
- [Project Wiki](https://wiki.company.com/lendbiz-apigateway)
