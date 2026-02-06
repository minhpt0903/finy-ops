# Jenkins Environment Variables Guide

## 🎯 Trả lời: Jenkins có setup được Environment Variables không?

**CÓ - Jenkins hỗ trợ nhiều cách setup environment variables:**

---

## 1️⃣ Environment Variables trong Jenkinsfile (Đang dùng)

Đây là cách hiện tại trong Jenkinsfile của bạn:

```groovy
environment {
    APP_NAME = 'lendbiz-apigateway'
    SPRING_PROFILE = "${params.ENVIRONMENT}"
    APP_PORT = "${params.ENVIRONMENT == 'production' ? '9200' : '9201'}"
    KAFKA_SERVERS = '42.112.38.103:9092'
}
```

**✅ Ưu điểm:**
- Dễ quản lý, version control trong Git
- Thay đổi nhanh, chỉ cần commit/push
- Environment-specific logic (ternary operator)

**❌ Nhược điểm:**
- Hardcode values trong code
- Credentials không nên để trong Git

---

## 2️⃣ Jenkins Credentials (Cho sensitive data)

### Setup Credentials trong Jenkins UI:

**Manage Jenkins → Credentials → System → Global credentials → Add Credentials**

**Các loại credentials:**

#### a. Secret Text (cho API keys, passwords đơn giản)
```
Kind: Secret text
Secret: lendbiZ@2023
ID: jasypt-password
Description: Jasypt Encryption Password
```

**Sử dụng trong Jenkinsfile:**
```groovy
environment {
    JASYPT_PASSWORD = credentials('jasypt-password')
}

steps {
    sh """
        gradle build -Djasypt.encryptor.password=${JASYPT_PASSWORD}
    """
}
```

#### b. Username with Password (cho DB credentials)
```
Kind: Username with password
Username: db_user
Password: db_password
ID: db-production-credentials
```

**Sử dụng:**
```groovy
environment {
    DB_CREDENTIALS = credentials('db-production-credentials')
}

steps {
    sh """
        # Jenkins tự động tạo 2 env vars:
        # DB_CREDENTIALS_USR=db_user
        # DB_CREDENTIALS_PSW=db_password
        
        podman run -d \
            -e DB_USERNAME=${DB_CREDENTIALS_USR} \
            -e DB_PASSWORD=${DB_CREDENTIALS_PSW} \
            your-app
    """
}
```

#### c. Secret File (cho config files lớn)
```
Kind: Secret file
File: application-prod-secrets.properties
ID: app-prod-secrets
```

**Sử dụng:**
```groovy
steps {
    withCredentials([file(credentialsId: 'app-prod-secrets', variable: 'SECRETS_FILE')]) {
        sh """
            cp $SECRETS_FILE src/main/resources/application-prod.properties
            gradle build
        """
    }
}
```

---

## 3️⃣ Environment Variables trong Jenkins Global Config

**Manage Jenkins → System → Global properties → Environment variables**

Checkbox: ✅ Environment variables

Add biến:
- Name: `KAFKA_BOOTSTRAP_SERVERS`
- Value: `42.112.38.103:9092`

**Sử dụng tất cả jobs:**
```groovy
steps {
    sh "echo Kafka: ${env.KAFKA_BOOTSTRAP_SERVERS}"
}
```

---

## 4️⃣ Parameterized Build (Đang dùng)

Đây là cách bạn đã setup trong job:

```groovy
parameters {
    choice(name: 'ENVIRONMENT', choices: ['test', 'production'])
    string(name: 'GIT_BRANCH', defaultValue: 'test')
    booleanParam(name: 'SKIP_TESTS', defaultValue: true)
}
```

User chọn khi build → Jenkins inject vào `${params.ENVIRONMENT}`

---

## 5️⃣ Config File Provider Plugin (Advanced)

Install plugin: **Config File Provider**

**Manage Jenkins → Managed files → Add new Config → Custom file**

Tạo file: `application-prod.properties`

**Sử dụng:**
```groovy
steps {
    configFileProvider([configFile(fileId: 'app-prod-config', variable: 'CONFIG_FILE')]) {
        sh """
            cp $CONFIG_FILE src/main/resources/application-prod.properties
            gradle build
        """
    }
}
```

---

## 📋 Khuyến nghị cho dự án của bạn

### Cấu trúc nên dùng:

