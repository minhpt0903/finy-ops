# Jenkins Credentials — finy-econtract Production

Các credentials cần cấu hình tại:
**Jenkins → Manage Jenkins → Credentials → System → Global credentials → Add Credentials**

---

## 1. Credentials mới (cần tạo)

### `finy-econtract-log-path-prod`
| Field | Value |
|---|---|
| Kind | Secret text |
| ID | `finy-econtract-log-path-prod` |
| Secret | Đường dẫn thư mục log trên host, vd: `/home/finy-service/logs/econtract` |
| Description | Finy eContract production log path |

> Thư mục này sẽ được mount vào container tại `/logs` và truyền vào app qua biến `LOG_PATH`.

---

### `finy-econtract-finy-url-prod`
| Field | Value |
|---|---|
| Kind | Secret text |
| ID | `finy-econtract-finy-url-prod` |
| Secret | `https://apigateway.lendbiz.vn` |
| Description | Finy API gateway URL (production) |

---

### `finy-econtract-client-domain-prod`
| Field | Value |
|---|---|
| Kind | Secret text |
| ID | `finy-econtract-client-domain-prod` |
| Secret | `https://econtract.finy.vn` |
| Description | Finy eContract client domain (production) |

---

### `finy-econtract-vnpt-domain-prod`
| Field | Value |
|---|---|
| Kind | Secret text |
| ID | `finy-econtract-vnpt-domain-prod` |
| Secret | `https://gateway-bus-econtract.vnpt.vn` |
| Description | VNPT eContract gateway domain (production) |

---

### `finy-econtract-vnpt-username-prod`
| Field | Value |
|---|---|
| Kind | Secret text |
| ID | `finy-econtract-vnpt-username-prod` |
| Secret | `0110351508` |
| Description | VNPT eContract username (production) |

---

### `finy-econtract-vnpt-password-prod`
| Field | Value |
|---|---|
| Kind | Secret text |
| ID | `finy-econtract-vnpt-password-prod` |
| Secret | `SmCaFn@1508` |
| Description | VNPT eContract password (production) |

---

### `finy-econtract-vnpt-clientid-prod`
| Field | Value |
|---|---|
| Kind | Secret text |
| ID | `finy-econtract-vnpt-clientid-prod` |
| Secret | `4C2FF62C5EF27434E0636B20A50AE22A` |
| Description | VNPT eContract client ID (production) |

---

### `finy-econtract-vnpt-clientsecret-prod`
| Field | Value |
|---|---|
| Kind | Secret text |
| ID | `finy-econtract-vnpt-clientsecret-prod` |
| Secret | `39aa295093f7e5dc22ddccf1cb8b57c9cca3485194c68c48e3d4cfbc2bad21eb` |
| Description | VNPT eContract client secret (production) |

---

## 2. Credentials dùng chung với finy-service (đã có, không cần tạo lại)

| Credential ID | Kind | Dùng cho |
|---|---|---|
| `db-finy-service-prod-credentials` | Username/Password | DB username & password |
| `db-finy-service-prod-url` | Secret text | JDBC URL của database |
| `git-credentials` | Username/Password | Git authentication khi checkout |

---

## 3. Kiểm tra sau khi tạo

Chạy lệnh sau trên Jenkins agent để đảm bảo thư mục log tồn tại và có quyền ghi:

```bash
# Tạo thư mục log nếu chưa có
mkdir -p /home/finy-service/logs/econtract
```

---

## 4. Tóm tắt mapping biến

| Credential ID | Variable trong pipeline | Env var trong container |
|---|---|---|
| `git-finy-api-prod-url` | `GIT_URL` | Git checkout |
| `db-finy-service-prod-url` | `DB_URL` | `SPRING_DATASOURCE_URL` |
| `db-finy-service-prod-credentials` | `DB_USER` / `DB_PASS` | `SPRING_DATASOURCE_USERNAME` / `SPRING_DATASOURCE_PASSWORD` |
| `finy-econtract-log-path-prod` | `ECONTRACT_LOG_PATH` | `LOG_PATH`, `-v .../logs:Z` |
| `finy-econtract-finy-url-prod` | `FINY_URL` | `FINY_URL` |
| `finy-econtract-client-domain-prod` | `FINY_CLIENT_DOMAIN` | `FINY_CLIENT_DOMAIN` |
| `finy-econtract-vnpt-domain-prod` | `VNPT_DOMAIN` | `VNPT_DOMAIN` |
| `finy-econtract-vnpt-username-prod` | `VNPT_USERNAME` | `VNPT_USERNAME` |
| `finy-econtract-vnpt-password-prod` | `VNPT_PASSWORD` | `VNPT_PASSWORD` |
| `finy-econtract-vnpt-clientid-prod` | `VNPT_CLIENTID` | `VNPT_CLIENTID` |
| `finy-econtract-vnpt-clientsecret-prod` | `VNPT_CLIENTSECRET` | `VNPT_CLIENTSECRET` |
