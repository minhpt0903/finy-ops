#!/bin/bash
# Stop Script for Finy-Ops Platform (Linux/Mac)
# Usage: ./stop.sh

set -e

echo "🛑 Stopping Finy-Ops Platform..."
echo ""

# Check for compose command
COMPOSE_CMD=""
if command -v podman-compose &> /dev/null; then
    COMPOSE_CMD="podman-compose"
elif command -v docker-compose &> /dev/null; then
    COMPOSE_CMD="docker-compose"
else
    COMPOSE_CMD="podman compose"
fi

echo "📦 Using: $COMPOSE_CMD"
echo ""

# Stop services
echo "🐳 Stopping services..."
$COMPOSE_CMD down

echo ""
echo "✅ Services stopped successfully!"
echo ""
echo "💡 To start again, run: ./start.sh"
echo ""
