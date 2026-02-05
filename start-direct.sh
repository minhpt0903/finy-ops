#!/bin/bash
# Alternative start script using podman directly (no compose)
# Use this if podman-compose has issues

set -e

echo "🚀 Starting Finy-Ops Platform (Direct Podman)"
echo ""

# Check Podman
if ! command -v podman &> /dev/null; then
    echo "❌ Podman not found!"
    exit 1
fi
echo "✅ Podman: $(podman --version)"
echo ""

# Create network
echo "📡 Creating network..."
podman network exists podman 2>/dev/null || podman network create podman
echo ""

# Create volumes
echo "💾 Creating volumes..."
podman volume exists jenkins_home 2>/dev/null || podman volume create jenkins_home
podman volume exists kafka_data 2>/dev/null || podman volume create kafka_data
podman volume exists kafka_logs 2>/dev/null || podman volume create kafka_logs
echo ""

# Start Jenkins
echo "🔧 Starting Jenkins..."
if podman ps -a --format "{{.Names}}" | grep -q "^jenkins$"; then
    echo "  Container exists, starting..."
    podman start jenkins
else
    echo "  Creating new container..."
    podman run -d \
        --name jenkins \
        --network podman \
        -p 8080:8080 \
        -p 50000:50000 \
        -v jenkins_home:/var/jenkins_home:Z \
        --restart unless-stopped \
        jenkins/jenkins:lts-jdk17
fi
echo "  ✅ Jenkins started"
echo ""

# Start Kafka
echo "📨 Starting Kafka..."
if podman ps -a --format "{{.Names}}" | grep -q "^kafka$"; then
    echo "  Container exists, starting..."
    podman start kafka
else
    echo "  Creating new container..."
    podman run -d \
        --name kafka \
        --network podman \
        -p 9092:9092 \
        -p 9093:9093 \
        -v kafka_data:/var/lib/kafka/data:Z \
        -v kafka_logs:/opt/kafka/logs:Z \
        -e KAFKA_NODE_ID=1 \
        -e KAFKA_PROCESS_ROLES=broker,controller \
        -e KAFKA_LISTENERS=PLAINTEXT://0.0.0.0:9092,CONTROLLER://0.0.0.0:9093 \
        -e KAFKA_ADVERTISED_LISTENERS=PLAINTEXT://kafka:9092 \
        -e KAFKA_CONTROLLER_LISTENER_NAMES=CONTROLLER \
        -e KAFKA_LISTENER_SECURITY_PROTOCOL_MAP=CONTROLLER:PLAINTEXT,PLAINTEXT:PLAINTEXT \
        -e KAFKA_CONTROLLER_QUORUM_VOTERS=1@kafka:9093 \
        -e KAFKA_OFFSETS_TOPIC_REPLICATION_FACTOR=1 \
        -e KAFKA_TRANSACTION_STATE_LOG_REPLICATION_FACTOR=1 \
        -e KAFKA_TRANSACTION_STATE_LOG_MIN_ISR=1 \
        -e KAFKA_GROUP_INITIAL_REBALANCE_DELAY_MS=0 \
        -e KAFKA_LOG_DIRS=/var/lib/kafka/data \
        -e CLUSTER_ID=MkU3OEVBNTcwNTJENDM2Qk \
        --restart unless-stopped \
        apache/kafka:3.8.1
fi
echo "  ✅ Kafka started"
echo ""

# Start Kafka UI
echo "🖥️  Starting Kafka UI..."
if podman ps -a --format "{{.Names}}" | grep -q "^kafka-ui$"; then
    echo "  Container exists, starting..."
    podman start kafka-ui
else
    echo "  Creating new container..."
    podman run -d \
        --name kafka-ui \
        --network podman \
        -p 8090:8080 \
        -e KAFKA_CLUSTERS_0_NAME=local \
        -e KAFKA_CLUSTERS_0_BOOTSTRAPSERVERS=kafka:9092 \
        -e DYNAMIC_CONFIG_ENABLED=true \
        --restart unless-stopped \
        provectuslabs/kafka-ui:latest
fi
echo "  ✅ Kafka UI started"
echo ""

# Wait for services
echo "⏳ Waiting for services to be ready..."
sleep 10
echo ""

# Check status
echo "📊 Service Status:"
podman ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" | grep -E "jenkins|kafka"
echo ""

# Get Jenkins password
echo "🔐 Jenkins Initial Admin Password:"
sleep 5
if podman exec jenkins test -f /var/jenkins_home/secrets/initialAdminPassword 2>/dev/null; then
    JENKINS_PASSWORD=$(podman exec jenkins cat /var/jenkins_home/secrets/initialAdminPassword 2>/dev/null)
    echo "  $JENKINS_PASSWORD"
else
    echo "  (Not ready yet, check in a moment)"
fi
echo ""

echo "✅ All services started!"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📍 Access URLs:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  🔧 Jenkins:    http://localhost:8080"
echo "  📊 Kafka UI:   http://localhost:8090"
echo "  📨 Kafka:      localhost:9092"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "📝 Next Steps:"
echo "  1. Open Jenkins: http://localhost:8080"
echo "  2. Use password above to unlock"
echo "  3. Install suggested plugins"
echo "  4. Create admin user"
echo ""
echo "🔍 Check logs:"
echo "  podman logs -f jenkins"
echo "  podman logs -f kafka"
echo ""
echo "🛑 Stop services:"
echo "  ./stop.sh"
echo ""
