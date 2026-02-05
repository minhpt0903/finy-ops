# 🚀 Quick Start - Finy-Ops

## Khởi động nhanh trong 5 phút

### 1. Khởi động platform (Windows)

```powershell
# Mở PowerShell tại thư mục finy-ops
cd d:\projects\finy-ops

# Chạy script khởi động
.\start.ps1
```

### 2. Khởi động platform (Linux/Mac)

```bash
# Mở terminal tại thư mục finy-ops
cd ~/projects/finy-ops

# Cấp quyền thực thi
chmod +x start.sh stop.sh

# Chạy script khởi động
./start.sh
```

### 3. Truy cập services

Sau khi khởi động thành công:

- **Jenkins**: http://localhost:8080
  - Copy password từ terminal output
  - Hoặc chạy: `podman exec jenkins cat /var/jenkins_home/secrets/initialAdminPassword`
  
- **Kafka UI**: http://localhost:8090
  - Không cần password, truy cập luôn
  
- **Kafka Broker**: `localhost:9092`
  - Dùng trong Spring Boot config

### 4. Setup Jenkins (lần đầu)

1. Paste password vào Jenkins
2. Click "Install suggested plugins" 
3. Tạo admin user
4. Finish!

### 5. Tạo Pipeline Job

#### Cách A: Multibranch Pipeline (Khuyến nghị)

```
1. New Item → Multibranch Pipeline
2. Tên: "my-spring-boot-app"
3. Branch Sources:
   - Add source: Git
   - Repository URL: https://github.com/your-org/your-repo.git
   - Credentials: Add token GitHub
4. Build Configuration:
   - Mode: by Jenkinsfile
   - Script Path: Jenkinsfile
5. Save
```

#### Cách B: Pipeline with Parameters

```
1. New Item → Pipeline
2. Check "This project is parameterized"
3. Add String Parameter:
   - Name: BRANCH_NAME
   - Default: main
4. Add Choice Parameter:
   - Name: ENVIRONMENT
   - Choices: dev, staging, production
5. Pipeline:
   - Definition: Pipeline script from SCM
   - SCM: Git
   - Repository: your-repo-url
   - Branch: ${BRANCH_NAME}
   - Script Path: Jenkinsfile
6. Save
```

### 6. Deploy Spring Boot App

#### Bước 1: Chuẩn bị project

```bash
cd your-spring-boot-project

# Copy files từ finy-ops
cp ../finy-ops/Jenkinsfile .
cp ../finy-ops/Dockerfile .
cp ../finy-ops/application.yml.example src/main/resources/application-prod.yml
```

#### Bước 2: Thêm Kafka dependency

Thêm vào `build.gradle`:

```gradle
dependencies {
    implementation 'org.springframework.kafka:spring-kafka'
    implementation 'org.springframework.boot:spring-boot-starter-actuator'
}
```

Hoặc copy file mẫu:
```bash
cp ../finy-ops/build.gradle.example build.gradle
cp ../finy-ops/settings.gradle.example settings.gradle
```

#### Bước 3: Commit & push

```bash
# Cấp quyền thực thi cho gradlew
chmod +x gradlew

git add Jenkinsfile Dockerfile build.gradle settings.gradle gradlew gradle/
git commit -m "Add CI/CD configuration with Gradle"
git push origin main
```

#### Bước 4: Build từ Jenkins

1. Vào Jenkins → chọn job
2. Click "Build with Parameters"
3. Nhập:
   - BRANCH_NAME: `main`
   - ENVIRONMENT: `dev`
4. Click "Build"
5. Xem logs trong Console Output

### 7. Test Kafka Integration

#### Tạo Kafka topic

```bash
podman exec -it kafka kafka-topics.sh --create \
  --bootstrap-server localhost:9092 \
  --topic test-topic \
  --partitions 3 \
  --replication-factor 1
```

#### Test Producer

```bash
echo "Hello Kafka" | podman exec -i kafka kafka-console-producer.sh \
  --bootstrap-server localhost:9092 \
  --topic test-topic
```

#### Test Consumer

```bash
podman exec -it kafka kafka-console-consumer.sh \
  --bootstrap-server localhost:9092 \
  --topic test-topic \
  --from-beginning
```

### 8. Stop Platform

**Windows:**
```powershell
.\stop.ps1
```

**Linux/Mac:**
```bash
./stop.sh
```

## 🎯 Next Steps

1. ✅ Platform đã chạy
2. 📝 Đọc [README.md](README.md) để hiểu chi tiết
3. 💻 Xem [examples/](examples/) để tích hợp Kafka vào code
4. 🔧 Customize Jenkinsfile cho project của bạn
5. 🚀 Deploy your apps!

## 📌 Common Commands

```bash
# Xem logs
podman logs -f jenkins
podman logs -f kafka

# Restart service
podman restart jenkins

# Check status
podman ps

# Clean up
podman-compose down -v  # Xóa cả volumes
```

## ❓ Troubleshooting

**Jenkins không start?**
```bash
podman logs jenkins
# Check port 8080 có bị chiếm không
```

**Kafka connection refused?**
```bash
podman logs kafka
# Đợi 30s để Kafka hoàn tất khởi động
```

**Build fails - Gradle not found?**
```
Jenkins → Manage Jenkins → Global Tool Configuration → Gradle
Add: Gradle-8.5 (auto-install)
```

**Permission denied: ./gradlew?**
```bash
chmod +x gradlew
git add gradlew
git commit --amend --no-edit
git push -f
```

## 📚 Tài liệu đầy đủ

- [README.md](README.md) - Hướng dẫn chi tiết
- [examples/README.md](examples/README.md) - Kafka integration code
- [Podman Docs](https://context7.com/containers/podman/llms.txt)
- [Jenkins Docs](https://context7.com/jenkinsci/jenkins/llms.txt)
- [Kafka Docs](https://context7.com/apache/kafka/llms.txt)

---

**Happy Coding! 🎉**
