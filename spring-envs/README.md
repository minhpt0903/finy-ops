# Spring Boot Environment Configurations

## Cấu trúc thư mục

```
spring-envs/
├── production/
│   └── application.properties          # Config cho môi trường production (branch: main)
├── test/
│   └── application.properties          # Config cho môi trường test (branch: test)
└── README.md
```

## Mapping Branch → Environment → Profile

| Git Branch | Environment | Spring Profile | Port | Database | Deploy URL |
|-----------|------------|----------------|------|----------|------------|
| `main` | production | `prod` | 9200 | DBLive | production server |
| `test` | test | `test` | 9201 | DBTest | test server |

## Cách sử dụng

### 1. Trong project Spring Boot

Tạo cấu trúc trong project:

```
your-spring-project/
└── src/
    └── main/
        └── resources/
            ├── application.properties              # Common config
            ├── application-prod.properties         # Production overrides
            └── application-test.properties         # Test overrides
```

#### application.properties (Common)
```properties
# Common configuration cho tất cả môi trường
spring.application.name=lendbiz-apigateway
server.servlet.context-path=/

# Jasypt configuration
jasypt.encryptor.password=lendbiZ@2023
jasypt.encryptor.algorithm=PBEWithMD5AndDES

# JPA common settings
spring.jpa.properties.hibernate.proc.param_null_passing=true
spring.jpa.hibernate.ddl-auto=none
spring.jpa.database-platform=org.hibernate.dialect.Oracle10gDialect
```

#### application-prod.properties
Copy nội dung từ `spring-envs/production/application.properties`

#### application-test.properties
Copy nội dung từ `spring-envs/test/application.properties`

### 2. Build với Gradle

```bash
# Build cho production (branch main)
./gradlew clean build -Pspring.profiles.active=prod

# Build cho test (branch test)
./gradlew clean build -Pspring.profiles.active=test
```

### 3. Run local với profile cụ thể

```bash
# Run với test profile
./gradlew bootRun --args='--spring.profiles.active=test'

# Hoặc
java -jar build/libs/lendbiz-apigateway.jar --spring.profiles.active=test

# Run với production profile
./gradlew bootRun --args='--spring.profiles.active=prod'
```

### 4. Jenkins Pipeline tự động

Jenkins sẽ tự động:
- **Branch `main`** → build với profile `prod` → deploy lên production port 9200
- **Branch `test`** → build với profile `test` → deploy lên test port 9201

#### Trigger build từ Jenkins:

```bash
# Build branch main (production)
curl -X POST http://localhost:8080/job/lendbiz-apigateway/buildWithParameters \
  --user admin:token \
  --data-urlencode "BRANCH_NAME=main"

# Build branch test
curl -X POST http://localhost:8080/job/lendbiz-apigateway/buildWithParameters \
  --user admin:token \
  --data-urlencode "BRANCH_NAME=test"
```

### 5. Docker/Podman với environment variables

```bash
# Run container với test profile
podman run -d \
  --name lendbiz-apigateway-test \
  -e SPRING_PROFILES_ACTIVE=test \
  -p 9201:9200 \
  lendbiz-apigateway:test-latest

# Run container với prod profile
podman run -d \
  --name lendbiz-apigateway-production \
  -e SPRING_PROFILES_ACTIVE=prod \
  -p 9200:9200 \
  lendbiz-apigateway:production-latest
```

## Quản lý Sensitive Data

### 1. Jasypt Encryption

Dữ liệu nhạy cảm đã được mã hóa với Jasypt:

```properties
# Encrypted values
spring.datasource.username=ENC(...)
spring.datasource.password=ENC(...)
spring.datasource.url=ENC(...)
```

### 2. Encrypt new values

```bash
# Install jasypt CLI
curl -L https://github.com/ulisesbocchio/jasypt-spring-boot/releases/download/3.0.5/jasypt-cli-3.0.5.jar -o jasypt.jar

# Encrypt a value
java -cp jasypt.jar org.jasypt.intf.cli.JasyptPBEStringEncryptionCLI \
  input="your-secret-value" \
  password="lendbiZ@2023" \
  algorithm=PBEWithMD5AndDES

# Output: ENC(encrypted_value_here)
```

### 3. Decrypt để verify

```bash
java -cp jasypt.jar org.jasypt.intf.cli.JasyptPBEStringDecryptionCLI \
  input="encrypted_value" \
  password="lendbiZ@2023" \
  algorithm=PBEWithMD5AndDES
```

## Environment-Specific Configurations

### Production (branch: main)

