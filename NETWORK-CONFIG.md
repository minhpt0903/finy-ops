# Network Configuration - Podman Default Network

## Thay đổi quan trọng 

Hệ thống đã được cập nhật để sử dụng **default Podman network** (`podman`) thay vì tạo network riêng (`finy-ops-network`).

## Lý do thay đổi

Trên server Red Hat đã có sẵn các container sử dụng network `podman` mặc định:
```bash
podman inspect <container> --format '{{.NetworkSettings.Networks}}'
# Output: map[podman:0xc000766fc0]
```

## Cấu hình hiện tại

### podman-compose.yml
Tất cả services sử dụng `network_mode: "podman"`:
```yaml
services:
  jenkins:
    network_mode: "podman"
  kafka:
    network_mode: "podman"
  kafka-ui:
    network_mode: "podman"
```

### Jenkinsfile
Pipeline deploy sử dụng `--network podman`:
```groovy
podman run -d --name ${APP_NAME}-${ENVIRONMENT} \
    --network podman \
    ...
```

## Communication giữa các containers

Vì tất cả containers đều trong cùng network `podman`, chúng có thể giao tiếp với nhau qua container name:

### Từ Jenkins → Kafka
```bash
KAFKA_BOOTSTRAP_SERVERS=kafka:9092
```

### Từ Spring Boot App → Kafka
```yaml
spring:
  kafka:
    bootstrap-servers: kafka:9092
```

### Từ Kafka UI → Kafka
```yaml
KAFKA_CLUSTERS_0_BOOTSTRAPSERVERS: kafka:9092
```

## Kiểm tra network

### List networks
```bash
podman network ls
```

Output:
```
NETWORK ID    NAME        DRIVER
2f259bab93aa  podman      bridge
```

### Inspect podman network
```bash
podman network inspect podman
```

### Kiểm tra container đang dùng network nào
```bash
podman inspect jenkins --format '{{.NetworkSettings.Networks}}'
podman inspect kafka --format '{{.NetworkSettings.Networks}}'
```

### List containers trong network
```bash
podman network inspect podman --format '{{range .Containers}}{{.Name}} {{end}}'
```

## DNS Resolution

Podman tự động cấu hình DNS cho các containers trong cùng network:
- Container name = hostname
- `jenkins` → IP của Jenkins container
- `kafka` → IP của Kafka container
- `kafka-ui` → IP của Kafka UI container

### Test DNS từ bên trong container
```bash
# Vào container Jenkins
podman exec -it jenkins bash

# Ping Kafka
ping -c 3 kafka

# Check DNS
nslookup kafka

# Test connection
curl -v kafka:9092
```

## Tương thích với containers khác

Vì sử dụng network `podman` mặc định, các services mới có thể giao tiếp với:
- ✅ Containers hiện có trên server
- ✅ Các container được tạo bởi `podman run` (không có flag `--network`)
- ✅ Các container trong podman-compose khác (dùng default network)

## Lưu ý quan trọng

### 1. Port conflicts
Kiểm tra ports không bị trùng với containers khác:
```bash
# List tất cả containers và ports
podman ps --format "{{.Names}}: {{.Ports}}"

# Kiểm tra port cụ thể
sudo ss -tulpn | grep :8080
```

### 2. Container name uniqueness
Container names phải unique trong cùng network:
```bash
# Nếu đã có container tên "jenkins"
podman rm -f jenkins  # Xóa trước khi start mới

# Hoặc đổi tên trong podman-compose.yml
container_name: jenkins-finy-ops
```

### 3. Host connectivity
Từ host machine, truy cập containers qua:
- `localhost:8080` → Jenkins
- `localhost:9092` → Kafka
- `localhost:8090` → Kafka UI

### 4. Security considerations
Tất cả containers trong `podman` network có thể giao tiếp với nhau:
- ✅ Tiện lợi cho development
- ⚠️ Cần cẩn thận với production
- 🔒 Cân nhắc tạo isolated network cho sensitive services

## Migration từ custom network

Nếu trước đó đã chạy với `finy-ops-network`:

### 1. Stop services
```bash
podman-compose down
```

### 2. Remove old network (nếu có)
```bash
podman network rm finy-ops-network
```

### 3. Update configs
File `podman-compose.yml` đã được cập nhật để dùng `network_mode: "podman"`

### 4. Start services
```bash
podman-compose up -d
```

### 5. Verify
```bash
podman inspect jenkins kafka kafka-ui --format '{{.Name}}: {{.NetworkSettings.Networks}}'
```

## Troubleshooting

### Container không kết nối được với nhau

```bash
# 1. Kiểm tra tất cả containers trong cùng network
podman network inspect podman | grep -A 3 '"Containers"'

# 2. Test DNS resolution
podman exec jenkins ping -c 1 kafka

# 3. Check firewall
sudo firewall-cmd --list-all

# 4. Kiểm tra SELinux
getenforce
sudo ausearch -m avc -ts recent | grep podman
```

### Network bị lỗi

```bash
# Recreate podman network
podman network rm podman
podman network create podman

# Hoặc reset Podman
podman system reset --force
```

## Best Practices

### Development Environment
✅ Dùng `podman` default network - đơn giản và đủ dùng

### Production Environment
Cân nhắc:
- 🔒 Tạo isolated networks cho từng service group
- 🛡️ Enable network policies
- 📊 Monitor network traffic
- 🔐 Implement mTLS between services

### Example: Production network setup
```yaml
networks:
  frontend:
    driver: bridge
  backend:
    driver: bridge
    internal: true

services:
  jenkins:
    networks:
      - frontend
      - backend
  kafka:
    networks:
      - backend  # Only internal access
```

## References

- [Podman Network Documentation](https://docs.podman.io/en/latest/markdown/podman-network.1.html)
- [Podman Compose Networking](https://github.com/containers/podman-compose#networking)
- [Container Network Best Practices](https://access.redhat.com/documentation/en-us/red_hat_enterprise_linux/9/html/building_running_and_managing_containers/assembly_working-with-container-networks_building-running-and-managing-containers)
