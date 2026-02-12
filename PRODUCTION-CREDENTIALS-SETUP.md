# Production Credentials Setup - Jenkins

Hướng dẫn setup credentials production trong Jenkins để bảo mật thông tin nhạy cảm.

## 🔐 Tại sao cần setup này?

**Vấn đề:** Nếu để DB credentials, API keys trong properties files → Push lên Git → **Lộ hết thông tin!**

**Giải pháp:** 
- Properties files: Chỉ chứa **public config** (URLs, settings)
- Jenkins Credentials: Lưu **sensitive data** (DB passwords, API keys)
- Runtime: Jenkins inject credentials vào container qua **environment variables**

**Spring Boot precedence:** Environment Variables > Properties files ✅

---

## 📋 Credentials cần setup

### 1. Database Production Credentials

**Manage Jenkins → Credentials → System → Global credentials → Add Credentials**

**Type: Username with password**

```
Kind: Username with password
Scope: Global
Username: <production-db-username>
Password: <production-db-password>
ID: db-production-credentials
Description: Production Database Credentials
```

Click **Create**

---

### 2. Database Production URL

**Add Credentials**

**Type: Secret text**

```
Kind: Secret text
Scope: Global
Secret: jdbc:oracle:thin:@<prod-db-host>:1521/<prod-db-sid>
ID: db-production-url
Description: Production Database JDBC URL
```

---

### 3. Jasypt Encryption Password (Optional - nếu dùng)

**Add Credentials**

**Type: Secret text**

```
Kind: Secret text
Scope: Global
Secret: lendbiZ@2023
ID: jasypt-encryptor-password
Description: Jasypt Encryption Password
```

---

### 4. Production Kafka Bootstrap Servers (Optional)

Nếu Kafka production khác với test:

**Add Credentials**

**Type: Secret text**

```
Kind: Secret text
Scope: Global
Secret: production-kafka-1:9092,production-kafka-2:9092
ID: kafka-production-servers
Description: Production Kafka Bootstrap Servers
```

---

### 5. External API Keys (Nếu cần)

Nếu có API keys cho external services:

**Add Credentials**

**Type: Secret text**

```
Kind: Secret text
Secret: <your-api-key>
ID: external-api-key
Description: External Service API Key
```

---

## 🔧 Update Jenkinsfile

Sau khi tạo credentials, update Jenkinsfile để inject vào container:

```groovy
pipeline {
    agent any
    
    parameters {
        choice(name: 'ENVIRONMENT', choices: ['test', 'production'])
        string(name: 'GIT_BRANCH', defaultValue: 'test')
        booleanParam(name: 'SKIP_TESTS', defaultValue: true)
    }
    
    environment {
        APP_NAME = 'lendbiz-apigateway'
        SPRING_PROFILE = "${params.ENVIRONMENT}"
        APP_PORT = "${params.ENVIRONMENT == 'production' ? '9200' : '9201'}"
        KAFKA_SERVERS = '42.112.38.103:9092'
    }
    
    stages {
        stage('Deploy') {
            steps {
                script {
                    def imageTag = "${APP_NAME}:${params.ENVIRONMENT}-${BUILD_NUMBER}"
                    def containerName = "${APP_NAME}-${params.ENVIRONMENT}"
                    
                    if (params.ENVIRONMENT == 'production') {
                        // Production: Inject credentials từ Jenkins
                        withCredentials([
                            usernamePassword(
                                credentialsId: 'db-production-credentials',
                                usernameVariable: 'DB_USER',
                                passwordVariable: 'DB_PASS'
                            ),
                            string(
                                credentialsId: 'db-production-url',
                                variable: 'DB_URL'
                            )
                        ]) {
                            sh """
                                export CONTAINER_HOST=unix:///run/podman/podman.sock
                                
                                podman stop ${containerName} 2>/dev/null || true
                                podman rm ${containerName} 2>/dev/null || true
                                
                                podman run -d --name ${containerName} \\
                                    --network podman \\
                                    -e SPRING_PROFILES_ACTIVE=${SPRING_PROFILE} \\
                                    -e SPRING_DATASOURCE_URL=${DB_URL} \\
                                    -e SPRING_DATASOURCE_USERNAME=${DB_USER} \\
                                    -e SPRING_DATASOURCE_PASSWORD=${DB_PASS} \\
                                    -e SPRING_KAFKA_BOOTSTRAP_SERVERS=${KAFKA_SERVERS} \\
                                    -p ${APP_PORT}:9200 \\
                                    --restart unless-stopped \\
                                    ${imageTag}
                            """
                        }
                    } else {
                        // Test: Dùng credentials từ properties file
                        sh """
                            export CONTAINER_HOST=unix:///run/podman/podman.sock
                            
                            podman stop ${containerName} 2>/dev/null || true
                            podman rm ${containerName} 2>/dev/null || true
                            
                            podman run -d --name ${containerName} \\
                                --network podman \\
                                -e SPRING_PROFILES_ACTIVE=${SPRING_PROFILE} \\
                                -e SPRING_KAFKA_BOOTSTRAP_SERVERS=${KAFKA_SERVERS} \\
                                -p ${APP_PORT}:9200 \\
                                --restart unless-stopped \\
                                ${imageTag}
                        """
                    }
                }
            }
        }
    }
}
```

