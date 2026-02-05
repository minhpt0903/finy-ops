#!/usr/bin/env pwsh
# Quick Start Script for Finy-Ops Platform
# Usage: .\start.ps1

Write-Host "🚀 Starting Finy-Ops Platform..." -ForegroundColor Green
Write-Host ""

# Check if Podman is installed
Write-Host "📦 Checking Podman installation..." -ForegroundColor Cyan
$podman = Get-Command podman -ErrorAction SilentlyContinue
if (-not $podman) {
    Write-Host "❌ Podman is not installed!" -ForegroundColor Red
    Write-Host "Please install Podman from: https://podman-desktop.io/" -ForegroundColor Yellow
    exit 1
}
Write-Host "✅ Podman found: $($podman.Version)" -ForegroundColor Green
Write-Host ""

# Check if podman-compose is available
Write-Host "📦 Checking Podman Compose..." -ForegroundColor Cyan
$composeCmd = $null
if (Get-Command podman-compose -ErrorAction SilentlyContinue) {
    $composeCmd = "podman-compose"
    Write-Host "✅ Using podman-compose" -ForegroundColor Green
} elseif (Get-Command docker-compose -ErrorAction SilentlyContinue) {
    $composeCmd = "docker-compose"
    Write-Host "✅ Using docker-compose (Podman compatible)" -ForegroundColor Green
} else {
    Write-Host "⚠️  No compose tool found, trying 'podman compose' (built-in)" -ForegroundColor Yellow
    $composeCmd = "podman compose"
}
Write-Host ""

# Create necessary directories
Write-Host "📁 Creating directories..." -ForegroundColor Cyan
$dirs = @("jenkins-data", "kafka-data")
foreach ($dir in $dirs) {
    if (-not (Test-Path $dir)) {
        New-Item -ItemType Directory -Path $dir | Out-Null
        Write-Host "  Created: $dir" -ForegroundColor Gray
    }
}
Write-Host ""

# Start services
Write-Host "🐳 Starting services..." -ForegroundColor Cyan
Write-Host "  This may take a few minutes on first run..." -ForegroundColor Gray
Write-Host ""

try {
    if ($composeCmd -eq "podman compose") {
        podman compose up -d
    } else {
        & $composeCmd up -d
    }
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host ""
        Write-Host "✅ Services started successfully!" -ForegroundColor Green
        Write-Host ""
        
        # Wait for services to be ready
        Write-Host "⏳ Waiting for services to be ready..." -ForegroundColor Cyan
        Start-Sleep -Seconds 10
        
        # Show status
        Write-Host ""
        Write-Host "📊 Services Status:" -ForegroundColor Cyan
        if ($composeCmd -eq "podman compose") {
            podman compose ps
        } else {
            & $composeCmd ps
        }
        
        Write-Host ""
        Write-Host "🌐 Access URLs:" -ForegroundColor Cyan
        Write-Host "  Jenkins:   http://localhost:8080" -ForegroundColor White
        Write-Host "  Kafka UI:  http://localhost:8090" -ForegroundColor White
        Write-Host ""
        
        # Get Jenkins initial password
        Write-Host "🔑 Getting Jenkins initial admin password..." -ForegroundColor Cyan
        Start-Sleep -Seconds 5  # Wait a bit more for Jenkins to create the file
        
        try {
            $password = podman exec jenkins cat /var/jenkins_home/secrets/initialAdminPassword 2>$null
            if ($password) {
                Write-Host "  Initial Admin Password: $password" -ForegroundColor Yellow
                Write-Host "  Save this password for first-time setup!" -ForegroundColor Red
            } else {
                Write-Host "  ⚠️  Password file not ready yet. Run this command manually:" -ForegroundColor Yellow
                Write-Host "  podman exec jenkins cat /var/jenkins_home/secrets/initialAdminPassword" -ForegroundColor Gray
            }
        } catch {
            Write-Host "  ⚠️  Could not retrieve password yet. Wait 30 seconds and try:" -ForegroundColor Yellow
            Write-Host "  podman exec jenkins cat /var/jenkins_home/secrets/initialAdminPassword" -ForegroundColor Gray
        }
        
        Write-Host ""
        Write-Host "📖 Next Steps:" -ForegroundColor Cyan
        Write-Host "  1. Open Jenkins: http://localhost:8080" -ForegroundColor White
        Write-Host "  2. Use the initial admin password above" -ForegroundColor White
        Write-Host "  3. Install suggested plugins" -ForegroundColor White
        Write-Host "  4. Create your first admin user" -ForegroundColor White
        Write-Host "  5. Check README.md for detailed instructions" -ForegroundColor White
        Write-Host ""
        
        Write-Host "💡 Useful Commands:" -ForegroundColor Cyan
        Write-Host "  View logs:     $composeCmd logs -f jenkins" -ForegroundColor Gray
        Write-Host "  Stop services: $composeCmd down" -ForegroundColor Gray
        Write-Host "  Restart:       $composeCmd restart" -ForegroundColor Gray
        Write-Host ""
        
    } else {
        Write-Host ""
        Write-Host "❌ Failed to start services!" -ForegroundColor Red
        Write-Host "Check the logs for more details." -ForegroundColor Yellow
        exit 1
    }
} catch {
    Write-Host ""
    Write-Host "❌ Error: $_" -ForegroundColor Red
    exit 1
}

Write-Host "✨ Setup complete! Happy coding! 🚀" -ForegroundColor Green
Write-Host ""
