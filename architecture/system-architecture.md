# System Architecture

---

## 1. Overview

```mermaid
flowchart TB
    classDef cluster fill:#1C2833,color:#fff,stroke:#AAB7B8,stroke-width:2px
    classDef gw      fill:#1C2833,color:#fff,stroke:none
    classDef infra   fill:#BA4A00,color:#fff,stroke:none
    classDef ext     fill:#626567,color:#fff,stroke:none

    EXT_USER(["🌐 User / Browser / Mobile"]):::ext
    EXT_VPBANK(["🏦 VPBank"]):::ext

    Kong["🔀 Kong Gateway
    api.finy.vn · app.finy.vn
    api.3gang.vn · app.3gang.vn"]:::gw

    CORE(["⚙️ Core
    Auth · Storage · Notification
    Console Hub"]):::cluster

    GANG(["🏢 3Gang
    3Gang Service · Fmarket · VPBank Service
    Saving Consumer · TSIO Service
    3Gang App · TSIO Dashboard"]):::cluster

    FINY(["💙 Finy
    Finy Service · eContract · FIO Service
    Finy Dashboard · FIO Dashboard"]):::cluster

    KafkaMain[("Kafka\nmain")]:::infra
    KafkaGang[("Kafka\n3gang")]:::infra
    MinIO[("MinIO\noss.finy.vn")]:::infra

    EXT_USER --> Kong
    EXT_VPBANK -->|"callback direct"| GANG

    Kong --> CORE
    Kong --> GANG
    Kong --> FINY

    CORE <-->|"internal"| GANG
    CORE <-->|"internal"| FINY

    FINY -->|publish| KafkaMain
    GANG -->|publish| KafkaMain
    CORE -->|publish / consume| KafkaMain

    GANG -->|publish| KafkaGang
    KafkaGang -->|consume| GANG

    CORE --- MinIO
    FINY -->|"upload file\n(via Kong)"| CORE
    GANG -->|"upload file\n(via Kong)"| CORE
```

> Chi tiết từng nhóm xem các mục bên dưới.

---

## 2. Core

```mermaid
flowchart TB
    classDef fe    fill:#2471A3,color:#fff,stroke:none
    classDef be    fill:#1E8449,color:#fff,stroke:none
    classDef db    fill:#6C3483,color:#fff,stroke:none
    classDef infra fill:#BA4A00,color:#fff,stroke:none
    classDef gw    fill:#1C2833,color:#fff,stroke:none
    classDef ext   fill:#626567,color:#fff,stroke:none

    Kong["🔀 Kong Gateway"]:::gw
    FinyDash_ext(["💙 Finy Dashboard\n(external caller)"]):::ext
    TsioDash_ext(["🏢 TSIO Dashboard\n(external caller)"]):::ext
    FioDash_ext(["💙 FIO Dashboard\n(external caller)"]):::ext

    subgraph CORE["⚙️ Core"]
        Hub["Console Hub FE\n/p/hub · /t/hub"]:::fe

        Auth["Auth Service\n/auth"]:::be
        Storage["Storage Service\n/storage"]:::be
        Notis["Notification Service\n/notis"]:::be

        AuthDB[("auth\nPostgreSQL")]:::db
        StorageDB[("storage\nPostgreSQL")]:::db
        NotisDB[("notification\nPostgreSQL")]:::db
        Redis[("Redis")]:::infra
        MinIO[("MinIO\noss.finy.vn ← direct")]:::infra
    end

    subgraph MQ["📨 Kafka (main)"]
        KafkaMain[("Kafka")]:::infra
    end

    Kong --> Hub & Auth & Storage & Notis
    Hub -->|"account management"| Auth
    Auth --> AuthDB & Redis
    Storage --> StorageDB
    Storage <-->|"S3 API\ndirect domain"| MinIO
    Notis --> NotisDB

    %% File upload từ FE (qua Kong → Storage)
    FinyDash_ext -->|"① upload (via Kong)"| Storage
    TsioDash_ext -->|"① upload (via Kong)"| Storage
    FioDash_ext  -->|"① upload (via Kong)"| Storage

    %% Confirm file từ internal services
    Storage -->|"② confirm event"| KafkaMain

    %% Kafka
    Storage -->|publish| KafkaMain
    Notis   -->|publish| KafkaMain
    KafkaMain -->|consume| Storage & Notis
```

