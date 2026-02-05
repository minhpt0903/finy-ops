# Jenkins Manual Build Guide

## 🎯 Hướng dẫn build manual trong Jenkins UI

Cấu hình hiện tại đã **tắt auto-trigger**. Bạn cần vào Jenkins UI để build thủ công.

---

## 🚀 Cách build manual

### Bước 1: Truy cập Jenkins

```
http://your-jenkins-url:8080
```

Đăng nhập với credentials của bạn.

### Bước 2: Chọn Job

```
Jenkins Dashboard
└── lendbiz-apigateway (hoặc tên job của bạn)
```

### Bước 3: Click "Build with Parameters"

```
lendbiz-apigateway
└── Build with Parameters (bên trái sidebar)
```

### Bước 4: Chọn Parameters

**ENVIRONMENT (dropdown):**
- `test` - Deploy to Test Server (192.168.20.82:9201)
- `production` - Deploy to Production Server (42.112.38.103:9200)

**GIT_BRANCH (text input):**
- `test` - Build từ nhánh test
- `main` - Build từ nhánh main
- `feature/xyz` - Build từ nhánh feature
- Hoặc bất kỳ branch name nào

**Ví dụ:**

#### ✅ Build Test Environment:
```
ENVIRONMENT: test
GIT_BRANCH: test
```
→ Click **Build**

#### ✅ Build Production Environment:
```
ENVIRONMENT: production
GIT_BRANCH: main
```
→ Click **Build**

### Bước 5: Theo dõi Build

Click vào **#Build Number** để xem console output:

```
lendbiz-apigateway
└── #123 (build number)
    └── Console Output
```

---

## 📊 Scenarios phổ biến

### Scenario 1: Build & Deploy Test Environment

```
Use Case: Developer muốn test code mới

Steps:
1. Developer push code lên branch test
2. Vào Jenkins UI
3. Build with Parameters:
   - ENVIRONMENT: test
   - GIT_BRANCH: test
4. Click Build
5. Verify: http://192.168.20.82:9201/actuator/health
```

### Scenario 2: Build & Deploy Production

```
Use Case: Sau khi test OK, deploy production

Steps:
1. Merge test → main
2. Vào Jenkins UI
3. Build with Parameters:
   - ENVIRONMENT: production
   - GIT_BRANCH: main
4. Click Build
5. Verify: http://42.112.38.103:9200/actuator/health
```

### Scenario 3: Build Feature Branch to Test Environment

```
Use Case: Test feature branch trước khi merge

Steps:
1. Developer tạo feature/new-feature branch
2. Vào Jenkins UI
3. Build with Parameters:
   - ENVIRONMENT: test
   - GIT_BRANCH: feature/new-feature
4. Click Build
5. Test trên Test Server
6. OK → merge vào test branch
```

### Scenario 4: Rebuild Previous Version

```
Use Case: Current deployment có bug, cần rollback

Steps:
1. Vào Jenkins UI
2. lendbiz-apigateway → Build History
3. Tìm build trước đó (ví dụ: #120)
4. Click #120 → Rebuild
5. Confirm parameters
6. Build
```

### Scenario 5: Build nhiều environments đồng thời

```
Use Case: Cần deploy cùng lúc test và production

Steps:
1. Build Test:
   - ENVIRONMENT: test
   - GIT_BRANCH: test
   - Click Build

2. Ngay lập tức build Production (parallel):
   - ENVIRONMENT: production
   - GIT_BRANCH: main
   - Click Build

Cả 2 builds sẽ chạy đồng thời nếu Jenkins có đủ executors.
```

---

## 🔧 Jenkins Job Configuration

### Tạo Regular Pipeline Job (không phải Multibranch)

#### Step 1: Create New Item

```
Jenkins Dashboard → New Item

Name: lendbiz-apigateway
Type: Pipeline (NOT Multibranch Pipeline)
Click OK
```

#### Step 2: Configure Job

**General:**
```
☐ Discard old builds
  Max # of builds to keep: 20

☐ This project is parameterized (already in Jenkinsfile)

☐ Do not allow concurrent builds (recommended)
```

**Build Triggers:**
```
☐ DO NOT select any triggers
  (Không chọn gì cả - để manual build only)
```

**Pipeline:**
```
Definition: Pipeline script from SCM

SCM: Git
  Repository URL: https://your-git-repo-url.git
  Credentials: git-credentials
  Branches to build: */main
    ↑ Default branch, nhưng sẽ bị override bởi parameter GIT_BRANCH

Script Path: Jenkinsfile
```

**Advanced:**
```
☑ Lightweight checkout (faster)
```

**Save**

---

## 🔐 Required Credentials

Đảm bảo đã add credentials vào Jenkins:

### 1. Git Credentials (git-credentials)

```
Jenkins → Manage Jenkins → Manage Credentials → Global
→ Add Credentials

Kind: Username with password (hoặc SSH key)
ID: git-credentials
Username: your-git-username
Password: your-git-token (or SSH private key)
```

