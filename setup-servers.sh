#!/bin/bash
# Setup script cho Test Server và Production Server
# Chạy từ Jenkins server

set -e

echo "=================================================="
echo "  Multi-Server Deployment Setup"
echo "=================================================="

# Configuration
DEPLOY_USER="deploy"
TEST_SERVER="192.168.20.82"
PROD_SERVER="42.112.38.103"
SSH_KEY="$HOME/.ssh/jenkins_deploy_key"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Functions
print_step() {
    echo -e "${GREEN}==>${NC} $1"
}

print_error() {
    echo -e "${RED}ERROR:${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}WARNING:${NC} $1"
}

check_command() {
    if ! command -v $1 &> /dev/null; then
        print_error "$1 is not installed"
        exit 1
    fi
}

# Step 1: Generate SSH key if not exists
generate_ssh_key() {
    print_step "Kiểm tra SSH key..."
    
    if [ -f "$SSH_KEY" ]; then
        print_warning "SSH key đã tồn tại: $SSH_KEY"
    else
        print_step "Tạo SSH key mới..."
        ssh-keygen -t rsa -b 4096 -C "jenkins@deploy" -f $SSH_KEY -N ""
        chmod 600 $SSH_KEY
        chmod 644 ${SSH_KEY}.pub
        echo -e "${GREEN}✓${NC} SSH key đã được tạo"
    fi
}

# Step 2: Copy SSH key to servers
copy_ssh_keys() {
    print_step "Copy SSH key đến servers..."
    
    echo "Nhập password cho user $DEPLOY_USER trên Test Server ($TEST_SERVER):"
    ssh-copy-id -i ${SSH_KEY}.pub ${DEPLOY_USER}@${TEST_SERVER}
    
    echo "Nhập password cho user $DEPLOY_USER trên Production Server ($PROD_SERVER):"
    ssh-copy-id -i ${SSH_KEY}.pub ${DEPLOY_USER}@${PROD_SERVER}
    
    echo -e "${GREEN}✓${NC} SSH keys đã được copy"
}

# Step 3: Test SSH connection
test_ssh_connection() {
    print_step "Test SSH connection..."
    
    if ssh -i $SSH_KEY -o BatchMode=yes -o ConnectTimeout=5 ${DEPLOY_USER}@${TEST_SERVER} 'echo "Test Server OK"' > /dev/null 2>&1; then
        echo -e "${GREEN}✓${NC} Test Server ($TEST_SERVER) - SSH OK"
    else
        print_error "Không thể SSH đến Test Server ($TEST_SERVER)"
        exit 1
    fi
    
    if ssh -i $SSH_KEY -o BatchMode=yes -o ConnectTimeout=5 ${DEPLOY_USER}@${PROD_SERVER} 'echo "Prod Server OK"' > /dev/null 2>&1; then
        echo -e "${GREEN}✓${NC} Production Server ($PROD_SERVER) - SSH OK"
    else
        print_error "Không thể SSH đến Production Server ($PROD_SERVER)"
        exit 1
    fi
}

# Step 4: Setup Test Server
setup_test_server() {
    print_step "Setup Test Server ($TEST_SERVER)..."
    
    ssh -i $SSH_KEY ${DEPLOY_USER}@${TEST_SERVER} bash -s << 'ENDSSH'
        set -e
        
        echo "→ Kiểm tra Podman..."
        if ! command -v podman &> /dev/null; then
            echo "ERROR: Podman chưa được cài đặt. Vui lòng cài đặt trước."
            exit 1
        fi
        
        echo "→ Enable Podman socket..."
        systemctl --user enable --now podman.socket
        
        echo "→ Enable linger..."
        loginctl enable-linger $USER
        
        echo "→ Tạo config directory..."
        sudo mkdir -p /opt/configs/test
        sudo chown $USER:$USER /opt/configs/test
        
        echo "→ Test Podman..."
        podman run --rm hello-world > /dev/null 2>&1
        
        echo "→ Cleanup..."
        podman system prune -f > /dev/null 2>&1
        
        echo "✓ Test Server setup completed!"
ENDSSH
    
    echo -e "${GREEN}✓${NC} Test Server đã được setup"
}

