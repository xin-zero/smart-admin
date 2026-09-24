$ErrorActionPreference = 'Stop'
[Console]::InputEncoding = [System.Text.UTF8Encoding]::new($false)
[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false)
$OutputEncoding = [System.Text.UTF8Encoding]::new($false)
chcp 65001 | Out-Null

$frontendRoot = Join-Path $PSScriptRoot 'smart-admin-web'
if (-not (Test-Path -LiteralPath $frontendRoot)) {
    throw "Frontend directory not found: $frontendRoot"
}
if (-not (Test-Path -LiteralPath (Join-Path $frontendRoot 'package.json'))) {
    throw "Frontend package manifest not found in: $frontendRoot"
}
if (-not (Get-Command npm.cmd -ErrorAction SilentlyContinue)) {
    throw 'npm (npm.cmd) was not found in PATH.'
}

if ([string]::IsNullOrWhiteSpace($env:VITE_APP_API_URL)) {
    $env:VITE_APP_API_URL = 'http://127.0.0.1:1024'
}

Push-Location $frontendRoot
try {
    if (-not (Test-Path -LiteralPath (Join-Path $frontendRoot 'node_modules'))) {
        Write-Host 'Installing frontend dependencies...' -ForegroundColor Cyan
        & npm.cmd install --no-package-lock
        if ($LASTEXITCODE -ne 0) {
            throw "Frontend dependency installation failed with exit code $LASTEXITCODE."
        }
    }

    Write-Host 'Starting frontend in the foreground...' -ForegroundColor Green
    & npm.cmd run dev
    exit $LASTEXITCODE
}
finally {
    Pop-Location
}