### 2. SSH Deploy Key (ssh-deploy-key)

```
Jenkins → Manage Jenkins → Manage Credentials → Global
→ Add Credentials

Kind: SSH Username with private key
ID: ssh-deploy-key
Username: deploy
Private Key: [Paste nội dung ~/.ssh/jenkins_deploy_key]
```

---

## 📝 Build Workflow Visualization

```
┌─────────────────────────────────────────────────────────┐
│  User opens Jenkins UI                                  │
│  http://jenkins:8080                                    │
└───────────────────────┬─────────────────────────────────┘
                        │
                        ▼
┌─────────────────────────────────────────────────────────┐
│  Select Job: lendbiz-apigateway                         │
│  Click: "Build with Parameters"                         │
└───────────────────────┬─────────────────────────────────┘
                        │
                        ▼
┌─────────────────────────────────────────────────────────┐
│  Fill Parameters:                                       │
│  ┌─────────────────────────────────────────────────┐   │
│  │ ENVIRONMENT:   [test ▼]                         │   │
│  │ GIT_BRANCH:    [test                    ]       │   │
│  └─────────────────────────────────────────────────┘   │
│                                                         │
│  [Build]                                                │
└───────────────────────┬─────────────────────────────────┘
                        │
                        ▼
┌─────────────────────────────────────────────────────────┐
│  Jenkins executes Jenkinsfile:                          │
│                                                          │
│  1. ✓ Checkout (git clone branch: test)                │
│  2. ✓ Build (./gradlew build -Pspring.profiles.active=test) │
│  3. ✓ Test (./gradlew test)                            │
│  4. ✓ Build Image (podman build)                       │
│  5. ✓ Deploy (SSH to 192.168.20.82, deploy container)  │
└───────────────────────┬─────────────────────────────────┘
                        │
                        ▼
┌─────────────────────────────────────────────────────────┐
│  Build Complete                                          │
│  ✓ Status: SUCCESS                                      │
│  ✓ Application URL: http://192.168.20.82:9201          │
│  ✓ Health: http://192.168.20.82:9201/actuator/health   │
└─────────────────────────────────────────────────────────┘
```

---

## 🎨 Jenkins UI Tips

### Keyboard Shortcuts

```
Jenkins Dashboard:
  j → Jump to Quick Search
  ? → Show keyboard shortcuts

In Build:
  Ctrl+A → Select All (console output)
  Ctrl+C → Copy
```

### Quick Links

Add bookmarks:

```
Test Build:
http://jenkins:8080/job/lendbiz-apigateway/build?delay=0sec

Production Build:
http://jenkins:8080/job/lendbiz-apigateway/build?delay=0sec

Last Build Console:
http://jenkins:8080/job/lendbiz-apigateway/lastBuild/console

Build History:
http://jenkins:8080/job/lendbiz-apigateway/builds
```

### Build URL with Parameters (Advanced)

Bạn có thể tạo URL để pre-fill parameters:

```bash
# Test build
http://jenkins:8080/job/lendbiz-apigateway/buildWithParameters?ENVIRONMENT=test&GIT_BRANCH=test

# Production build
http://jenkins:8080/job/lendbiz-apigateway/buildWithParameters?ENVIRONMENT=production&GIT_BRANCH=main
```

**Note:** Cần enable CSRF protection bypass hoặc có API token.

### Create Build Button on Desktop

#### Windows (PowerShell script):

```powershell
# build-test.ps1
$jenkinsUrl = "http://jenkins:8080"
$jobName = "lendbiz-apigateway"
$user = "your-username"
$token = "your-api-token"

$params = @{
    ENVIRONMENT = "test"
    GIT_BRANCH = "test"
}

$body = $params | ConvertTo-Json
$base64Auth = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes("${user}:${token}"))

Invoke-RestMethod -Uri "$jenkinsUrl/job/$jobName/buildWithParameters" `
    -Method Post `
    -Headers @{Authorization="Basic $base64Auth"} `
    -Body $body `
    -ContentType "application/json"

Write-Host "Build triggered successfully!"
```

#### Linux (bash script):

```bash
#!/bin/bash
# build-test.sh

JENKINS_URL="http://jenkins:8080"
JOB_NAME="lendbiz-apigateway"
USER="your-username"
TOKEN="your-api-token"

curl -X POST \
  "$JENKINS_URL/job/$JOB_NAME/buildWithParameters" \
  --user "$USER:$TOKEN" \
  --data "ENVIRONMENT=test" \
  --data "GIT_BRANCH=test"

echo "Build triggered successfully!"
```

---

## 🔍 Troubleshooting

### Issue 1: "Build with Parameters" button không hiện

**Reason:** Job chưa có parameters

**Solution:**

```
1. Run build lần đầu (sẽ dùng default values)
2. Jenkins sẽ detect parameters từ Jenkinsfile
3. Lần sau sẽ có "Build with Parameters" button
```