# Step 5: Setup Production Server
setup_prod_server() {
    print_step "Setup Production Server ($PROD_SERVER)..."
    
    ssh -i $SSH_KEY ${DEPLOY_USER}@${PROD_SERVER} bash -s << 'ENDSSH'
        set -e
        
        echo "→ Kiểm tra Podman..."
        if ! command -v podman &> /dev/null; then
            echo "ERROR: Podman chưa được cài đặt. Vui lòng cài đặt trước."
            exit 1
        fi
        
        echo "→ Enable Podman socket..."
        systemctl --user enable --now podman.socket
        
        echo "→ Enable linger..."
        loginctl enable-linger $USER
        
        echo "→ Tạo config directory..."
        sudo mkdir -p /opt/configs/production
        sudo chown $USER:$USER /opt/configs/production
        
        echo "→ Test Podman..."
        podman run --rm hello-world > /dev/null 2>&1
        
        echo "→ Cleanup..."
        podman system prune -f > /dev/null 2>&1
        
        echo "✓ Production Server setup completed!"
ENDSSH
    
    echo -e "${GREEN}✓${NC} Production Server đã được setup"
}

# Step 6: Copy configs to servers
copy_configs() {
    print_step "Copy application configs đến servers..."
    
    if [ ! -f "spring-envs/test/application.properties" ]; then
        print_error "File spring-envs/test/application.properties không tồn tại"
        exit 1
    fi
    
    if [ ! -f "spring-envs/production/application.properties" ]; then
        print_error "File spring-envs/production/application.properties không tồn tại"
        exit 1
    fi
    
    # Copy test config
    scp -i $SSH_KEY spring-envs/test/application.properties \
        ${DEPLOY_USER}@${TEST_SERVER}:/opt/configs/test/application.properties
    echo -e "${GREEN}✓${NC} Test config copied"
    
    # Copy production config
    scp -i $SSH_KEY spring-envs/production/application.properties \
        ${DEPLOY_USER}@${PROD_SERVER}:/opt/configs/production/application.properties
    echo -e "${GREEN}✓${NC} Production config copied"
}

# Step 7: Verify setup
verify_setup() {
    print_step "Xác minh setup..."
    
    echo "Test Server:"
    ssh -i $SSH_KEY ${DEPLOY_USER}@${TEST_SERVER} bash << 'ENDSSH'
        echo "  • Podman version: $(podman --version)"
        echo "  • Config exists: $([ -f /opt/configs/test/application.properties ] && echo 'Yes' || echo 'No')"
        echo "  • Podman socket: $(systemctl --user is-active podman.socket)"
        echo "  • User linger: $(loginctl show-user $USER -p Linger --value)"
ENDSSH
    
    echo ""
    echo "Production Server:"
    ssh -i $SSH_KEY ${DEPLOY_USER}@${PROD_SERVER} bash << 'ENDSSH'
        echo "  • Podman version: $(podman --version)"
        echo "  • Config exists: $([ -f /opt/configs/production/application.properties ] && echo 'Yes' || echo 'No')"
        echo "  • Podman socket: $(systemctl --user is-active podman.socket)"
        echo "  • User linger: $(loginctl show-user $USER -p Linger --value)"
ENDSSH
}

# Main execution
main() {
    echo ""
    print_step "Bắt đầu setup..."
    echo ""
    
    # Check prerequisites
    check_command ssh
    check_command ssh-keygen
    check_command scp
    
    # Execute steps
    generate_ssh_key
    echo ""
    
    copy_ssh_keys
    echo ""
    
    test_ssh_connection
    echo ""
    
    setup_test_server
    echo ""
    
    setup_prod_server
    echo ""
    
    copy_configs
    echo ""
    
    verify_setup
    echo ""
    
    echo "=================================================="
    echo -e "${GREEN}✓ Setup hoàn tất!${NC}"
    echo "=================================================="
    echo ""
    echo "Next steps:"
    echo "  1. Add SSH credential vào Jenkins:"
    echo "     Jenkins → Credentials → Add → SSH Username with private key"
    echo "     ID: ssh-deploy-key"
    echo "     Username: $DEPLOY_USER"
    echo "     Private Key: $SSH_KEY"
    echo ""
    echo "  2. Tạo Multibranch Pipeline job trong Jenkins"
    echo ""
    echo "  3. Test deployment:"
    echo "     git push origin test   # Deploy to Test Server"
    echo "     git push origin main   # Deploy to Production Server"
    echo ""
}

# Run
main
