# Finy-Ops - Jenkins & Kafka Deployment Platform

Hệ thống CI/CD với Jenkins và Kafka để deploy các dự án Java Spring Boot.

## 📋 Yêu cầu hệ thống

- **Podman** >= 4.0 hoặc **Podman Desktop**
- **Podman Compose** hoặc **docker-compose** (compatible)
- **Java** 17+ (cho local development)
- **Gradle** 8.5+ (cho local build)
- Hệ điều hành: **RedHat Enterprise Linux 8/9**, Fedora, CentOS Stream, hoặc các distro khác

## 🚀 Khởi động

### 1. Cài đặt Podman (nếu chưa có)

**Red Hat Enterprise Linux 8/9:**
```bash
# Enable repository (nếu chưa có)
sudo subscription-manager repos --enable codeready-builder-for-rhel-9-$(arch)-rpms

# Cài đặt Podman và Podman Compose
sudo dnf install -y podman podman-compose podman-docker

# Enable và start Podman socket
sudo systemctl enable --now podman.socket
sudo systemctl enable --now podman

# Cho phép user thường dùng Podman (rootless)
sudo usermod -aG wheel $USER
```

**Fedora / CentOS Stream:**
```bash
# Cài đặt Podman
sudo dnf install -y podman podman-compose podman-docker

# Enable Podman socket
systemctl --user enable --now podman.socket
```

**Ubuntu/Debian:**
```bash
sudo apt-get update
sudo apt-get install -y podman podman-compose
```

### 2. Khởi động các services

```bash
# Di chuyển vào thư mục project
cd ~/projects/finy-ops

# Cấp quyền thực thi cho scripts
chmod +x start.sh stop.sh

# Khởi động tất cả services
./start.sh

# Hoặc manual:
podman-compose up -d

# Kiểm tra trạng thái
podman-compose ps
```

### 3. Truy cập các services

- **Jenkins**: http://localhost:8080
- **Kafka UI**: http://localhost:8090
- **Kafka Broker**: localhost:9092

### 4. Lấy mật khẩu Jenkins lần đầu

```bash
# Lấy initial admin password
podman exec jenkins cat /var/jenkins_home/secrets/initialAdminPassword
```

## 📦 Cấu hình Jenkins

### Cài đặt Plugins cần thiết

1. Truy cập Jenkins: http://localhost:8080
2. Đăng nhập với password từ bước 4
3. Chọn "Install suggested plugins"
4. Cài thêm các plugins:
   - Git Plugin
   - Pipeline Maven Integration
   - Docker Pipeline (hoặc Podman)
   - Kafka Plugin (optional)
   - Blue Ocean (UI đẹp hơn)

### Cấu hình Gradle & JDK trong Jenkins

1. **Manage Jenkins** → **Global Tool Configuration**
2. **Gradle installations**:
   - Name: `Gradle-8.5`
   - Install automatically từ Gradle.org
   - Version: 8.5 hoặc mới hơn
3. **JDK installations**:
   - Name: `JDK-17`
   - Install automatically từ Adoptium (Eclipse Temurin 17)

### Tạo Pipeline Job theo Branch

#### Cách 1: Multibranch Pipeline (Khuyến nghị)

```groovy
// Trong Jenkins UI:
1. New Item → Multibranch Pipeline
2. Branch Sources → Add Git
3. Repository URL: https://github.com/your-org/your-repo.git
4. Credentials: Add your GitHub token
5. Build Configuration:
   - Mode: by Jenkinsfile
   - Script Path: Jenkinsfile
6. Scan Multibranch Pipeline Triggers:
   - Periodically if not otherwise run: 5 minutes
```

#### Cách 2: Pipeline with Parameters

