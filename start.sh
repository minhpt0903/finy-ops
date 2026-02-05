#!/bin/bash
# Quick Start Script for Finy-Ops Platform (Linux/Mac)
# Usage: ./start.sh

set -e

echo "🚀 Starting Finy-Ops Platform..."
echo ""

# Check if Podman is installed
echo "📦 Checking Podman installation..."

# Try different ways to detect podman
PODMAN_CMD=""
if command -v podman &> /dev/null; then
    PODMAN_CMD="podman"
elif command -v /usr/bin/podman &> /dev/null; then
    PODMAN_CMD="/usr/bin/podman"
elif [ -f /usr/bin/podman ]; then
    PODMAN_CMD="/usr/bin/podman"
else
    echo "❌ Podman is not installed or not in PATH!"
    echo ""
    echo "Debug info:"
    echo "  PATH: $PATH"
    echo "  which podman: $(which podman 2>&1 || echo 'not found')"
    echo "  /usr/bin/podman exists: $([ -f /usr/bin/podman ] && echo 'yes' || echo 'no')"
    echo ""
    echo "Please install Podman:"
    echo "  Ubuntu/Debian: sudo apt-get install -y podman"
    echo "  Fedora/RHEL:   sudo dnf install -y podman"
    echo "  macOS:         brew install podman"
    echo ""
    echo "After install, try: source ~/.bashrc"
    exit 1
fi

PODMAN_VERSION=$($PODMAN_CMD --version 2>&1 || echo "unknown")
echo "✅ Podman found: $PODMAN_VERSION"
echo "   Location: $PODMAN_CMD"
echo ""

# Check for compose command
echo "📦 Checking Podman Compose..."
COMPOSE_CMD=""
if command -v podman-compose &> /dev/null; then
    COMPOSE_CMD="podman-compose"
    echo "✅ Using podman-compose"
elif $PODMAN_CMD compose version &> /dev/null; then
    COMPOSE_CMD="$PODMAN_CMD compose"
    echo "✅ Using podman compose (built-in)"
elif command -v docker-compose &> /dev/null; then
    COMPOSE_CMD="docker-compose"
    echo "⚠️  Using docker-compose (compatibility mode)"
else
    echo "❌ No compose tool found!"
    echo ""
    echo "Install podman-compose:"
    echo "  pip3 install podman-compose"
    echo "  # Or"
    echo "  sudo apt-get install -y podman-compose"
    exit 1
fi
echo ""

# Create necessary directories
echo "📁 Creating directories..."
mkdir -p jenkins-data kafka-data
echo ""

# Start services
echo "🐳 Starting services..."
echo "  This may take a few minutes on first run..."
echo ""

$COMPOSE_CMD up -d

# Wait for services
echo ""
echo "⏳ Waiting for services to be ready..."
sleep 15

# Show status
echo ""
echo "📊 Services Status:"
$COMPOSE_CMD ps

echo ""
echo "🌐 Access URLs:"
echo "  Jenkins:   http://localhost:8080"
echo "  Kafka UI:  http://localhost:8090"
echo ""

# Get Jenkins password
echo "🔑 Getting Jenkins initial admin password..."
sleep 5
PASSWORD=$(podman exec jenkins cat /var/jenkins_home/secrets/initialAdminPassword 2>/dev/null || echo "")

if [ -n "$PASSWORD" ]; then
    echo "  Initial Admin Password: $PASSWORD"
    echo "  ⚠️  Save this password for first-time setup!"
else
    echo "  ⚠️  Password not ready yet. Run this command in 30 seconds:"
    echo "  podman exec jenkins cat /var/jenkins_home/secrets/initialAdminPassword"
fi

echo ""
echo "📖 Next Steps:"
echo "  1. Open Jenkins: http://localhost:8080"
echo "  2. Use the initial admin password above"
echo "  3. Install suggested plugins"
echo "  4. Create your first admin user"
echo "  5. Check README.md for detailed instructions"
echo ""

echo "💡 Useful Commands:"
echo "  View logs:     $COMPOSE_CMD logs -f jenkins"
echo "  Stop services: $COMPOSE_CMD down"
echo "  Restart:       $COMPOSE_CMD restart"
echo ""

echo "✨ Setup complete! Happy coding! 🚀"
echo ""