```properties
# Database: PRODUCTION
spring.datasource.username=ENC(C8kqb6zJ2hpV/LuQZFDeUA==)    # DBLive
spring.datasource.password=ENC(QwYy7AugLrAHQYJ+ZDvOQPjJ2I+/KDQw)

# Logging: Less verbose
logging.level.root=info
spring.jpa.show-sql=false

# Flyway: Production migrations
spring.flyway.locations=classpath:db/migration/production

# External URLs
econtract-gateway.url=https://econtract.finy.vn

# File upload limits
spring.servlet.multipart.max-file-size=50MB

# Kafka: Production settings
spring.kafka.producer.acks=all
spring.kafka.producer.retries=3
```

### Test (branch: test)

```properties
# Database: TEST
spring.datasource.username=ENC(nwtguNr2R6NJLqQzx0mpK2pYDTMCm5xI)    # DBTest
spring.datasource.password=ENC(WD+WD9iNhvaJkBJrpfI/vaKBAKskDxV9)

# Logging: More verbose for debugging
logging.level.root=info
logging.level.com.technology.apigateway=debug
spring.jpa.show-sql=true

# Flyway: Test migrations
spring.flyway.locations=classpath:db/migration/test

# External URLs
econtract-gateway.url=https://econtracttest.finy.vn

# File upload limits
spring.servlet.multipart.max-file-size=15MB

# Kafka: Test settings (less strict)
```

## Git Workflow

### Development Flow

```bash
# Feature development
git checkout -b feature/new-feature
git commit -am "Add new feature"

# Merge vào test để test
git checkout test
git merge feature/new-feature
git push origin test
# → Jenkins tự động build và deploy lên test environment

# Sau khi test OK, merge vào main
git checkout main
git merge test
git push origin main
# → Jenkins tự động build và deploy lên production
```

### Hotfix Flow

```bash
# Hotfix từ main
git checkout -b hotfix/critical-bug main
git commit -am "Fix critical bug"

# Merge vào test trước
git checkout test
git merge hotfix/critical-bug
git push origin test
# → Test trên environment test

# Nếu OK, merge vào main
git checkout main
git merge hotfix/critical-bug
git push origin main
# → Deploy production
```

## Monitoring & Logs

### Check application status

```bash
# Production
curl http://production-server:9200/actuator/health

# Test
curl http://test-server:9201/actuator/health
```

### View logs

```bash
# Production container
podman logs -f lendbiz-apigateway-production

# Test container
podman logs -f lendbiz-apigateway-test

# Log files (nếu mount volume)
tail -f /path/to/logs/production/spring.log
tail -f /path/to/logs/test/spring.log
```

## Troubleshooting

### Issue: Wrong profile being used

```bash
# Check active profile
curl http://localhost:9200/actuator/env | jq '.propertySources[] | select(.name | contains("applicationConfig"))'

# Or check logs
podman logs lendbiz-apigateway-test | grep "The following profiles are active"
```

### Issue: Database connection failed

```bash
# Verify encrypted credentials
# Decrypt and test manually with SQL client

# Check database connectivity from container
podman exec -it lendbiz-apigateway-test bash
nc -zv <db-host> 1521
```

### Issue: Kafka connection failed

```bash
# Check Kafka from container
podman exec -it lendbiz-apigateway-test bash
telnet 42.112.38.103 9092

# Verify Kafka topics
kafka-topics.sh --list --bootstrap-server 42.112.38.103:9092
```

## Best Practices

1. ✅ **Never commit unencrypted secrets** - Always use Jasypt ENC()
2. ✅ **Test on test environment first** - Merge test → main workflow
3. ✅ **Use different databases** - Test DB vs Production DB
4. ✅ **Monitor both environments** - Set up alerts
5. ✅ **Backup configurations** - Keep encrypted backups
6. ✅ **Document changes** - Update this README when adding configs
7. ✅ **Use feature flags** - For gradual rollout
8. ✅ **Rotate secrets regularly** - Re-encrypt with new passwords

## Security Checklist

- [ ] All passwords encrypted with Jasypt
- [ ] Different credentials for test/prod databases
- [ ] Jasypt master password stored securely (not in git)
- [ ] HTTPS enabled for external URLs
- [ ] Kafka authentication configured (if needed)
- [ ] Database connection pooling configured
- [ ] Rate limiting enabled
- [ ] Actuator endpoints secured
- [ ] Log files contain no sensitive data
- [ ] Regular security updates

## References

- [Spring Boot Profiles](https://docs.spring.io/spring-boot/docs/2.7.8/reference/html/features.html#features.profiles)
- [Jasypt Spring Boot](https://github.com/ulisesbocchio/jasypt-spring-boot)
- [Spring Boot Externalized Configuration](https://docs.spring.io/spring-boot/docs/2.7.8/reference/html/features.html#features.external-config)
