#!/bin/bash
# Stop services (direct podman)

echo "🛑 Stopping Finy-Ops services..."
echo ""

# Stop containers
for container in kafka-ui kafka jenkins; do
    if podman ps -a --format "{{.Names}}" | grep -q "^$container$"; then
        echo "Stopping $container..."
        podman stop $container
    fi
done

echo ""
echo "✅ All services stopped"
echo ""
echo "To remove containers completely:"
echo "  podman rm jenkins kafka kafka-ui"
echo ""
echo "To remove volumes (⚠️ deletes all data):"
echo "  podman volume rm jenkins_home kafka_data kafka_logs"
echo ""
