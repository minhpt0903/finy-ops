# 🎩 Red Hat Enterprise Linux Setup Guide

## Hướng dẫn cài đặt chi tiết cho RHEL 8/9

### 1. Cài đặt Podman trên Red Hat

#### RHEL 8
```bash
# Enable repositories
sudo subscription-manager repos --enable rhel-8-for-x86_64-baseos-rpms
sudo subscription-manager repos --enable rhel-8-for-x86_64-appstream-rpms

# Update system
sudo dnf update -y

# Install Podman
sudo dnf install -y podman podman-compose podman-docker container-tools

# Verify installation
podman --version
podman-compose --version
```

#### RHEL 9
```bash
# Enable repositories
sudo subscription-manager repos --enable codeready-builder-for-rhel-9-$(arch)-rpms

# Update system
sudo dnf update -y

# Install Podman and tools
sudo dnf install -y podman podman-compose podman-docker buildah skopeo

# Verify installation
podman --version
podman-compose --version
```

### 2. Cấu hình Podman Rootless

```bash
# Enable user namespaces (nếu chưa có)
echo "user.max_user_namespaces=28633" | sudo tee -a /etc/sysctl.d/userns.conf
sudo sysctl -p /etc/sysctl.d/userns.conf

# Configure subuid and subgid
sudo usermod --add-subuids 100000-165535 $USER
sudo usermod --add-subgids 100000-165535 $USER

# Enable linger (để container chạy khi user logout)
sudo loginctl enable-linger $USER

# Start Podman socket cho user
systemctl --user enable --now podman.socket

# Verify rootless setup
podman info | grep rootless
# Should show: rootless: true
```

### 3. Cấu hình SELinux cho Container

```bash
# Check SELinux status
getenforce
# Should return: Enforcing

# Install SELinux policy tools
sudo dnf install -y policycoreutils-python-utils

# Set proper context cho container volumes
sudo semanage fcontext -a -t container_file_t "/home/$USER/projects/finy-ops/jenkins-data(/.*)?"
sudo semanage fcontext -a -t container_file_t "/home/$USER/projects/finy-ops/kafka-data(/.*)?"

# Apply SELinux context
sudo restorecon -R ~/projects/finy-ops/

# Verify context
ls -Z ~/projects/finy-ops/
```

### 4. Cấu hình Firewall

```bash
# Allow Jenkins port
sudo firewall-cmd --permanent --add-port=8080/tcp
sudo firewall-cmd --permanent --add-port=50000/tcp

# Allow Kafka ports
sudo firewall-cmd --permanent --add-port=9092/tcp
sudo firewall-cmd --permanent --add-port=9093/tcp

# Allow Kafka UI
sudo firewall-cmd --permanent --add-port=8090/tcp

# Reload firewall
sudo firewall-cmd --reload

# Verify
sudo firewall-cmd --list-ports
```

### 5. Cài đặt Java và Gradle (cho local development)

```bash
# Install Java 17
sudo dnf install -y java-17-openjdk java-17-openjdk-devel

# Set JAVA_HOME
echo 'export JAVA_HOME=/usr/lib/jvm/java-17-openjdk' >> ~/.bashrc
echo 'export PATH=$JAVA_HOME/bin:$PATH' >> ~/.bashrc
source ~/.bashrc

# Verify Java
java -version
javac -version

# Install Gradle
wget https://services.gradle.org/distributions/gradle-8.5-bin.zip
sudo unzip -d /opt/gradle gradle-8.5-bin.zip
sudo ln -s /opt/gradle/gradle-8.5 /opt/gradle/latest

# Add Gradle to PATH
echo 'export GRADLE_HOME=/opt/gradle/latest' >> ~/.bashrc
echo 'export PATH=$GRADLE_HOME/bin:$PATH' >> ~/.bashrc
source ~/.bashrc

# Verify Gradle
gradle --version
```

### 6. Clone và Setup Project

```bash
# Clone repository
cd ~
mkdir -p projects
cd projects
git clone https://github.com/your-org/finy-ops.git
cd finy-ops

# Create necessary directories
mkdir -p jenkins-data kafka-data

# Set proper permissions
chmod 755 jenkins-data kafka-data
chmod +x start.sh stop.sh gradlew

# Verify Podman can run
podman run --rm hello-world
```

### 7. Khởi động Platform

```bash
# Start services
./start.sh

# Check status
podman ps

# View logs
podman logs -f jenkins
podman logs -f kafka

# Get Jenkins initial password
podman exec jenkins cat /var/jenkins_home/secrets/initialAdminPassword
```

### 8. Test Deployment

```bash
# Check services are accessible
curl http://localhost:8080  # Jenkins
curl http://localhost:8090  # Kafka UI

# Test Kafka
podman exec -it kafka kafka-topics.sh --list --bootstrap-server localhost:9092

# Test container build
cd ~/my-spring-boot-app
./gradlew clean build
podman build -t my-app:test .
```