```groovy
// Trong Jenkins UI:
1. New Item → Pipeline
2. Check "This project is parameterized"
3. Add String Parameter:
   - Name: BRANCH_NAME
   - Default Value: main
4. Add Choice Parameter:
   - Name: ENVIRONMENT
   - Choices: dev, staging, production
5. Pipeline Script from SCM:
   - SCM: Git
   - Repository URL: your-repo-url
   - Branch: ${BRANCH_NAME}
   - Script Path: Jenkinsfile
```

## 🔧 Cấu hình Kafka

### Tạo topics

```bash
# Exec vào Kafka container
podman exec -it kafka bash

# Tạo topic
kafka-topics.sh --create \
  --bootstrap-server localhost:9092 \
  --topic jenkins-builds \
  --partitions 3 \
  --replication-factor 1

# List topics
kafka-topics.sh --list --bootstrap-server localhost:9092

# Describe topic
kafka-topics.sh --describe \
  --bootstrap-server localhost:9092 \
  --topic jenkins-builds
```

### Test Kafka từ Spring Boot

Thêm vào `application.yml`:

```yaml
spring:
  kafka:
    bootstrap-servers: kafkbuild.gradle`:

```gradle
dependencies {
    implementation 'org.springframework.boot:spring-boot-starter-web'
    implementation 'org.springframework.boot:spring-boot-starter-actuator'
    implementation 'org.springframework.kafka:spring-kafka'
    
    testImplementation 'org.springframework.boot:spring-boot-starter-test'
    testImplementation 'org.springframework.kafka:spring-kafka-test'
}
```

Hoặc copy file mẫu:
```bash
cp build.gradle.example your-project/build.gradle
cp settings.gradle.example your-project/settings.gradle

## 📝 Deploy Spring Boot Application
các file cần thiết vào root project

```bash
# Copy Jenkinsfile, Dockerfile và Gradle wrapper từ finy-ops vào project của bạn
cp Jenkinsfile /path/to/your-spring-boot-project/
cp Dockerfile /path/to/your-spring-boot-project/
cp gradlew /path/to/your-spring-boot-project/
cp build.gradle.example /path/to/your-spring-boot-project/build.gradle
cp settings.gradle.example /path/to/your-spring-boot-project/settings.gradle

# Cấp quyền thực thi cho gradlew
chmod +x /path/to/your-spring-boot-project/gradlew
<dependency>
    <groupId>org.springframework.kafka</groupId>
    <artifactId>spring-kafka</artifactId>
</dependency>

<dependency>
    <groupId>org.springframewo build.gradle settings.gradle gradlew
git commit -m "Add CI/CD configuration with Gradletuator</artifactId>
</dependency>
```

### 2. Copy Jenkinsfile vào root project

```bash
# Copy Jenkinsfile và Dockerfile từ finy-ops vào project của bạn
cp Jenkinsfile /path/to/your-spring-boot-project/
cp Dockerfile /path/to/your-spring-boot-project/
```

### 3. Commit và push code

```bash
cd /path/to/your-spring-boot-project
git add Jenkinsfile Dockerfile
git commit -m "Add CI/CD configuration"
git push origin main  # hoặc branch khác
```

### 4. Trigger build từ Jenkins

```bash
# Hoặc dùng Jenkins UI:
# 1. Chọn job
# 2. "Build with Parameters"
# 3. Nhập branch name: main/develop/feature-xxx
# 4. Chọn environment
# 5. Click "Build"

# Hoặc dùng API:
curl -X POST http://localhost:8080/job/your-job/buildWithParameters \
  --user admin:your-api-token \
  --data-urlencode "BRANCH_NAME=main" \
  --data-urlencode "ENVIRONMENT=dev"
```

## 🛠 Các lệnh hữu ích

### Podman Management

```bash
# Xem logs
podman-compose logs -f jenkins
podman-compose logs -f kafka

# Restart service
podman-compose restart jenkins

# Stop tất cả
podman-compose down

# Stop và xóa volumes
podman-compose down -v

# Xem resource usage
podman stats