### Issue 2: Build failed - Cannot checkout branch

**Symptom:**
```
ERROR: Couldn't find any revision to build. Verify the repository and branch configuration for this job.
```

**Solution:**

```
Jenkins → lendbiz-apigateway → Configure
→ Pipeline → SCM
→ Check:
  ✓ Repository URL correct
  ✓ Credentials selected
  ✓ Branch specifier: */${GIT_BRANCH} hoặc */main
```

### Issue 3: Parameter không được apply

**Symptom:** Build vẫn dùng branch cũ dù đã đổi parameter

**Solution:**

```
1. Xóa workspace cũ:
   lendbiz-apigateway → Workspace → Wipe Out Workspace

2. Build lại với parameters mới
```

### Issue 4: Muốn thay đổi default parameters

**Solution:**

Edit Jenkinsfile:

```groovy
parameters {
    choice(
        name: 'ENVIRONMENT',
        choices: ['test', 'production'],  // Test là default (đầu tiên)
        description: 'Select environment'
    )
    string(
        name: 'GIT_BRANCH',
        defaultValue: 'develop',  // Đổi default thành develop
        description: 'Branch to build'
    )
}
```

Commit, push, rồi run build 1 lần để Jenkins update parameters.

---

## 📊 Monitoring & Verification

### After Build Success

#### 1. Check Console Output

```
lendbiz-apigateway → #123 → Console Output

Tìm dòng:
✓ Deployment completed!
Application URL: http://192.168.20.82:9201
```

#### 2. Verify Health

```bash
# Test environment
curl http://192.168.20.82:9201/actuator/health

# Production environment
curl http://42.112.38.103:9200/actuator/health

# Expected response:
{"status":"UP"}
```

#### 3. Check Container on Server

```bash
# SSH to test server
ssh deploy@192.168.20.82

# Check container
podman ps | grep lendbiz-apigateway-test

# View logs
podman logs -f lendbiz-apigateway-test
```

#### 4. View Build Artifacts

```
lendbiz-apigateway → #123
→ Artifacts (if archived)
→ Test Results (if tests run)
→ Workspace (source code)
```

---

## 📚 Best Practices

### 1. Always verify before production

```
✓ Build test environment first
✓ Run smoke tests
✓ Check logs for errors
✓ Verify health endpoints
✓ Then build production
```

### 2. Use descriptive build description

Add to Jenkinsfile:

```groovy
stage('Deploy') {
    steps {
        script {
            currentBuild.description = "ENV: ${params.ENVIRONMENT}, BRANCH: ${params.GIT_BRANCH}"
        }
    }
}
```

### 3. Schedule regular builds

Nếu muốn build định kỳ (ví dụ: nightly builds):

```
Jenkins → lendbiz-apigateway → Configure
→ Build Triggers
→ Build periodically
Schedule: H 2 * * *  (2AM every day)

Build with default parameters
```

### 4. Access Control

```
Jenkins → Manage Jenkins → Configure Global Security
→ Authorization
→ Matrix-based security:

User          Build    Cancel    Read
admin         ✓        ✓         ✓
developer     ✓        ✗         ✓
viewer        ✗        ✗         ✓
```

### 5. Build Notifications

Add email notification to Jenkinsfile:

```groovy
post {
    success {
        mail to: 'team@company.com',
             subject: "✓ Build #${env.BUILD_NUMBER} Success",
             body: "ENV: ${params.ENVIRONMENT}\nBRANCH: ${params.GIT_BRANCH}"
    }
    failure {
        mail to: 'team@company.com',
             subject: "✗ Build #${env.BUILD_NUMBER} Failed",
             body: "Check: ${env.BUILD_URL}"
    }
}
```

---

## 🎯 Quick Reference Card

```
╔════════════════════════════════════════════════════════╗
║  JENKINS MANUAL BUILD QUICK REFERENCE                 ║
╠════════════════════════════════════════════════════════╣
║                                                        ║
║  URL: http://jenkins:8080                             ║
║  Job: lendbiz-apigateway                              ║
║                                                        ║
║  BUILD TEST:                                          ║
║    ENVIRONMENT = test                                 ║
║    GIT_BRANCH = test                                  ║
║    → Deploy to 192.168.20.82:9201                     ║
║                                                        ║
║  BUILD PRODUCTION:                                    ║
║    ENVIRONMENT = production                           ║
║    GIT_BRANCH = main                                  ║
║    → Deploy to 42.112.38.103:9200                     ║
║                                                        ║
║  VERIFY:                                              ║
║    curl http://SERVER:PORT/actuator/health           ║
║                                                        ║
║  VIEW LOGS:                                           ║
║    ssh deploy@SERVER                                  ║
║    podman logs -f lendbiz-apigateway-{env}           ║
║                                                        ║
╚════════════════════════════════════════════════════════╝
```

Print và dán lên tường! 😄

---

**Last Updated**: 2026-02-05  
**Mode**: Manual Build Only (No Auto-Trigger)
