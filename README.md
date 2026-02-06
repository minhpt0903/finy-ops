# Finy-Ops - Jenkins CI/CD Platform với Podman

Hệ thống CI/CD tự động để deploy các dự án Java Spring Boot sử dụng Jenkins, Kafka và Podman.

## 📋 Mô tả hệ thống

- **Jenkins**: Build và deploy tự động từ GitHub
- **Apache Kafka**: Message broker cho microservices
- **Podman**: Container runtime (thay thế Docker, tiết kiệm tài nguyên)
- **Automated Pipeline**: Tự động build JAR → Build Image → Deploy Container

## 🔧 Yêu cầu hệ thống

- Ubuntu Server (đã cài Podman 4.9+)
- Port mở: 8080 (Jenkins), 9092 (Kafka), 8090 (Kafka UI), 9200-9201 (Apps)
- GitHub repository với Dockerfile
- Internet để pull dependencies

## 🚀 Cài đặt lần đầu

### Bước 1: Clone repository này

```bash
# Trên máy Windows (local)
git clone https://github.com/<your-org>/finy-ops.git
cd finy-ops

# Copy lên Ubuntu server
scp -r * minhpt@42.112.38.103:~/projects/finy-ops/
```

### Bước 2: Khởi động Infrastructure

```bash
# SSH vào Ubuntu server
ssh minhpt@42.112.38.103

# Chạy script khởi động
cd ~/projects/finy-ops
sudo sh ./start.sh
```

Script này sẽ:
- ✅ Tạo Podman network và volumes
- ✅ Start Jenkins container (với Podman CLI và socket access)
- ✅ Start Kafka (KRaft mode)
- ✅ Start Kafka UI
- ✅ Cấu hình tự động registries và permissions

### Bước 3: Lấy Jenkins password

```bash
# Password sẽ hiện ra sau khi start, hoặc chạy:
sudo podman exec jenkins cat /var/jenkins_home/secrets/initialAdminPassword
```

### Bước 4: Setup Jenkins

1. Mở trình duyệt: `http://42.112.38.103:8080`
2. Nhập initial admin password
3. Chọn **Install suggested plugins**
4. Tạo admin user
5. Cấu hình Jenkins URL: `http://42.112.38.103:8080`

### Bước 5: Cấu hình Jenkins Tools & Credentials

#### 5.1 Cài đặt Gradle Tool

**Dashboard → Manage Jenkins → Tools → Gradle installations**

- Name: `Gradle 8.0`
- Install automatically: ✅
- Version: **Gradle 8.0** (compatible với Spring Boot 2.7.8)

#### 5.2 Thêm GitHub Credentials

**Dashboard → Manage Jenkins → Credentials → System → Global credentials**

- Kind: `Username with password`
- Username: `<your-github-username>`
- Password: `<your-github-token>` (Personal Access Token)
- ID: `github-credentials`
- Description: `GitHub Access Token`

#### 5.3 Tạo Jenkins Job

**Dashboard → New Item**

- Name: `Finy` (hoặc tên project của bạn)
- Type: **Pipeline**
- OK

**Configuration:**

- **General:**
  - ✅ This project is parameterized
  - Add parameters:
    - `ENVIRONMENT`: Choice (test, production) - Default: test
    - `GIT_BRANCH`: String - Default: test
    - `SKIP_TESTS`: Boolean - Default: true

- **Pipeline:**
  - Definition: `Pipeline script from SCM`
  - SCM: `Git`
  - Repository URL: `https://github.com/<your-org>/finy-ops.git`
  - Credentials: `github-credentials`
  - Branch: `*/main`
  - Script Path: `Jenkinsfile`

- Save

## 📁 Cấu trúc Repository dự án (Ví dụ)

Repository Java Spring Boot của bạn cần có:

```
your-spring-boot-project/
├── src/
│   └── main/
│       ├── java/
│       └── resources/
│           ├── application.properties
│           ├── application-test.properties    # ⚠️ KHÔNG có spring.profiles.active
│           └── application-prod.properties
├── build.gradle (hoặc pom.xml)
├── Dockerfile                                # ⚠️ BẮT BUỘC
└── README.md
```

### Dockerfile mẫu

```dockerfile
FROM eclipse-temurin:17-jre
COPY build/libs/your-app.jar app.jar
ENTRYPOINT java -Dspring.profiles.active=${SPRING_PROFILES_ACTIVE:-production} -jar /app.jar
```

**⚠️ LƯU Ý QUAN TRỌNG:**

1. **ENTRYPOINT dùng shell form** (không có dấu ngoặc vuông) để expand environment variable
2. **KHÔNG định nghĩa `spring.profiles.active`** trong file `application-test.properties` hoặc `application-prod.properties`
   - Profile sẽ được inject từ Jenkins qua environment variable
   - Nếu có dòng này → XÓA ngay để tránh conflict

## 🎯 Sử dụng - Deploy ứng dụng

### Cách 1: Automated Deploy qua Jenkins (Khuyến nghị)