---

## ✅ Verify Setup

### 1. Check Credentials trong Jenkins

**Manage Jenkins → Credentials**

Bạn sẽ thấy:
- ✅ `db-production-credentials` (Username/Password)
- ✅ `db-production-url` (Secret text)
- ✅ `jasypt-encryptor-password` (Secret text - nếu cần)

### 2. Test Build Production

**Jenkins → Finy → Build with Parameters**

- Environment: `production`
- Branch: `main`
- Skip Tests: `true`

Click **Build**

### 3. Verify Container có credentials

```bash
# SSH vào server
ssh minhpt@42.112.38.103

# Check environment variables trong container
sudo podman exec lendbiz-apigateway-production env | grep SPRING_DATASOURCE

# Output mong đợi:
# SPRING_DATASOURCE_URL=jdbc:oracle:thin:@...
# SPRING_DATASOURCE_USERNAME=prod_user
# SPRING_DATASOURCE_PASSWORD=****  (masked)
```

### 4. Check logs

```bash
sudo podman logs lendbiz-apigateway-production | grep -i "started"
```

Nếu thấy "Started Application" → Thành công! ✅

---

## 🔍 Troubleshooting

### Issue: Credentials not found

**Error:** `Credentials 'db-production-credentials' not found`

**Solution:** 
1. Verify credential ID chính xác trong Jenkins UI
2. Check scope = **Global** (không phải System)
3. Restart Jenkins: `sudo podman restart jenkins`

---

### Issue: Permission denied accessing credentials

**Solution:**
```bash
# Give Jenkins user permission
sudo podman exec -u root jenkins sh -c '
    chown -R jenkins:jenkins /var/jenkins_home/credentials
'
```

---

### Issue: Application không connect được DB

**Check:**
1. Verify DB URL đúng format: `jdbc:oracle:thin:@host:1521/sid`
2. Check DB username/password
3. Verify network connectivity từ Jenkins server tới DB

```bash
# Test từ server
telnet prod-db-host 1521
```

---

## 📚 Best Practices

### ✅ NÊN:

1. **Tất cả production credentials phải dùng Jenkins Credentials**
2. **Rotate credentials định kỳ** (3-6 tháng)
3. **Limit access**: Chỉ admin có quyền xem credentials
4. **Backup credentials** ở nơi an toàn (1Password, Vault)
5. **Audit log**: Monitor ai access credentials

### ❌ KHÔNG NÊN:

1. **Hard-code passwords trong Jenkinsfile**
2. **Commit credentials vào Git** (dù có encrypt)
3. **Share credentials qua email/chat**
4. **Dùng chung credentials giữa test và production**
5. **Echo credentials ra console log**

---

## 🔐 Security Checklist

- [ ] Production DB credentials được lưu trong Jenkins Credentials
- [ ] Application-prod.properties KHÔNG chứa passwords
- [ ] Jenkinsfile inject credentials qua environment variables
- [ ] Git history không có sensitive data (nếu có → rewrite history)
- [ ] Jenkins credentials được backup
- [ ] Chỉ admin mới access được Jenkins Credentials
- [ ] Credentials được rotate định kỳ

---

## 📖 Xem thêm

- [JENKINS-ENV-VARS-GUIDE.md](JENKINS-ENV-VARS-GUIDE.md) - Chi tiết về env vars
- [Spring Boot External Config](https://docs.spring.io/spring-boot/docs/current/reference/html/features.html#features.external-config)
- [Jenkins Credentials Plugin](https://plugins.jenkins.io/credentials/)

# Jenkins Production Credentials Setup for finy-service

Bạn cần khai báo các credentials sau trong Jenkins để pipeline production hoạt động:

1. Git repository URL:
   - ID: git-finy-service-url
   - Type: String
   - Giá trị: URL repo production của finy-service

2. Git credentials:
   - ID: git-credentials
   - Type: Username with password
   - Dùng để truy cập repo production

3. Database credentials:
   - ID: db-finy-service-prod-credentials
   - Type: Username with password
   - Username variable: DB_USER
   - Password variable: DB_PASS

4. Database URL:
   - ID: db-finy-service-prod-url
   - Type: String
   - Variable: DB_URL

5. Log path:
   - ID: finy-log-path-prod
   - Type: String
   - Variable: LOG_PATH
   - Giá trị: Đường dẫn thư mục logs trên host production

6. Contract path:
   - ID: finy-document-path-prod
   - Type: String
   - Variable: CONTRACT_PATH
   - Giá trị: Đường dẫn thư mục contract trên host production

> Đảm bảo các credentials trên được tạo đúng ID và type trong Jenkins Credentials Manager.
> Các giá trị path phải tồn tại trên host production.