| Service | Port test / prod | DB | Ghi chú |
|---|---|---|---|
| Auth Service | 8000 | PostgreSQL `auth` + Redis | JWT issuer, session validation |
| Storage Service | 8200 | PostgreSQL `storage` + MinIO | Upload từ FE, confirm từ internal |
| Notification Service | 8100 | PostgreSQL `notification` | Firebase push, consume Kafka |
| Console Hub FE | 8800 | — | Login, redirect TSIO/FIO, account mgmt qua Auth |

---

## 3. 3Gang

```mermaid
flowchart TB
    classDef fe    fill:#2471A3,color:#fff,stroke:none
    classDef be    fill:#1E8449,color:#fff,stroke:none
    classDef db    fill:#6C3483,color:#fff,stroke:none
    classDef infra fill:#BA4A00,color:#fff,stroke:none
    classDef gw    fill:#1C2833,color:#fff,stroke:none
    classDef ext   fill:#626567,color:#fff,stroke:none

    Kong["🔀 Kong Gateway"]:::gw
    Storage_ext(["⚙️ Storage Service\n(Core)"]):::ext
    VPBank(["🏦 VPBank"]):::ext

    subgraph GANG["🏢 3Gang"]
        GangApp["📱 3Gang App\n(Mobile)"]:::fe
        TsioDash["TSIO Dashboard FE\n/p/tsio · /t/tsio"]:::fe

        GangSvc["3Gang Service\n(không qua Kong)\n🔐 tự auth"]:::be
        Fmarket["Fmarket Service\n(không qua Kong)"]:::be
        VPBankSvc["VPBank Service\n(không qua Kong)"]:::be
        SavingConsumer["Saving Consumer\n(không qua Kong)"]:::be
        TsioSvc["TSIO Service\n/tsio"]:::be

        OracleGang[("Oracle\n3gang")]:::db
        TsioDB[("tsio\nPostgreSQL")]:::db
        Redis[("Redis")]:::infra
    end

    subgraph MQ["📨 Kafka"]
        KafkaMain[("Kafka\nmain")]:::infra
        KafkaGang[("Kafka\n3gang internal")]:::infra
    end

    Kong --> TsioDash & TsioSvc
    VPBank -->|"HTTPS callback\n(direct, không qua Kong)"| VPBankSvc

    GangApp -->|"3gang domain\n(auth nội bộ)"| GangSvc

    GangSvc & Fmarket & VPBankSvc & SavingConsumer --> OracleGang
    TsioSvc --> TsioDB & Redis

    TsioDash -->|"① upload file (via Kong)"| Storage_ext
    TsioSvc  -->|"② confirm file (internal)"| Storage_ext

    GangSvc -. "🔄 đang tách dần" .-> TsioSvc

    TsioSvc -->|publish| KafkaMain
    GangSvc -->|publish| KafkaGang
    KafkaGang -->|consume| SavingConsumer
```

| Service | Port test / prod | DB | Ghi chú |
|---|---|---|---|
| 3Gang Service | — | Oracle `3gang` | Monolith legacy — **đang tách dần** sang TSIO Service |
| Fmarket Service | — | Oracle `3gang` | Dịch vụ quỹ/fund |
| VPBank Service | — | Oracle `3gang` | Nhận callback từ VPBank (direct) |
| Saving Consumer | — | Oracle `3gang` | Consume Kafka 3gang riêng |
| TSIO Service | 9007 / 8000 | PostgreSQL `tsio` + Redis | Service mới, nhận dần chức năng từ 3Gang Service |
| 3Gang App (Mobile) | — | — | Gọi 3Gang Service qua domain riêng, SSO qua Auth |
| TSIO Dashboard FE | 9008 / 8800 | — | SPA vận hành nội bộ 3Gang |