1. Mở Jenkins UI: `http://42.112.38.103:8080`
2. Click vào job **Finy**
3. Click **Build with Parameters**
4. Chọn options:
   - **Environment**: `test` hoặc `production`
   - **Git Branch**: `test` hoặc `main`
   - **Skip Tests**: `true` (khuyến nghị để build nhanh)
5. Click **Build**

**Pipeline sẽ tự động:**
- ✅ Checkout code từ GitHub
- ✅ Build JAR với Gradle 8.0
- ✅ Build Container Image với Podman
- ✅ Stop container cũ (nếu có)
- ✅ Deploy container mới
- ✅ Archive JAR artifacts

**Kết quả:**
- Test environment: `http://42.112.38.103:9201`
- Production: `http://42.112.38.103:9200`

### Cách 2: Manual Deploy (Backup)

```bash
# SSH vào server
ssh minhpt@42.112.38.103
cd ~/projects/finy-ops

# Deploy
./jenkins-deploy.sh test    # Hoặc: production
```

## 🔍 Monitoring & Troubleshooting

### Xem logs

```bash
# Jenkins logs
sudo podman logs -f jenkins

# Kafka logs
sudo podman logs -f kafka

# Application logs (replace với tên container)
sudo podman logs -f lendbiz-apigateway-test
```

### Kiểm tra containers

```bash
# List tất cả containers
sudo podman ps -a

# Inspect một container
sudo podman inspect jenkins
```

### Kiểm tra Podman socket

```bash
# Verify socket exists và có permission
sudo ls -la /run/podman/podman.sock

# Test từ Jenkins container
sudo podman exec jenkins sh -c 'export CONTAINER_HOST=unix:///run/podman/podman.sock && podman ps'
```

### Vào Kafka UI

```bash
# Mở browser
http://42.112.38.103:8090
```

### Restart services

```bash
# Restart Jenkins
sudo podman restart jenkins

# Restart Kafka
sudo podman restart kafka

# Restart application
sudo podman restart lendbiz-apigateway-test
```

## 🛑 Dừng hệ thống

```bash
# Dừng tất cả services
sudo sh ./stop.sh

# Hoặc dừng từng service
sudo podman stop jenkins kafka kafka-ui
```

## 📚 Services URLs

| Service | URL | Credentials |
|---------|-----|-------------|
| **Jenkins** | http://42.112.38.103:8080 | admin / (xem initial password) |
| **Kafka UI** | http://42.112.38.103:8090 | No auth |
| **Kafka Bootstrap** | 42.112.38.103:9092 | No auth |
| **App Test** | http://42.112.38.103:9201 | Depends on app |
| **App Production** | http://42.112.38.103:9200 | Depends on app |

## 🔐 Security Notes

- Jenkins admin password: Thay đổi sau lần đăng nhập đầu
- Kafka: Chưa có authentication (cân nhắc enable SASL cho production)
- Podman socket: Chỉ accessible từ Jenkins container với root group
- GitHub credentials: Sử dụng Personal Access Token, không dùng password

## ⚙️ Technical Details

- **Jenkins**: 2.541.1 LTS (JDK 17)
- **Kafka**: Apache Kafka 3.8.1 (KRaft mode, không cần Zookeeper)
- **Podman**: 4.9.3 rootful mode
- **Gradle**: 8.0 (compatible với Spring Boot 2.7.8)
- **Java Runtime**: Eclipse Temurin 17 JRE
- **Network**: Podman default bridge network

## 🐛 Common Issues

### Issue 1: `podman: not found` trong Jenkins build

**Nguyên nhân**: Podman CLI chưa được cài trong Jenkins container

**Giải pháp:**
```bash
# Recreate Jenkins container
sudo podman rm -f jenkins
sudo sh ./start.sh
```

### Issue 2: `permission denied` khi access socket

**Nguyên nhân**: User jenkins không có quyền truy cập `/run/podman/podman.sock`

**Giải pháp:**
```bash
sudo podman exec -u root jenkins usermod -aG root jenkins
sudo podman restart jenkins
```

### Issue 3: `spring.profiles.active` conflict

**Nguyên nhân**: Có định nghĩa `spring.profiles.active` trong file `application-test.properties`

**Giải pháp**: Xóa dòng này khỏi file properties trong repository

### Issue 4: `short-name "openjdk:17-oracle" did not resolve`

**Nguyên nhân**: Registry không được cấu hình hoặc image không tồn tại

**Giải pháp:**
```bash
# Cấu hình registry (đã được tự động setup)
sudo cat /etc/containers/registries.conf

# Dùng image khác trong Dockerfile (khuyến nghị)
FROM eclipse-temurin:17-jre
```

## 📞 Support

Nếu gặp vấn đề, check logs và verify:
1. ✅ Podman daemon đang chạy: `sudo podman info`
2. ✅ Socket có quyền đúng: `sudo ls -la /run/podman/podman.sock`
3. ✅ Jenkins có Podman CLI: `sudo podman exec jenkins podman --version`
4. ✅ Registry đã cấu hình: `sudo cat /etc/containers/registries.conf`
5. ✅ Dockerfile đúng format và image tồn tại

## 📄 License

Internal company use only.
