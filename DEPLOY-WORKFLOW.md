# Workflow Deploy với Jenkins + Podman

## Tổng quan

Jenkins chỉ build JAR file, deploy bằng Podman thủ công để tiết kiệm tài nguyên.

## Workflow

```
┌─────────────┐
│   Jenkins   │ 1. Checkout code
│             │ 2. Build JAR với Gradle
│             │ 3. Archive artifact
└──────┬──────┘
       │
       │ Download JAR
       ▼
┌─────────────┐
│   Manual    │ 1. Download JAR từ Jenkins
│   Deploy    │ 2. Chạy jenkins-deploy.sh
│   (Podman)  │ 3. Podman build + run
└─────────────┘
```

## Bước 1: Build với Jenkins

1. Truy cập Jenkins: http://localhost:8080
2. Mở job **Finy** (hoặc tên job của bạn)
3. Click **Build with Parameters**
4. Chọn:
   - **ENVIRONMENT**: `test` hoặc `production`
   - **GIT_BRANCH**: `test`, `main`, ...
   - **SKIP_TESTS**: `true` (mặc định)
5. Click **Build**

**Kết quả:** Jenkins build JAR và lưu trong Artifacts

## Bước 2: Download JAR

Sau khi build thành công:

1. Click vào build number (ví dụ: #15)
2. Click **Build Artifacts**
3. Download file `.jar`
4. Copy vào thư mục project (nơi có `Dockerfile`)

**Hoặc dùng command:**

```bash
# Lấy JAR từ Jenkins workspace
podman cp jenkins:/var/jenkins_home/workspace/Finy/build/libs/apigateway-0.1.jar ./build/libs/
```

## Bước 3: Deploy với Podman

### Option 1: Dùng script tự động

```bash
# Deploy môi trường test
./jenkins-deploy.sh test

# Deploy môi trường production
./jenkins-deploy.sh production
```

### Option 2: Deploy thủ công

#### Deploy môi trường TEST (port 9201):

```bash
# Build image
podman build -t lendbiz-apigateway:test .

# Stop container cũ (nếu có)
podman stop lendbiz-apigateway-test
podman rm lendbiz-apigateway-test

# Run container
podman run -d --name lendbiz-apigateway-test \
  --network podman \
  -e SPRING_PROFILES_ACTIVE=test \
  -e SPRING_KAFKA_BOOTSTRAP_SERVERS=42.112.38.103:9092 \
  -p 9201:9200 \
  --restart unless-stopped \
  lendbiz-apigateway:test

# Check logs
podman logs -f lendbiz-apigateway-test
```

#### Deploy môi trường PRODUCTION (port 9200):

```bash
# Build image
podman build -t lendbiz-apigateway:production .

# Stop container cũ (nếu có)
podman stop lendbiz-apigateway-production
podman rm lendbiz-apigateway-production

# Run container
podman run -d --name lendbiz-apigateway-production \
  --network podman \
  -e SPRING_PROFILES_ACTIVE=prod \
  -e SPRING_KAFKA_BOOTSTRAP_SERVERS=42.112.38.103:9092 \
  -p 9200:9200 \
  --restart unless-stopped \
  lendbiz-apigateway:production

# Check logs
podman logs -f lendbiz-apigateway-production
```

## Kiểm tra ứng dụng

```bash
# Test environment
curl http://localhost:9201/actuator/health

# Production environment
curl http://localhost:9200/actuator/health
```

## Quản lý containers

```bash
# Xem containers đang chạy
podman ps | grep lendbiz

# Xem logs
podman logs -f lendbiz-apigateway-test
podman logs -f lendbiz-apigateway-production

# Restart
podman restart lendbiz-apigateway-test
podman restart lendbiz-apigateway-production

# Stop
podman stop lendbiz-apigateway-test
podman stop lendbiz-apigateway-production

# Remove
podman rm -f lendbiz-apigateway-test
podman rm -f lendbiz-apigateway-production
```

## Rollback

Nếu cần rollback về version cũ:

```bash
# Xem images
podman images | grep lendbiz-apigateway

# Stop container hiện tại
podman stop lendbiz-apigateway-production

# Run version cũ
podman run -d --name lendbiz-apigateway-production \
  --network podman \
  -e SPRING_PROFILES_ACTIVE=prod \
  -e SPRING_KAFKA_BOOTSTRAP_SERVERS=42.112.38.103:9092 \
  -p 9200:9200 \
  --restart unless-stopped \
  lendbiz-apigateway:production-old
```

## Troubleshooting

### Lỗi: Port already in use

```bash
# Tìm và stop container đang dùng port
podman ps | grep 9201
podman stop <container_name>
```

### Lỗi: Cannot connect to Kafka

```bash
# Kiểm tra Kafka đang chạy
podman ps | grep kafka

# Kiểm tra network
podman network inspect podman
```

### Lỗi: Application not starting

```bash
# Xem logs chi tiết
podman logs lendbiz-apigateway-test

# Check container status
podman ps -a | grep lendbiz

# Restart container
podman restart lendbiz-apigateway-test
```

## Tự động hóa (Optional)

Nếu muốn tự động deploy sau khi Jenkins build, có thể:

1. Setup Jenkins Post-build Actions
2. Dùng webhook để trigger deploy script
3. Dùng cron job để monitor Jenkins artifacts

**Nhưng hiện tại workflow thủ công đơn giản và tiết kiệm tài nguyên hơn.**
