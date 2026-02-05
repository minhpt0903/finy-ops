# Jenkins Auto-Build Setup Guide

## 📋 Mục tiêu
Sau khi setup xong, mỗi khi developer push code:
- Push `test` branch → Jenkins tự động build & deploy lên Test Server (192.168.20.82:9201)
- Push `main` branch → Jenkins tự động build & deploy lên Prod Server (42.112.38.103:9200)

---

## 🏗️ Architecture

```
┌──────────────────────────────────────────────────────────────┐
│  Developer                                                   │
│  git push origin test/main                                   │
└────────────────────┬─────────────────────────────────────────┘
                     │
                     ▼
┌──────────────────────────────────────────────────────────────┐
│  Git Server (GitHub/GitLab/Bitbucket)                        │
│  - Receives push                                             │
│  - Triggers webhook → Jenkins                                │
└────────────────────┬─────────────────────────────────────────┘
                     │ HTTP POST
                     ▼
┌──────────────────────────────────────────────────────────────┐
│  Jenkins (Multibranch Pipeline)                              │
│  1. Receives webhook notification                            │
│  2. Scans repository                                         │
│  3. Detects which branch changed (test or main)              │
│  4. Reads Jenkinsfile from that branch                       │
│  5. Executes pipeline:                                       │
│     - Build with Gradle                                      │
│     - Create Docker/Podman image                             │
│     - Deploy to correct server                               │
└────────────────────┬─────────────────────────────────────────┘
                     │
            ┌────────┴────────┐
            ▼                 ▼
    ┌──────────────┐  ┌──────────────┐
    │ Test Server  │  │ Prod Server  │
    │ 192.168.20.82│  │ 42.112.38.103│
    │ Port: 9201   │  │ Port: 9200   │
    └──────────────┘  └──────────────┘
```

---

## 🚀 Step-by-Step Setup

### Step 1: Cài đặt Jenkins Plugins

```
Jenkins Dashboard → Manage Jenkins → Manage Plugins → Available
```

Cài các plugins sau:

#### **Required Plugins:**
- ✅ **Git Plugin** - Để clone Git repository
- ✅ **Pipeline** - Hỗ trợ Jenkinsfile
- ✅ **Multibranch Pipeline** - Auto-detect branches
- ✅ **SSH Agent Plugin** - Để SSH đến target servers
- ✅ **Credentials Plugin** - Quản lý credentials

#### **Webhook Plugins (chọn theo Git server):**
- ✅ **GitHub Plugin** - Nếu dùng GitHub
- ✅ **GitLab Plugin** - Nếu dùng GitLab  
- ✅ **Bitbucket Plugin** - Nếu dùng Bitbucket

#### **Optional but Recommended:**
- **Workspace Cleanup Plugin** - Dọn dẹp workspace
- **Timestamper Plugin** - Thêm timestamp vào logs
- **AnsiColor Plugin** - Colored output trong console

```bash
# Hoặc install via Jenkins CLI
java -jar jenkins-cli.jar -s http://localhost:8080/ install-plugin \
  git \
  workflow-aggregator \
  pipeline-multibranch-defaults \
  ssh-agent \
  credentials-binding \
  github \
  gitlab-plugin \
  bitbucket
```

### Step 2: Thêm Credentials vào Jenkins

#### **A. Git Repository Credentials**

```
Jenkins → Manage Jenkins → Manage Credentials → Global → Add Credentials
```

**Username/Password:**
```
Kind: Username with password
Scope: Global
Username: <your-git-username>
Password: <your-git-token>
ID: git-credentials
Description: Git Repository Access
```

**SSH Key (nếu dùng SSH):**
```
Kind: SSH Username with private key
Scope: Global
Username: git
Private Key: [Enter directly]
  ↳ Paste your ~/.ssh/id_rsa content
ID: git-ssh-key
Description: Git SSH Key
```

#### **B. Deployment SSH Key**

```
Kind: SSH Username with private key
Scope: Global
Username: deploy
Private Key: [Enter directly]
  ↳ Paste content of ~/.ssh/jenkins_deploy_key
ID: ssh-deploy-key
Description: SSH key for deploying to servers
```

### Step 3: Tạo Multibranch Pipeline Job

#### **A. Create New Job**

```
Jenkins Dashboard → New Item

Enter an item name: lendbiz-apigateway
Type: Multibranch Pipeline
Click OK
```

#### **B. Configure Branch Sources**

**Tab: Branch Sources → Add source → Git**

```
Project Repository: https://github.com/your-org/lendbiz-apigateway.git
Credentials: git-credentials (select from dropdown)

Behaviors:
  ✓ Discover branches
    Strategy: All branches
  
  ✓ Filter by name (with regular expression)
    Regular expression: (main|test|develop|feature/.*)
    ↑ Chỉ build các branches này
```

#### **C. Build Configuration**

```
Build Configuration:
  Mode: by Jenkinsfile
  Script Path: Jenkinsfile
```

#### **D. Scan Multibranch Pipeline Triggers**

