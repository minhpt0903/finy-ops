# Setup Test Credentials - Quick Practice Guide

Hướng dẫn nhanh để setup test credentials trong Jenkins - để thực hành workflow an toàn.

## 🎯 Tại sao setup credentials cho TEST?

**Lợi ích:**
- ✅ Thực hành workflow giống production ngay từ đầu
- ✅ Không commit sensitive data vào Git (kể cả test)
- ✅ Dễ dàng thay đổi test DB credentials
- ✅ Nhất quán giữa test và production

**Jenkinsfile đã sẵn sàng** - inject credentials cho cả test và production!

---

## 📋 Bước 1: Lấy test credentials hiện tại

Credentials đang có trong `application-test.properties` cũ:

```properties
spring.datasource.url=ENC(WihXytinrZ4IMjvF6lxkRT3uaVFT8vvifJlfA5KVFIjCxJZqo/4vHt8pWA++sD8TAjgOOJxHiIg=)
spring.datasource.username=ENC(nwtguNr2R6NJLqQzx0mpK2pYDTMCm5xI)
spring.datasource.password=ENC(WD+WD9iNhvaJkBJrpfI/vaKBAKskDxV9)
```

**Bạn cần decrypt ra plain text để setup trong Jenkins:**

### Option 1: Lấy từ application server hiện tại

```bash
# SSH vào test server và check application.properties đang dùng
# hoặc
# Hỏi team member có DB test credentials
```

### Option 2: Dùng Jasypt để decrypt

```bash
# Nếu có Jasypt CLI và biết password (lendbiZ@2023):
java -cp jasypt-1.9.3.jar org.jasypt.intf.cli.JasyptPBEStringDecryptionCLI \
     input="nwtguNr2R6NJLqQzx0mpK2pYDTMCm5xI" \
     password="lendbiZ@2023" \
     algorithm=PBEWithMD5AndDES
```

**Ví dụ credentials giả (thay bằng thực tế):**
- URL: `jdbc:oracle:thin:@test-db-host:1521/testdb`
- Username: `test_user`
- Password: `test_password_123`

---

## 📋 Bước 2: Setup Test Credentials trong Jenkins

### 2.1. Mở Jenkins UI

```
http://42.112.38.103:8080
```

Login với admin account

---

### 2.2. Tạo Database Test URL

**Navigate to:** Manage Jenkins → Credentials → System → Global credentials (unrestricted)

**Click:** Add Credentials

**Fill form:**
```
Kind: Secret text
Scope: Global (Jenkins, nodes, items, all child items, etc)
Secret: jdbc:oracle:thin:@test-db-host:1521/testdb
ID: db-test-url
Description: Test Database JDBC URL
```

**Click:** Create

---

### 2.3. Tạo Database Test Credentials

**Click:** Add Credentials (lại)

**Fill form:**
```
Kind: Username with password
Scope: Global
Username: test_user
Password: test_password_123
ID: db-test-credentials
Description: Test Database Credentials
```
**Click:** Create

### 2.4. Tạo github account Test Credentials

**Click:** Add Credentials (lại)

**Fill form:**
```
Kind: Username with password
Scope: Global
Username: test_user
Password: test_password_123
ID: git-credentials
Description: Github Account Credentials
```

**Click:** Create

---

### 2.5. Tạo Github finy api URL


**Click:** Add Credentials  (lại)

**Fill form:**
```
Kind: Secret text
Scope: Global (Jenkins, nodes, items, all child items, etc)
Secret: https://github.com/your-original/repository.git
ID: git-finy-api-test-url
Description: GITHUB FINY API URL
```

**Click:** Create

---

## ✅ Bước 3: Verify Credentials

**Manage Jenkins → Credentials**

Bạn sẽ thấy:

| ID | Type | Description |
|----|------|-------------|
| `db-test-url` | Secret text | Test Database JDBC URL |
| `db-test-credentials` | Username with password | Test Database Credentials |
| `db-production-url` | Secret text | Production Database JDBC URL *(chưa setup)* |
| `db-production-credentials` | Username with password | Production Database Credentials *(chưa setup)* |
| `git-finy-api-test-url` | Secret text | GITHUB URL |
| `git-credentials` | Username with password | GITHUB ACCOUNT USERNAME/TOKEN |

---

## 🚀 Bước 4: Test Build

### 4.1. Trigger build

**Jenkins → Job "Finy" → Build with Parameters**

```
Environment: test
Git Branch: test
Skip Tests: true
```

**Click:** Build

---

### 4.2. Check Build Log

**Console Output** sẽ show:

```bash
========================================
Deploying to test environment
Spring Profile: test
Container: lendbiz-apigateway-test
Port: 9201:9200
========================================
🔐 Loading credentials from Jenkins Credentials...
[INFO] Using credentials 'db-test-credentials'
[INFO] Using secret 'db-test-url'

# Stop old container
podman stop lendbiz-apigateway-test 2>/dev/null || true
podman rm lendbiz-apigateway-test 2>/dev/null || true

# Run new container with injected credentials
podman run -d --name lendbiz-apigateway-test \
    -e SPRING_DATASOURCE_URL=**** \       # ← Masked by Jenkins
    -e SPRING_DATASOURCE_USERNAME=**** \  # ← Masked
    -e SPRING_DATASOURCE_PASSWORD=**** \  # ← Masked
    -e SPRING_KAFKA_BOOTSTRAP_SERVERS=42.112.38.103:9092 \
    -p 9201:9200 \
    lendbiz-apigateway:test-10

✅ TEST deployed with injected credentials
```

