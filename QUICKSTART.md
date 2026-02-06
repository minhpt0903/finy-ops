# 🚀 Quick Start Guide

Hướng dẫn nhanh để deploy ứng dụng Java Spring Boot với Jenkins CI/CD.

## 1️⃣ Khởi động Infrastructure (5 phút)

```bash
# SSH vào Ubuntu server
ssh minhpt@42.112.38.103
cd ~/projects/finy-ops

# Chạy một lệnh duy nhất
sudo sh ./start.sh
```

**Kết quả:**
- ✅ Jenkins: http://42.112.38.103:8080
- ✅ Kafka UI: http://42.112.38.103:8090
- ✅ Kafka: 42.112.38.103:9092

## 2️⃣ Setup Jenkins (10 phút)

### Bước 1: Unlock Jenkins

```bash
# Lấy password
sudo podman exec jenkins cat /var/jenkins_home/secrets/initialAdminPassword
```

Copy password → Mở http://42.112.38.103:8080 → Paste

### Bước 2: Install Plugins

- Click "Install suggested plugins"
- Chờ cài đặt xong (~3 phút)

### Bước 3: Tạo Admin User

- Username: `admin`
- Password: `<your-password>`
- Email: `<your-email>`
- Full Name: `Admin`
- Save and Continue

### Bước 4: Cấu hình Gradle

**Manage Jenkins → Tools → Gradle installations**

- Click "Add Gradle"
- Name: `Gradle 8.0`
- Install automatically: ✅
- Version: **Gradle 8.0**
- Save

### Bước 5: Thêm GitHub Credentials

**Manage Jenkins → Credentials → System → Global credentials → Add Credentials**

- Kind: `Username with password`
- Username: `<your-github-username>`
- Password: `<your-github-personal-access-token>`
- ID: `github-credentials`
- Description: `GitHub Access`
- Create

### Bước 6: Tạo Jenkins Job

**Dashboard → New Item**

- Name: `Finy`
- Type: **Pipeline**
- OK

**Configuration:**

1. **General** → ✅ This project is parameterized
   
   Add 3 parameters:
   
   a. **Choice Parameter**:
   - Name: `ENVIRONMENT`
   - Choices: (nhập từng dòng)
     ```
     test
     production
     ```
   - Default: `test`
   
   b. **String Parameter**:
   - Name: `GIT_BRANCH`
   - Default Value: `test`
   - Description: `Git branch to build`
   
   c. **Boolean Parameter**:
   - Name: `SKIP_TESTS`
   - Default: `true`

2. **Pipeline**:
   - Definition: `Pipeline script from SCM`
   - SCM: `Git`
   - Repository URL: `https://github.com/lendbiz/apigatewayfiny.git` (thay bằng repo của bạn)
   - Credentials: `github-credentials`
   - Branch Specifier: `*/main`
   - Script Path: `Jenkinsfile`

3. **Save**

## 3️⃣ Chuẩn bị Repository (5 phút)

### Kiểm tra Dockerfile trong repository

```dockerfile
FROM eclipse-temurin:17-jre
COPY build/libs/your-app.jar app.jar
ENTRYPOINT java -Dspring.profiles.active=${SPRING_PROFILES_ACTIVE:-production} -jar /app.jar
```

### Kiểm tra application properties

**⚠️ QUAN TRỌNG**: Trong `application-test.properties` và `application-prod.properties`:

**KHÔNG ĐƯỢC CÓ:**
```properties
spring.profiles.active=test   # ❌ XÓA dòng này!
```

**CHỈ CẦN:**
```properties
spring.application.name=your-app-name
# ... các config khác
```

## 4️⃣ Deploy lần đầu (2 phút)

1. Mở Jenkins: http://42.112.38.103:8080
2. Click vào job **Finy**
3. Click **Build with Parameters**
4. Chọn:
   - Environment: `test`
   - Git Branch: `test`
   - Skip Tests: `true`
5. Click **Build**

**Chờ kết quả** (~2-5 phút tùy kích thước project):

- ✅ Stage 1: Checkout
- ✅ Stage 2: Build (Gradle)
- ✅ Stage 3: Build Image (Podman)
- ✅ Stage 4: Deploy
- ✅ Stage 5: Archive

## 5️⃣ Kiểm tra kết quả

```bash
# Xem container đang chạy
sudo podman ps

# Xem logs ứng dụng
sudo podman logs -f lendbiz-apigateway-test

# Test API (thay đổi URL phù hợp)
curl http://42.112.38.103:9201/health
```

**Test environment**: http://42.112.38.103:9201  
**Production**: http://42.112.38.103:9200

## ⚡ Deploy lần sau

Sau khi setup xong, deploy chỉ cần 3 clicks:

1. Mở Jenkins → Job "Finy"
2. Build with Parameters → chọn environment/branch
3. Build

**Tất cả sẽ tự động!**

## 🐛 Gặp lỗi?

### Build failed: `podman: not found`

```bash
sudo podman restart jenkins
# Chờ 30 giây rồi build lại
```

### Build failed: `spring.profiles.active conflict`

Vào repository, xóa dòng `spring.profiles.active=xxx` trong `application-test.properties`

### Container không start

```bash
# Xem logs
sudo podman logs lendbiz-apigateway-test

# Restart
sudo podman restart lendbiz-apigateway-test
```

## 📚 Chi tiết đầy đủ

Xem [README.md](README.md) để biết thêm chi tiết và troubleshooting.

---

**Tổng thời gian setup**: ~20 phút lần đầu  
**Thời gian deploy sau này**: 2-5 phút (tự động)