```
☑ Periodically if not otherwise run
Interval: 5 minutes

☑ Scan by webhook
```

#### **E. Orphaned Item Strategy**

```
Days to keep old items: 7
Max # of old items to keep: 10
```

**Save**

### Step 4: Configure Webhook (Auto-trigger)

#### **GitHub Webhook Setup:**

1. Vào repository trên GitHub:
   ```
   https://github.com/your-org/lendbiz-apigateway
   ```

2. Settings → Webhooks → Add webhook:
   ```
   Payload URL: http://YOUR_JENKINS_URL:8080/github-webhook/
   Content type: application/json
   Secret: (leave empty hoặc set password)
   
   Which events would you like to trigger this webhook?
   ○ Just the push event
   
   ☑ Active
   ```

3. Click **Add webhook**

4. Test webhook:
   ```
   Webhooks → Edit → Recent Deliveries → Redeliver
   ```
   
   Phải thấy **green checkmark** ✓

#### **GitLab Webhook Setup:**

```
Repository → Settings → Webhooks

URL: http://YOUR_JENKINS_URL:8080/project/lendbiz-apigateway
Secret Token: (optional)

Trigger:
☑ Push events
  Branch filter: (empty = all branches)
☑ Merge request events

☑ Enable SSL verification (if Jenkins uses HTTPS)

Add webhook
```

Test webhook: Click **Test → Push events**

#### **Bitbucket Webhook Setup:**

```
Repository → Settings → Webhooks → Add webhook

Title: Jenkins Auto Build
URL: http://YOUR_JENKINS_URL:8080/bitbucket-hook/
Status: Active

Triggers:
☑ Repository - Push
☑ Pull Request - Created
☑ Pull Request - Updated

Save
```

### Step 5: Configure Jenkins Global Settings

```
Manage Jenkins → Configure System
```

#### **A. Git Plugin**
```
Global Config user.name: Jenkins
Global Config user.email: jenkins@your-company.com
```

#### **B. GitHub Server (if using GitHub)**
```
GitHub Servers → Add GitHub Server

Name: GitHub
API URL: https://api.github.com
Credentials: (create GitHub token with repo access)
☑ Manage hooks
```

#### **C. GitLab Connection (if using GitLab)**
```
GitLab → Add GitLab Server

Connection name: GitLab
GitLab host URL: https://gitlab.com (hoặc self-hosted URL)
Credentials: Add → GitLab API token
```

### Step 6: Test Setup

#### **A. Manual Scan**
```
Jenkins → lendbiz-apigateway → Scan Multibranch Pipeline Now
```

Kết quả:
```
✓ Branches found: main, test
✓ Sub-jobs created:
  - lendbiz-apigateway/main
  - lendbiz-apigateway/test
```

#### **B. Test Auto-trigger**

```bash
# On your local machine
git checkout test
echo "# Test auto-build" >> README.md
git add README.md
git commit -m "Test Jenkins auto-build"
git push origin test
```

**Quan sát Jenkins:**
1. Sau 5-10 giây, job `lendbiz-apigateway/test` bắt đầu build
2. Console output hiển thị:
   ```
   Started by GitHub push by your-username
   ```
3. Build thành công → Deploy to Test Server (192.168.20.82:9201)

#### **C. Verify Deployment**

```bash
# Check health
curl http://192.168.20.82:9201/actuator/health

# Check Jenkins logs
http://jenkins:8080/job/lendbiz-apigateway/job/test/lastBuild/console
```

---

## 🔍 Troubleshooting

### Issue 1: Webhook không trigger Jenkins

**Symptom:** Push code nhưng Jenkins không build

**Check:**

```bash
# 1. Check Jenkins có nhận webhook không
Jenkins → lendbiz-apigateway → Webhook Delivery
# Phải thấy recent deliveries

# 2. Check Jenkins URL có accessible không
curl http://YOUR_JENKINS_URL:8080/github-webhook/
# Phải trả về 200 OK hoặc 302

# 3. Check firewall
sudo firewall-cmd --list-all | grep 8080
# Port 8080 phải open

# 4. Check webhook logs trên Git server
GitHub: Settings → Webhooks → Recent Deliveries
# Check HTTP response code
```

**Solution:**

```bash
# A. Nếu Jenkins ở local/behind firewall, dùng ngrok:
ngrok http 8080

# Lấy public URL:
# https://abc123.ngrok.io → update vào webhook URL

# B. Hoặc dùng Polling thay webhook:
# Jenkinsfile thêm:
triggers {
    pollSCM('H/5 * * * *')  # Check every 5 minutes
}
```

### Issue 2: Build failed - Cannot connect to Git

**Symptom:** `git fetch` failed

**Solution:**

```bash
# Check SSH key permission
chmod 600 ~/.ssh/id_rsa

# Test Git connection from Jenkins container
podman exec -it jenkins bash
git ls-remote https://github.com/your-org/repo.git

# If failed, regenerate credentials in Jenkins
```

### Issue 3: Build failed - Cannot deploy to server

**Symptom:** SSH connection refused