# Cleanup images cũ
podman image prune -a
```

### Jenkins Management

```bash
# Backup Jenkins
podman exec jenkins tar czf /tmp/jenkins-backup.tar.gz /var/jenkins_home
podman cp jenkins:/tmp/jenkins-backup.tar.gz ./

# Restore Jenkins
podman cp jenkins-backup.tar.gz jenkins:/tmp/
podman exec jenkins tar xzf /tmp/jenkins-backup.tar.gz -C /
```

### Kafka Management

```bash
# Consumer test
podman exec -it kafka kafka-console-consumer.sh \
  --bootstrap-server localhost:9092 \
  --topic jenkins-builds \
  --from-beginning

# Producer test
echo "test message" | podman exec -i kafka kafka-console-producer.sh \
  --bootstrap-server localhost:9092 \
  --topic jenkins-builds

# Monitor consumer groups
podman exec kafka kafka-consumer-groups.sh \
  --bootstrap-server localhost:9092 \
  --list
```

## 🔐 Security Best Practices

1. **Thay đổi default credentials** sau khi setup
2. **Bật HTTPS** cho Jenkins production
3. **Sử dụng Jenkins Credentials Store** cho sensitive data
4. **Cấu hình Kafka authentication** cho production (SASL/SSL)
5. **Sử dụng secrets management** (HashiCorp Vault, AWS Secrets Manager)

## 📊 Monitoring

### Jenkins Metrics

- Truy cập: http://localhost:8080/monitoring
- Hoặc cài plugin: Prometheus Metrics Plugin

### Kafka Monitoring

- Kafka UI: http://localhost:8090
- JMX Metrics: Port 9999 (nếu enable)

## 🐛 Troubleshooting

### Jenkins không khởi động

```bash
# Check logs
podman logs jenkins

# Check permissions
podman exec jenkins ls -la /var/jenkins_home

# Restart with clean state
podman-compose down
podman volume rm fGradle not found

```bash
# Ensure Gradle tool is configured in Jenkins
# Manage Jenkins → Global Tool Configuration → Gradle
# Name: Gradle-8.5
# Install automatically: Yes
```

### Permission denied: gradlew

```bash
# Đảm bảo gradlew có quyền thực thi
chmod +x gradlew
git add gradlew
git commit -m "Fix gradlew permissions"
git push

```bash
# Check Kafka is running
podman ps | grep kafka

# Check Kafka logs
podman logs kafka

# Verify network (sử dụng default podman network)
podman network ls
podman network inspect podman

# Check container network
podman inspect kafka --format '{{.NetworkSettings.Networks}}'
```

### Build fails - Maven not found

```bash
# Ensure Maven tool is configured in Jenkins
# Manage Jenkins → Global Tool Configuration → Maven
```

## 📚 Tài liệu tham khảo

### Hướng dẫn cài đặt
- [QUICKSTART.md](QUICKSTART.md) - Bắt đầu nhanh trong 5 phút
- [REDHAT-SETUP.md](REDHAT-SETUP.md) - Hướng dẫn chi tiết cho RHEL 8/9
- [NETWORK-CONFIG.md](NETWORK-CONFIG.md) - Cấu hình network Podman

### Tài liệu kỹ thuật
- Podman: https://context7.com/containers/podman/llms.txt
- Jenkins: https://context7.com/jenkinsci/jenkins/llms.txt
- Kafka: https://context7.com/apache/kafka/llms.txt
- Spring Boot 2.7.8: https://docs.spring.io/spring-boot/docs/2.7.8/reference/html/

### Code Examples
- [examples/README.md](examples/README.md) - Kafka integration với Spring Boot
- [examples/KafkaProducerService.java](examples/KafkaProducerService.java) - Producer example
- [examples/KafkaConsumerService.java](examples/KafkaConsumerService.java) - Consumer example

## 🤝 Contributing

Mọi đóng góp đều được chào đón! Hãy tạo issue hoặc pull request.

## 📄 License

MIT License
