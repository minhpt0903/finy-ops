# Spring Properties Configuration Templates

Thư mục này chứa các file properties mẫu được tối ưu cho CI/CD với Jenkins.

## 📁 Cấu trúc

```
spring-envs/
├── application.properties          # ⭐ Config chung cho TẤT CẢ môi trường
├── application-test.properties     # Config riêng cho TEST
├── application-prod.properties     # Config riêng cho PRODUCTION
└── README.md
```

## ⚙️ Cách hoạt động

### Profile được inject từ Jenkins → Spring Boot tự động load đúng file

```
Jenkins sets: SPRING_PROFILES_ACTIVE=test
    ↓
Dockerfile: -Dspring.profiles.active=${SPRING_PROFILES_ACTIVE}
    ↓
Spring Boot loads:
    1. application.properties (config chung)
    2. application-test.properties (override cho test)
```

## 📋 Nội dung từng file

| File | Chứa gì | Ví dụ |
|------|---------|-------|
| **application.properties** | Config **CHUNG** cho tất cả môi trường | Logging, Jasypt, JPA settings, Kafka serialization, Flyway common, OpenAPI |
| **application-test.properties** | Config **RIÊNG TEST** | Test DB credentials, Test Kafka URL, test migration path |
| **application-prod.properties** | Config **RIÊNG PROD** | Prod DB credentials, Prod Kafka URL, prod migration path |

### ⚠️ QUAN TRỌNG

**KHÔNG được có `spring.profiles.active=xxx` trong BẤT KỲ file properties nào!**

❌ **SAI:**
```properties
# Trong application-test.properties:
spring.profiles.active=test    # ← XÓA dòng này!
```

✅ **ĐÚNG:** Profile được inject từ Jenkins environment variable

## 🚀 Cách sử dụng

### Bước 1: Copy vào dự án

```bash
# Copy 3 files vào Spring Boot project:
cp spring-envs/*.properties your-project/src/main/resources/
```

### Bước 2: Update credentials

**application-test.properties:**
```properties
spring.datasource.url=ENC(...)
spring.datasource.username=ENC(...)
spring.datasource.password=ENC(...)
spring.kafka.bootstrap-servers=42.112.38.103:9092
```

**application-prod.properties:**
```properties
# ⚠️ Thay đổi với production credentials thực tế!
spring.datasource.url=ENC(...)
spring.datasource.username=ENC(...)
spring.datasource.password=ENC(...)
spring.kafka.bootstrap-servers=<production-kafka-url>
```

### Bước 3: Commit và push

```bash
git add src/main/resources/application*.properties
git commit -m "feat: Configure environment-specific properties"
git push
```

### Bước 4: Build trong Jenkins

Jenkins tự động inject profile → Application chạy với config đúng môi trường.

## ✅ Best Practices

1. **Config chung** → Chỉ đặt trong `application.properties`
2. **Config riêng môi trường** → Override trong `application-{profile}.properties`
3. **Sensitive data** → Encrypt với Jasypt: `ENC(...)`
4. **KHÔNG duplicate config** giữa các files

## 🔐 Encrypt credentials với Jasypt

```bash
java -cp jasypt-1.9.3.jar org.jasypt.intf.cli.JasyptPBEStringEncryptionCLI \
     input="your-password" \
     password="lendbiZ@2023" \
     algorithm=PBEWithMD5AndDES

# Output: ENC(xxxxxxxxx)
```

## 📚 Xem thêm

- [Jenkins Environment Variables Guide](../JENKINS-ENV-VARS-GUIDE.md)
- [QUICKSTART.md](../QUICKSTART.md) - Setup Jenkins từ đầu
- [README.md](../README.md) - Full documentation