**Check:**

```bash
# Test SSH from Jenkins container
podman exec -it jenkins bash
ssh -i /var/jenkins_home/.ssh/jenkins_deploy_key deploy@192.168.20.82

# Check SSH key in Jenkins credentials
Jenkins → Credentials → ssh-deploy-key → Update
```

### Issue 4: Wrong branch được build

**Symptom:** Push `test` nhưng Jenkins build `main`

**Solution:**

```
Jenkins → lendbiz-apigateway → Configure
→ Branch Sources → Behaviors
→ Filter by name: ^(main|test)$
→ Save

→ Scan Multibranch Pipeline Now
```

### Issue 5: Jenkins quá nhiều builds (spam)

**Symptom:** Mỗi commit tạo nhiều builds

**Solution:**

```
Jenkinsfile → options {
    // Discard old builds
    buildDiscarder(logRotator(numToKeepStr: '10'))
    
    // Disable concurrent builds on same branch
    disableConcurrentBuilds()
}
```

---

## 📊 Monitoring & Logs

### View Build History

```
Jenkins → lendbiz-apigateway → test → Build History
```

### View Console Output

```
Jenkins → lendbiz-apigateway → test → #123 → Console Output
```

### View Deployment Logs on Server

```bash
# Test server
ssh deploy@192.168.20.82
podman logs -f lendbiz-apigateway-test

# Production server
ssh deploy@42.112.38.103
podman logs -f lendbiz-apigateway-production
```

### Email Notifications

Add to Jenkinsfile:

```groovy
pipeline {
    // ... stages ...
    
    post {
        success {
            emailext (
                subject: "✓ Build Success: ${env.JOB_NAME} #${env.BUILD_NUMBER}",
                body: """
                    Build succeeded!
                    Branch: ${env.BRANCH_NAME}
                    Environment: ${env.ENVIRONMENT}
                    Check: ${env.BUILD_URL}
                """,
                to: "team@your-company.com"
            )
        }
        failure {
            emailext (
                subject: "✗ Build Failed: ${env.JOB_NAME} #${env.BUILD_NUMBER}",
                body: """
                    Build failed!
                    Branch: ${env.BRANCH_NAME}
                    Logs: ${env.BUILD_URL}console
                """,
                to: "team@your-company.com"
            )
        }
    }
}
```

---

## 🎯 Best Practices

### 1. Branch Protection

Chỉ allow merge vào `main` qua Pull Request:

```
GitHub: Settings → Branches → Add rule
Branch name pattern: main
☑ Require pull request reviews before merging
☑ Require status checks to pass (Jenkins build)
```

### 2. Manual Approval for Production

Add approval step cho production deployment:

```groovy
stage('Deploy') {
    when {
        branch 'main'
    }
    steps {
        // Manual approval for production
        input message: 'Deploy to Production?', 
              ok: 'Deploy',
              submitter: 'admin,lead-dev'
        
        script {
            // Deploy to production...
        }
    }
}
```

### 3. Parallel Builds for Multiple Services

```groovy
stage('Build') {
    parallel {
        stage('API Gateway') {
            steps {
                sh './gradlew :apigateway:build'
            }
        }
        stage('Auth Service') {
            steps {
                sh './gradlew :auth:build'
            }
        }
        stage('User Service') {
            steps {
                sh './gradlew :user:build'
            }
        }
    }
}
```

### 4. Cache Dependencies

```groovy
stage('Build') {
    steps {
        // Cache Gradle dependencies
        sh '''
            ./gradlew build \
                --build-cache \
                --parallel \
                --max-workers=4
        '''
    }
}
```

---

## 📚 Additional Resources

### Jenkins Documentation
- Multibranch Pipeline: https://www.jenkins.io/doc/book/pipeline/multibranch/
- Webhooks: https://www.jenkins.io/doc/book/managing/webhooks/
- Credentials: https://www.jenkins.io/doc/book/using/using-credentials/

### Quick Commands

```bash
# View Jenkins logs
podman logs -f jenkins

# Restart Jenkins
podman restart jenkins

# Backup Jenkins home
tar -czf jenkins-backup-$(date +%Y%m%d).tar.gz /opt/jenkins_home/

# View webhook deliveries
# GitHub: Repository → Settings → Webhooks → Recent Deliveries
# GitLab: Repository → Settings → Webhooks → Recent events
```

### Verification Checklist

After setup, verify:

- [ ] Plugins installed successfully
- [ ] Git credentials added to Jenkins
- [ ] SSH deploy key added to Jenkins
- [ ] Multibranch Pipeline job created
- [ ] Webhook configured on Git server
- [ ] Manual scan finds both `main` and `test` branches
- [ ] Push to `test` branch triggers build automatically
- [ ] Build deploys to Test Server successfully
- [ ] Push to `main` branch triggers build automatically
- [ ] Build deploys to Production Server successfully
- [ ] Health checks passing on both environments
- [ ] Email notifications working (if configured)

---

**Last Updated**: 2026-02-05  
**Next Review**: After first production deployment
