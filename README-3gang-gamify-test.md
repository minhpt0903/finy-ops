# 3gang-gamify-test Jenkins Pipeline

## Mục đích
Tự động build, tạo image, deploy và archive artifact cho ứng dụng 3gang-gamify-test môi trường test (branch: feature/tbg-3, port: 9005).

## Luồng pipeline
1. **Checkout**: Lấy code từ branch `feature/tbg-3` bằng credentials bảo mật.
2. **Build**: Build ứng dụng Java Spring Boot với profile `test`.
3. **Build Image**: Tạo image container bằng Podman.
4. **Deploy**: Deploy container, inject thông tin database và Kafka.
5. **Archive Artifacts**: Lưu file jar build được.

## Credentials cần tạo trên Jenkins
- `git-3gang-gamify-test-url`: Secret text (URL repo Git)
- `git-credentials`: Username with password (truy cập repo Git)
- `db-3gang-gamify-test-credentials`: Username with password (DB test)
- `db-3gang-gamify-test-url`: Secret text (JDBC URL DB test)

## Biến môi trường
- `APP_NAME`: 3gang-gamify
- `SPRING_PROFILE`: test
- `APP_PORT`: 9005

## Port public
- 9005 (ứng dụng Java)

## Branch
- feature/tbg-3

## Hướng dẫn
1. Tạo các credentials đúng ID như trên trong Jenkins.
2. Đảm bảo Podman socket đã mount vào container Jenkins.
3. Trigger pipeline để kiểm tra build và deploy.

## Tham khảo Jenkinsfile
Xem file `Jenkinsfile-3gang-gamify-test` trong repo.

---
Nếu cần thêm môi trường hoặc branch khác, hãy bổ sung thông tin tương ứng.