```groovy
environment {
    // Public configs - OK trong Jenkinsfile
    APP_NAME = 'lendbiz-apigateway'
    APP_PORT = "${params.ENVIRONMENT == 'production' ? '9200' : '9201'}"
    SPRING_PROFILE = "${params.ENVIRONMENT}"
    
    // Kafka config - có thể để đây nếu không sensitive
    KAFKA_SERVERS = '42.112.38.103:9092'
    
    // ⚠️ Sensitive data - PHẢI dùng Jenkins Credentials
    JASYPT_PASSWORD = credentials('jasypt-password')
    DB_PROD_CREDS = credentials('db-production-credentials')
}

stages {
    stage('Deploy') {
        steps {
            sh """
                export CONTAINER_HOST=unix:///run/podman/podman.sock
                
                podman run -d \
                    --name ${APP_NAME}-${ENVIRONMENT} \
                    -e SPRING_PROFILES_ACTIVE=${SPRING_PROFILE} \
                    -e JASYPT_PASSWORD=${JASYPT_PASSWORD} \
                    -e DB_USERNAME=${DB_PROD_CREDS_USR} \
                    -e DB_PASSWORD=${DB_PROD_CREDS_PSW} \
                    -e KAFKA_SERVERS=${KAFKA_SERVERS} \
                    -p ${APP_PORT}:9200 \
                    ${APP_NAME}:${BUILD_NUMBER}
            """
        }
    }
}
```

---

## 🔐 Security Best Practices

### ✅ NÊN:
1. Dùng Jenkins Credentials cho:
   - Database passwords
   - API keys
   - Encryption keys (Jasypt password)
   - Private tokens

2. Dùng Jenkinsfile environment cho:
   - Public configs (ports, URLs)
   - Application names
   - Non-sensitive settings

3. Mask credentials trong logs:
   - Jenkins tự động mask credentials trong console output

### ❌ KHÔNG NÊN:
1. Hard-code passwords trong Jenkinsfile
2. Commit credentials vào Git
3. Echo credentials ra console: `echo $PASSWORD` (Jenkins sẽ mask nhưng vẫn không nên)

---

## 📝 Ví dụ: Update Jenkinsfile với Credentials

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
        
        // Public configs
        KAFKA_SERVERS = '42.112.38.103:9092'
        
        // Sensitive data from Jenkins Credentials
        JASYPT_PASSWORD = credentials('jasypt-password')
        GITHUB_TOKEN = credentials('github-credentials')
    }
    
    stages {
        stage('Checkout') {
            steps {
                git branch: "${params.GIT_BRANCH}",
                    url: 'https://github.com/lendbiz/apigatewayfiny.git',
                    credentialsId: 'github-credentials'
            }
        }
        
        stage('Build') {
            steps {
                sh """
                    gradle clean build \\
                        -Pspring.profiles.active=${SPRING_PROFILE} \\
                        -Djasypt.encryptor.password=${JASYPT_PASSWORD} \\
                        ${params.SKIP_TESTS ? '-x test' : ''}
                """
            }
        }
        
        stage('Deploy') {
            steps {
                script {
                    // Chỉ inject password vào container, không hardcode vào image
                    sh """
                        export CONTAINER_HOST=unix:///run/podman/podman.sock
                        
                        podman stop ${APP_NAME}-${ENVIRONMENT} 2>/dev/null || true
                        podman rm ${APP_NAME}-${ENVIRONMENT} 2>/dev/null || true
                        
                        podman run -d \\
                            --name ${APP_NAME}-${ENVIRONMENT} \\
                            --network podman \\
                            -e SPRING_PROFILES_ACTIVE=${SPRING_PROFILE} \\
                            -e JASYPT_ENCRYPTOR_PASSWORD=${JASYPT_PASSWORD} \\
                            -e KAFKA_BOOTSTRAP_SERVERS=${KAFKA_SERVERS} \\
                            -p ${APP_PORT}:9200 \\
                            --restart unless-stopped \\
                            ${APP_NAME}:${BUILD_NUMBER}
                    """
                }
            }
        }
    }
}
```

---

## 🎓 Tóm tắt

| Use Case | Phương pháp | Ví dụ |
|----------|------------|-------|
| Public config | Jenkinsfile `environment` | APP_NAME, ports |
| Passwords, API keys | Jenkins Credentials (Secret text) | DB password, Jasypt key |
| DB credentials | Jenkins Credentials (Username+Password) | DB_USER, DB_PASS |
| Large config files | Config File Provider | application-prod.properties |
| User choices | Parameters | ENVIRONMENT, GIT_BRANCH |
| Global settings | Jenkins Global Properties | JAVA_HOME, Maven path |

**Mọi sensitive data PHẢI dùng Jenkins Credentials!**