---

## 4. Finy

```mermaid
flowchart TB
    classDef fe    fill:#2471A3,color:#fff,stroke:none
    classDef be    fill:#1E8449,color:#fff,stroke:none
    classDef db    fill:#6C3483,color:#fff,stroke:none
    classDef infra fill:#BA4A00,color:#fff,stroke:none
    classDef gw    fill:#1C2833,color:#fff,stroke:none
    classDef ext   fill:#626567,color:#fff,stroke:none

    Kong["🔀 Kong Gateway"]:::gw
    Storage_ext(["⚙️ Storage Service\n(Core)"]):::ext

    subgraph FINY["💙 Finy"]
        FinyDash["Finy Dashboard FE\n(không qua Kong)"]:::fe
        FioDash["FIO Dashboard FE\n/p/fio · /t/fio"]:::fe

        FinySvc["Finy Service\n(không qua Kong)"]:::be
        eContract["eContract Service\n(không qua Kong)"]:::be
        FioSvc["FIO Service\n/fio"]:::be

        OracleFiny[("Oracle\nfiny")]:::db
        FioDB[("fio\nPostgreSQL")]:::db
        LocalFS[("Local FS\neContract files")]:::db
    end

    subgraph MQ["📨 Kafka (main)"]
        KafkaMain[("Kafka")]:::infra
    end

    Kong --> FioDash & FioSvc

    FinyDash -->|"finy domain\n(không qua Kong)"| FinySvc

    FinySvc & eContract --> OracleFiny
    eContract --> LocalFS
    FioSvc --> FioDB

    FioDash -->|"① upload file (via Kong)"| Storage_ext
    FioSvc  -->|"② confirm file (internal)"| Storage_ext

    FinySvc -. "🔄 đang tách dần" .-> FioSvc

    FinySvc -->|publish| KafkaMain
    FioSvc  -->|publish| KafkaMain
```

| Service | Port test / prod | DB | Ghi chú |
|---|---|---|---|
| Finy Service | — | Oracle `finy` | Monolith legacy — **đang tách dần** sang FIO Service |
| eContract Service | — | Oracle `finy` + Local FS | File hợp đồng lưu trực tiếp trên server |
| FIO Service | 9101 / 9010 | PostgreSQL `fio` | Service mới, nhận dần chức năng từ Finy Service |
| Finy Dashboard FE | — | — | Kết nối Finy Service qua domain riêng (không qua Kong) |
| FIO Dashboard FE | 9102 / 9011 | — | SPA vận hành nội bộ Finy (qua Kong) |

---

## 5. Key Flows

### File Upload
```
FIO/TSIO Dashboard  ──① upload──▶  Storage Service (qua Kong)
FIO/TSIO Service    ──② confirm──▶  Storage Service (internal)
Storage Service     ──publish──▶   Kafka (main)
```

### Notification
```
Any Service  ──publish──▶  Kafka (main)  ──consume──▶  Notification Service  ──▶  Firebase Push
```

### Saving Consumer (3Gang)
```
3Gang Service  ──publish──▶  Kafka (3gang)  ──consume──▶  Saving Consumer
```

### SSO / Login
```
Console Hub / TSIO Dashboard / FIO Dashboard
    ──▶  Kong  ──▶  Auth Service (/p/auth · /t/auth)

3Gang App (Mobile)
    ──▶  3Gang Service (auth nội bộ, không qua Core Auth)
```

### Migration Direction
```
Finy Service  ──🔄 tách dần──▶  FIO Service     (Oracle → PostgreSQL)
3Gang Service ──🔄 tách dần──▶  TSIO Service    (Oracle → PostgreSQL)
eContract     ──🔄 tách dần──▶  Storage Service (Local FS → MinIO)  [planned]
```

---
_Last updated: 2026-06-10_