## 🔧 Troubleshooting trên RHEL

### Issue: Permission denied khi chạy Podman

```bash
# Fix user permissions
sudo usermod -aG wheel $USER
newgrp wheel

# Fix subuid/subgid
sudo usermod --add-subuids 100000-165535 $USER
sudo usermod --add-subgids 100000-165535 $USER
podman system migrate
```

### Issue: SELinux chặn container

```bash
# Temporarily set to permissive (for debugging)
sudo setenforce 0

# Check SELinux denials
sudo ausearch -m avc -ts recent

# Create custom policy nếu cần
sudo audit2allow -a -M my_container
sudo semodule -i my_container.pp

# Re-enable enforcing
sudo setenforce 1
```

### Issue: Container không start sau reboot

```bash
# Enable systemd service cho container (rootless)
podman generate systemd --new --name jenkins --files
mkdir -p ~/.config/systemd/user
mv container-jenkins.service ~/.config/systemd/user/
systemctl --user daemon-reload
systemctl --user enable container-jenkins
systemctl --user start container-jenkins

# For non-rootless (system-wide)
sudo podman generate systemd --new --name jenkins --files
sudo mv container-jenkins.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable container-jenkins
sudo systemctl start container-jenkins
```

### Issue: Port already in use

```bash
# Find process using port
sudo ss -tulpn | grep :8080

# Kill process if needed
sudo kill -9 <PID>

# Or change port in podman-compose.yml
sed -i 's/8080:8080/8081:8080/' podman-compose.yml
```

### Issue: Out of disk space

```bash
# Check disk usage
df -h
podman system df

# Clean up unused images
podman image prune -a

# Clean up unused volumes
podman volume prune

# Clean up everything
podman system prune -a --volumes
```

## 📊 Monitoring trên RHEL

### System Resources

```bash
# Monitor container resources
podman stats

# System resource usage
top
htop  # sudo dnf install htop

# Disk I/O
iostat -x 1

# Network
ss -s
netstat -i
```

### Container Logs

```bash
# View logs
podman logs jenkins
podman logs kafka

# Follow logs
podman logs -f --tail 100 jenkins

# Export logs
podman logs jenkins > jenkins.log 2>&1
```

### Health Checks

```bash
# Check container health
podman ps --format "{{.Names}}: {{.Status}}"

# Inspect container
podman inspect jenkins | jq '.[0].State.Health'

# Check service endpoints
curl -I http://localhost:8080
curl http://localhost:8090/api/clusters
```

## 🛡️ Security Best Practices trên RHEL

### 1. Keep SELinux Enforcing
```bash
# Never disable SELinux in production
sudo setenforce 1
sudo sed -i 's/SELINUX=.*/SELINUX=enforcing/' /etc/selinux/config
```

### 2. Use Rootless Containers
```bash
# Always run as non-root user
podman info | grep rootless
# Should be: true
```

### 3. Regular Updates
```bash
# Update system and containers regularly
sudo dnf update -y
podman auto-update
```

### 4. Limit Resources
```bash
# Add to podman-compose.yml
services:
  jenkins:
    deploy:
      resources:
        limits:
          cpus: '2'
          memory: 2G
```

### 5. Network Configuration
```bash
# Kiểm tra network hiện có
podman network ls

# Inspect default podman network
podman network inspect podman

# Các container sẽ tự động dùng network "podman" mặc định
# Không cần tạo network mới
```

## 📝 Production Checklist

- [ ] SELinux is enforcing
- [ ] Firewall rules configured
- [ ] User namespaces enabled
- [ ] Systemd services created for auto-start
- [ ] Backups configured (jenkins-data, kafka-data)
- [ ] Monitoring setup (Prometheus + Grafana)
- [ ] Log rotation configured
- [ ] SSL/TLS certificates installed
- [ ] Jenkins security configured
- [ ] Kafka authentication enabled
- [ ] Resource limits set
- [ ] Regular security updates scheduled

## 🔗 RHEL Resources

- [Red Hat Container Tools Guide](https://access.redhat.com/documentation/en-us/red_hat_enterprise_linux/9/html/building_running_and_managing_containers/)
- [Podman on RHEL](https://access.redhat.com/documentation/en-us/red_hat_enterprise_linux/9/html-single/building_running_and_managing_containers/index#proc_running-containers-as-systemd-services-with-podman_assembly_porting-containers-to-systemd-using-podman)
- [SELinux User Guide](https://access.redhat.com/documentation/en-us/red_hat_enterprise_linux/9/html/using_selinux/)
- [RHEL Security Guide](https://access.redhat.com/documentation/en-us/red_hat_enterprise_linux/9/html/security_hardening/)
