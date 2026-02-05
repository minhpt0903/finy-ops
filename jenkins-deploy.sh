#!/bin/bash
# Script deploy ứng dụng với Podman
# Chạy trên HOST sau khi Jenkins build xong JAR

set -e

# Parse arguments
ENVIRONMENT=${1:-test}
JAR_FILE=${2:-build/libs/apigateway-0.1.jar}

# Config
APP_NAME="lendbiz-apigateway"
IMAGE_TAG="${APP_NAME}:${ENVIRONMENT}"
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
echo "Deploying Application with Podman"
echo "=========================================="
echo "Environment: $ENVIRONMENT"
echo "Spring Profile: $SPRING_PROFILE"
echo "JAR file: $JAR_FILE"
echo "Image: $IMAGE_TAG"
echo "Port: $APP_PORT"
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

# Check JAR file exists
if [ ! -f "$JAR_FILE" ]; then
    echo "❌ JAR file not found: $JAR_FILE"
    echo "Please download JAR from Jenkins artifacts first"
    exit 1
fi

# Build image
echo "🔨 Building container image with Podman..."
$PODMAN_CMD build -t $IMAGE_TAG .
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
echo "Commands:"
echo "  View logs: $PODMAN_CMD logs -f $CONTAINER_NAME"
echo "  Stop:      $PODMAN_CMD stop $CONTAINER_NAME"
echo "  Restart:   $PODMAN_CMD restart $CONTAINER_NAME"
echo "  Remove:    $PODMAN_CMD rm -f $CONTAINER_NAME"
echo "=========================================="
