#!/bin/bash
# Script chạy trên HOST để build image và deploy
# Jenkins sẽ gọi script này sau khi build JAR

set -e

# Parse arguments
ENVIRONMENT=$1
BUILD_NUMBER=$2
WORKSPACE=$3

if [ -z "$ENVIRONMENT" ] || [ -z "$BUILD_NUMBER" ] || [ -z "$WORKSPACE" ]; then
    echo "Usage: $0 <test|production> <build_number> <workspace_path>"
    exit 1
fi

# Config
APP_NAME="lendbiz-apigateway"
IMAGE_TAG="${APP_NAME}:${ENVIRONMENT}-${BUILD_NUMBER}"
CONTAINER_NAME="${APP_NAME}-${ENVIRONMENT}"

# Set profile and port based on environment
if [ "$ENVIRONMENT" = "production" ]; then
    SPRING_PROFILE="prod"
    APP_PORT="9200"
else
    SPRING_PROFILE="test"
    APP_PORT="9201"
fi

KAFKA_SERVERS="42.112.38.103:9092"

echo "=========================================="
echo "Building and Deploying Application"
echo "=========================================="
echo "Environment: $ENVIRONMENT"
echo "Spring Profile: $SPRING_PROFILE"
echo "Build Number: $BUILD_NUMBER"
echo "Image: $IMAGE_TAG"
echo "Port: $APP_PORT"
echo "Workspace: $WORKSPACE"
echo "=========================================="
echo ""

# Detect podman command
PODMAN_CMD="podman"
if ! command -v podman &> /dev/null; then
    if [ -x /usr/bin/podman ]; then
        PODMAN_CMD="/usr/bin/podman"
    else
        echo "❌ Podman not found!"
        exit 1
    fi
fi

# Create Dockerfile
echo "📝 Creating Dockerfile..."
cat > $WORKSPACE/Dockerfile.deploy <<'EOF'
FROM docker.io/openjdk:17-jdk-slim
WORKDIR /app
COPY build/libs/*.jar app.jar
EXPOSE 9200
ENTRYPOINT ["java", "-jar", "app.jar"]
EOF

# Build image
echo "🔨 Building container image..."
cd $WORKSPACE
$PODMAN_CMD build -t $IMAGE_TAG -f Dockerfile.deploy .
echo "✅ Image built: $IMAGE_TAG"
echo ""

# Stop old container
echo "🛑 Stopping old container..."
$PODMAN_CMD stop $CONTAINER_NAME 2>/dev/null || true
$PODMAN_CMD rm $CONTAINER_NAME 2>/dev/null || true
echo ""

# Deploy new container
echo "🚀 Deploying new container..."
$PODMAN_CMD run -d --name $CONTAINER_NAME \
    --network podman \
    -e SPRING_PROFILES_ACTIVE=$SPRING_PROFILE \
    -e SPRING_KAFKA_BOOTSTRAP_SERVERS=$KAFKA_SERVERS \
    -p $APP_PORT:9200 \
    --restart unless-stopped \
    $IMAGE_TAG

echo "✅ Container deployed: $CONTAINER_NAME"
echo ""

# Wait and show logs
echo "⏳ Waiting for application to start..."
sleep 10
echo ""
echo "📋 Container logs (last 30 lines):"
$PODMAN_CMD logs --tail 30 $CONTAINER_NAME
echo ""

echo "=========================================="
echo "✅ Deployment completed!"
echo "=========================================="
echo "Application URL: http://localhost:$APP_PORT"
echo "Container: $CONTAINER_NAME"
echo "Image: $IMAGE_TAG"
echo ""
echo "View logs: $PODMAN_CMD logs -f $CONTAINER_NAME"
echo "=========================================="
