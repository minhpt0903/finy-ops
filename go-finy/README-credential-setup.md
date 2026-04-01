# Hướng dẫn setup Credential cho go-finy

Để pipeline Jenkins hoạt động đúng với dự án go-finy, bạn cần chuẩn bị các credential sau trong Jenkins và cấu hình tương ứng với file Jenkinsfile-go-finy-production.

## 1. Credential Jenkins cần tạo

### 1.1. Git Repository
- **ID:** `git-go-finy-url`
- **Loại:** Secret text
- **Giá trị:** URL repo git của dự án go-finy

- **ID:** `git-credentials`
- **Loại:** Username with password
- **Giá trị:** Tài khoản truy cập repo

### 1.2. Database
- **ID:** `db-go-finy-prod-credentials`
- **Loại:** Username with password
- **Giá trị:** Tài khoản kết nối DB production

- **ID:** `db-go-finy-prod-url`
- **Loại:** Secret text
- **Giá trị:** JDBC URL kết nối DB production

### 1.3. Đường dẫn log và tài liệu
- **ID:** `go-finy-log-path-prod`
- **Loại:** Secret text
- **Giá trị:** Đường dẫn thư mục log trên host (ví dụ: `/var/log/go-finy`)

- **ID:** `go-finy-document-path-prod`
- **Loại:** Secret text
- **Giá trị:** Đường dẫn thư mục tài liệu hợp đồng trên host (ví dụ: `/data/hoso`)

## 2. Cách tạo Credential trong Jenkins
1. Vào Jenkins > Manage Jenkins > Manage Credentials
2. Chọn domain phù hợp (hoặc `(global)`)
3. Nhấn **Add Credentials**
4. Điền các trường như hướng dẫn ở trên (ID, loại, giá trị)

## 3. Kiểm tra lại Jenkinsfile
Đảm bảo các ID credential trong Jenkinsfile-go-finy-production trùng khớp với credential bạn đã tạo.

## 4. Tham khảo thêm
- Để biết thêm chi tiết về các biến môi trường, xem file `Jenkinsfile-go-finy-production`.
- Để biết cấu hình Spring Boot, xem file `go-finy/application.properties`.

---
Mọi thắc mắc vui lòng liên hệ DevOps hoặc người quản lý dự án.
