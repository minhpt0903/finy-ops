# Jenkins Setup cho Java Spring Boot - Quick Guide

## 🎯 Các bước setup (5-10 phút)

### 1. Truy cập Jenkins

```bash
# Lấy password Jenkins
podman exec jenkins cat /var/jenkins_home/secrets/initialAdminPassword

# Copy password, mở browser
http://localhost:8080
# Hoặc nếu từ xa:
http://192.168.20.82:8080
```

**Unlock Jenkins:**
- Paste password → Continue
- Install suggested plugins → Đợi 2-3 phút
- Create admin user:
  - Username: `admin`
  - Password: `admin123` (hoặc password của bạn)
  - Full name: `Admin`
  - Email: `admin@localhost`
- Save and Continue → Start using Jenkins

---

### 2. Cài Git Plugin (nếu chưa có)

```
Dashboard → Manage Jenkins → Manage Plugins → Available
```

Tìm và install:
- ✅ Git Plugin
- ✅ Git client Plugin
- ✅ Credentials Plugin

Click **Install without restart**

---

### 3. Add Git Credentials

```
Dashboard → Manage Jenkins → Manage Credentials
→ System → Global credentials → Add Credentials
```

**Chọn loại:**

#### Option A: Username/Password (GitHub/GitLab)
```
Kind: Username with password
Scope: Global
Username: your-git-username
Password: your-personal-access-token
ID: git-credentials
Description: Git Repository Access
```

**Tạo Personal Access Token:**
- GitHub: Settings → Developer settings → Personal access tokens → Generate new token (classic)
  - Chọn: `repo` (full control)
- GitLab: User Settings → Access Tokens → Add new token
  - Chọn: `read_repository`, `write_repository`

#### Option B: SSH Key (nếu dùng SSH)
```
Kind: SSH Username with private key
Username: git
Private Key: Enter directly
  → Paste nội dung file ~/.ssh/id_rsa
ID: git-ssh-key
Description: Git SSH Key
```

Click **Create**

---

### 4. Tạo Pipeline Job

```
Dashboard → New Item
```

**Cấu hình:**
```
Enter an item name: lendbiz-apigateway
Type: Pipeline
OK
```

**General:**
```
☑ This project is parameterized (sẽ tự detect từ Jenkinsfile)
Description: Lendbiz API Gateway - Spring Boot Application
```

**Build Triggers:**
```
☐ Không chọn gì (manual build only theo yêu cầu của bạn)
```

**Pipeline:**
```
Definition: Pipeline script from SCM

SCM: Git
  Repository URL: https://github.com/your-org/lendbiz-apigateway.git
  Credentials: git-credentials (chọn credential vừa tạo)
  
  Branches to build:
    Branch Specifier: */main
    (hoặc */master tùy repository của bạn)

Script Path: Jenkinsfile
```

**Advanced (click Show Advanced):**
```
☑ Lightweight checkout (faster)
```

Click **Save**

---

### 5. Cấu hình Tools trong Jenkins

Jenkins cần Gradle và JDK để build:

```
Dashboard → Manage Jenkins → Global Tool Configuration
```

#### A. JDK Configuration
```
JDK installations → Add JDK

Name: JDK-17
☐ Install automatically (uncheck)
JAVA_HOME: /opt/java/openjdk
```

Hoặc nếu muốn auto install:
```
☑ Install automatically
Install from adoptium.net
Version: jdk-17.0.x+x
```

#### B. Gradle Configuration
```
Gradle installations → Add Gradle

Name: Gradle-8.5
☑ Install automatically
Install from Gradle.org
Version: 8.5
```

Click **Save**

---

### 6. Test Build

```
Dashboard → lendbiz-apigateway → Build with Parameters
```

**Parameters (sẽ tự xuất hiện sau lần build đầu):**
```
ENVIRONMENT: test
GIT_BRANCH: test
SKIP_TESTS: ☐
```

Click **Build**

**Xem progress:**
```
#1 → Console Output
```

Đợi build hoàn tất (~3-5 phút lần đầu)

---

### 7. Verify Deployment