---

### 4.3. Verify Application

```bash
# SSH to server
ssh minhpt@42.112.38.103

# Check container running
sudo podman ps | grep test

# Check logs
sudo podman logs lendbiz-apigateway-test | grep -i "started"
# Output: Started Application in 15.234 seconds ✅

# Test API
curl http://localhost:9201/actuator/health
# {"status":"UP"}  ✅
```

---

## 🎓 So sánh: Trước vs Sau

### ❌ Trước (credentials trong properties file)

```properties
# application-test.properties - committed to Git
spring.datasource.url=ENC(xxx)
spring.datasource.username=ENC(yyy)
spring.datasource.password=ENC(zzz)
```

**Vấn đề:**
- Credentials trong Git (encrypted nhưng vẫn không an toàn)
- Thay đổi phải commit code mới
- Không có audit log

---

### ✅ Sau (credentials từ Jenkins)

```properties
# application-test.properties - committed to Git
# Không có credentials!
spring.kafka.bootstrap-servers=42.112.38.103:9092
spring.flyway.locations=classpath:db/migration/test
```

**Jenkins Credentials:**
- `db-test-url`: jdbc:oracle:thin:@...
- `db-test-credentials`: test_user / ****

**Runtime Injection:**
```bash
podman run -d \
    -e SPRING_DATASOURCE_URL=${DB_URL} \      # From Jenkins
    -e SPRING_DATASOURCE_USERNAME=${DB_USER} \ # From Jenkins
    -e SPRING_DATASOURCE_PASSWORD=${DB_PASS} \ # From Jenkins
    your-app
```

**Lợi ích:**
- ✅ Credentials không trong Git
- ✅ Thay đổi không cần commit code
- ✅ Jenkins audit log
- ✅ Masked trong build logs

---

## 🔄 Workflow hoàn chỉnh

```
1. Developer commit code (không có credentials)
   ↓
2. Push to GitHub (branch: test)
   ↓
3. Trigger Jenkins build
   ↓
4. Jenkins checkout code
   ↓
5. Jenkins load credentials (db-test-credentials, db-test-url)
   ↓
6. Gradle build JAR
   ↓
7. Podman build image
   ↓
8. Podman run với credentials inject:
   -e SPRING_DATASOURCE_URL=${DB_URL}
   -e SPRING_DATASOURCE_USERNAME=${DB_USER}
   -e SPRING_DATASOURCE_PASSWORD=${DB_PASS}
   ↓
9. Application start → Connect DB thành công ✅
```

---

## 🐛 Troubleshooting

### Issue 1: Credentials không tìm thấy

**Error:** `Credentials 'db-test-credentials' could not be found`

**Solution:**
1. Verify ID chính xác: `db-test-credentials` (không phải `test-db-credentials`)
2. Check Scope = **Global**
3. Restart Jenkins: `sudo podman restart jenkins`

---

### Issue 2: Application không connect được DB

**Check logs:**
```bash
sudo podman logs lendbiz-apigateway-test | grep -i error
```

**Common causes:**
1. JDBC URL sai format
2. DB username/password không đúng
3. Network không reach được DB host

**Test connection từ server:**
```bash
telnet test-db-host 1521
```

---

### Issue 3: Credentials vẫn bị lộ trong logs

**Jenkins tự động mask credentials**, nhưng nếu thấy:

```bash
# ✅ ĐÚNG - Masked:
-e SPRING_DATASOURCE_PASSWORD=****

# ❌ SAI - Plain text:
-e SPRING_DATASOURCE_PASSWORD=test_password_123
```

**Solution:** Check Jenkins Mask Passwords plugin đã enable

---

## 📚 Next Steps

### 1. Sau khi test thành công:

✅ **Bạn đã thực hành xong workflow:**
- Setup credentials trong Jenkins
- Properties files không có sensitive data
- Build tự động inject credentials
- Application chạy thành công

### 2. Apply cho Production:

Làm tương tự cho production:
- Tạo `db-production-url`
- Tạo `db-production-credentials`
- Build với environment = production
- Jenkins tự động inject production credentials

👉 **Chi tiết:** [PRODUCTION-CREDENTIALS-SETUP.md](PRODUCTION-CREDENTIALS-SETUP.md)

---

## ✅ Checklist

Test credentials workflow:

- [ ] Copy application-test.properties mới vào project (không có credentials)
- [ ] Commit và push lên GitHub branch test
- [ ] Decrypt test credentials hiện tại (hoặc lấy từ team)
- [ ] Tạo `db-test-url` trong Jenkins Credentials
- [ ] Tạo `db-test-credentials` trong Jenkins Credentials
- [ ] Build test trong Jenkins → Thành công
- [ ] Check logs → Credentials được masked
- [ ] Check application → Connect DB thành công
- [ ] ✅ Workflow hoạt động!

---

**Thực hành xong test → Sẵn sàng cho production! 🎓**
