#!/bin/bash
# Script kiểm tra deployment status trên cả 2 servers

TEST_SERVER="192.168.20.82"
PROD_SERVER="42.112.38.103"
DEPLOY_USER="deploy"
SSH_KEY="$HOME/.ssh/jenkins_deploy_key"

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_header() {
    echo ""
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}  $1${NC}"
    echo -e "${BLUE}========================================${NC}"
}

check_server() {
    local server=$1
    local env=$2
    local port=$3
    
    print_header "$env Server ($server)"
    
    # Check SSH connectivity
    echo -n "SSH Connection: "
    if ssh -i $SSH_KEY -o BatchMode=yes -o ConnectTimeout=5 ${DEPLOY_USER}@${server} 'exit' &> /dev/null; then
        echo -e "${GREEN}OK${NC}"
    else
        echo -e "${RED}FAILED${NC}"
        return 1
    fi
    
    # Get container status
    echo ""
    echo "Container Status:"
    ssh -i $SSH_KEY ${DEPLOY_USER}@${server} bash << ENDSSH
        CONTAINER_NAME="lendbiz-apigateway-${env}"
        
        if podman ps --format "{{.Names}}" | grep -q \$CONTAINER_NAME; then
            echo -e "  Status: ${GREEN}Running${NC}"
            echo "  Details:"
            podman ps --filter "name=\$CONTAINER_NAME" --format "    • ID: {{.ID}}\n    • Image: {{.Image}}\n    • Ports: {{.Ports}}\n    • Status: {{.Status}}"
        else
            echo -e "  Status: ${RED}Not Running${NC}"
            
            # Check if container exists but stopped
            if podman ps -a --format "{{.Names}}" | grep -q \$CONTAINER_NAME; then
                echo "  Container exists but stopped"
                echo "  Last logs:"
                podman logs --tail 20 \$CONTAINER_NAME 2>&1 | sed 's/^/    /'
            else
                echo "  Container does not exist"
            fi
            return 1
        fi
ENDSSH
    
    # Check health endpoint
    echo ""
    echo -n "Health Check (http://${server}:${port}/actuator/health): "
    HEALTH_RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" http://${server}:${port}/actuator/health 2>/dev/null)
    
    if [ "$HEALTH_RESPONSE" = "200" ]; then
        echo -e "${GREEN}OK (200)${NC}"
        
        # Get detailed health
        HEALTH_JSON=$(curl -s http://${server}:${port}/actuator/health 2>/dev/null)
        echo "  Response: $HEALTH_JSON"
    elif [ "$HEALTH_RESPONSE" = "000" ]; then
        echo -e "${RED}FAILED (Connection refused)${NC}"
    else
        echo -e "${YELLOW}WARNING (HTTP $HEALTH_RESPONSE)${NC}"
    fi
    
    # Check recent logs
    echo ""
    echo "Recent Logs (last 10 lines):"
    ssh -i $SSH_KEY ${DEPLOY_USER}@${server} bash << ENDSSH
        CONTAINER_NAME="lendbiz-apigateway-${env}"
        if podman ps --format "{{.Names}}" | grep -q \$CONTAINER_NAME; then
            podman logs --tail 10 \$CONTAINER_NAME 2>&1 | sed 's/^/  /'
        fi
ENDSSH
    
    # Check resource usage
    echo ""
    echo "Resource Usage:"
    ssh -i $SSH_KEY ${DEPLOY_USER}@${server} bash << ENDSSH
        CONTAINER_NAME="lendbiz-apigateway-${env}"
        if podman ps --format "{{.Names}}" | grep -q \$CONTAINER_NAME; then
            podman stats --no-stream --format "  • CPU: {{.CPUPerc}}\n  • Memory: {{.MemUsage}}\n  • Net I/O: {{.NetIO}}\n  • Block I/O: {{.BlockIO}}" \$CONTAINER_NAME
        fi
ENDSSH
    
    echo ""
}

# Main
main() {
    echo ""
    echo -e "${BLUE}╔════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║  Multi-Server Deployment Verification ║${NC}"
    echo -e "${BLUE}╚════════════════════════════════════════╝${NC}"
    
    # Check Test Server
    check_server $TEST_SERVER "test" "9201"
    
    # Check Production Server
    check_server $PROD_SERVER "production" "9200"
    
    # Summary
    print_header "Summary"
    
    echo "Health URLs:"
    echo "  • Test:       http://${TEST_SERVER}:9201/actuator/health"
    echo "  • Production: http://${PROD_SERVER}:9200/actuator/health"
    echo ""
    
    echo "Application URLs:"
    echo "  • Test:       http://econtracttest.finy.vn"
    echo "  • Production: http://econtract.finy.vn"
    echo ""
    
    echo "SSH Access:"
    echo "  • Test:       ssh -i $SSH_KEY ${DEPLOY_USER}@${TEST_SERVER}"
    echo "  • Production: ssh -i $SSH_KEY ${DEPLOY_USER}@${PROD_SERVER}"
    echo ""
}

# Check if SSH key exists
if [ ! -f "$SSH_KEY" ]; then
    echo -e "${RED}ERROR:${NC} SSH key not found: $SSH_KEY"
    echo "Run setup-servers.sh first"
    exit 1
fi

# Run main
main