```bash
# Check containers
podman ps

# Should see:
# lendbiz-apigateway-test   0.0.0.0:9201->9200/tcp

# Test health
curl http://localhost:9201/actuator/health

# Response:
# {"status":"UP"}

# View logs
podman logs -f lendbiz-apigateway-test
```

---

## 🔧 Troubleshooting

### Issue 1: Git clone failed

**Error:** `Failed to connect to repository`

**Fix:**
```
1. Check Git URL correct
2. Check credentials valid
3. Test manually:
   podman exec jenkins git ls-remote https://github.com/your-org/repo.git
```

### Issue 2: Gradle not found

**Error:** `gradlew: command not found`

**Fix:**
```
1. Ensure gradlew exists in repo root
2. Make it executable:
   git update-index --chmod=+x gradlew
   git commit -m "Make gradlew executable"
   git push
```

### Issue 3: Java version mismatch

**Error:** `Unsupported class file major version`

**Fix:**
```
1. Check Jenkinsfile uses correct JDK version
2. Jenkins → Manage Jenkins → Global Tool Configuration
3. Configure JDK-17
4. In Jenkinsfile:
   tools {
       jdk 'JDK-17'
   }
```

### Issue 4: Cannot build Podman image

**Error:** `podman: command not found`

**Fix:**
```bash
# Install Podman in Jenkins container
podman exec -u root jenkins bash -c "
  apt-get update
  apt-get install -y podman
"

# Restart Jenkins
podman restart jenkins
```

### Issue 5: Port already in use

**Error:** `port 9201 is already allocated`

**Fix:**
```bash
# Find what's using the port
podman ps | grep 9201

# Stop old container
podman stop lendbiz-apigateway-test
podman rm lendbiz-apigateway-test

# Build again in Jenkins
```

---

## 📝 Deploy Production

Sau khi test OK trên test environment:

```
Dashboard → lendbiz-apigateway → Build with Parameters

ENVIRONMENT: production
GIT_BRANCH: main
SKIP_TESTS: ☐

Build
```

Application sẽ deploy to port **9200**:
```bash
curl http://localhost:9200/actuator/health
```

---

## 🚀 Quick Reference

### URLs
```
Jenkins:     http://localhost:8080
Kafka UI:    http://localhost:8090
App Test:    http://localhost:9201
App Prod:    http://localhost:9200
```

### Commands
```bash
# View all containers
podman ps

# Jenkins logs
podman logs -f jenkins

# App logs
podman logs -f lendbiz-apigateway-test
podman logs -f lendbiz-apigateway-production

# Restart Jenkins
podman restart jenkins

# Stop all
podman stop jenkins kafka kafka-ui lendbiz-apigateway-test
```

### Next Build
```
1. Push code to Git
2. Go to Jenkins → lendbiz-apigateway
3. Click "Build with Parameters"
4. Select environment and branch
5. Click Build
6. Wait for deployment
7. Test health endpoint
```

---

## 🎯 Automation Tips

### Tip 1: Add Build Description

Jenkinsfile thêm:
```groovy
stage('Info') {
    steps {
        script {
            currentBuild.description = "ENV: ${params.ENVIRONMENT} | BRANCH: ${params.GIT_BRANCH}"
        }
    }
}
```

### Tip 2: Email Notifications

Jenkinsfile thêm:
```groovy
post {
    success {
        echo "✅ Build SUCCESS - http://localhost:${APP_PORT}/actuator/health"
    }
    failure {
        echo "❌ Build FAILED - Check logs: ${BUILD_URL}console"
    }
}
```

### Tip 3: Parallel Builds

Để build test và production cùng lúc:
```
1. Mở 2 tabs Jenkins
2. Tab 1: Build test
3. Tab 2: Build production
4. Cả 2 chạy parallel
```

### Tip 4: Clean Old Containers

Thêm stage cleanup trong Jenkinsfile:
```groovy
stage('Cleanup') {
    steps {
        sh '''
            # Remove stopped containers
            podman container prune -f
            
            # Remove unused images
            podman image prune -a -f --filter "until=24h"
        '''
    }
}
```

---

**Setup complete!** 🎉

Giờ mỗi khi có code mới:
```
1. Push code to Git
2. Vào Jenkins UI
3. Click Build with Parameters
4. Chọn environment
5. Click Build
6. Done!
```
