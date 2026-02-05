#!/usr/bin/env pwsh
# Stop Script for Finy-Ops Platform
# Usage: .\stop.ps1

Write-Host "🛑 Stopping Finy-Ops Platform..." -ForegroundColor Red
Write-Host ""

# Check compose command
$composeCmd = $null
if (Get-Command podman-compose -ErrorAction SilentlyContinue) {
    $composeCmd = "podman-compose"
} elseif (Get-Command docker-compose -ErrorAction SilentlyContinue) {
    $composeCmd = "docker-compose"
} else {
    $composeCmd = "podman compose"
}

Write-Host "📦 Using: $composeCmd" -ForegroundColor Cyan
Write-Host ""

# Stop services
Write-Host "🐳 Stopping services..." -ForegroundColor Cyan

try {
    if ($composeCmd -eq "podman compose") {
        podman compose down
    } else {
        & $composeCmd down
    }
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host ""
        Write-Host "✅ Services stopped successfully!" -ForegroundColor Green
        Write-Host ""
        
        Write-Host "💡 To start again, run: .\start.ps1" -ForegroundColor Cyan
        Write-Host ""
    } else {
        Write-Host ""
        Write-Host "❌ Failed to stop services!" -ForegroundColor Red
        exit 1
    }
} catch {
    Write-Host ""
    Write-Host "❌ Error: $_" -ForegroundColor Red
    exit 1
}
