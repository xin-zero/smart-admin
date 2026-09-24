$ErrorActionPreference = 'Stop'
[Console]::InputEncoding = [System.Text.UTF8Encoding]::new($false)
[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false)
$OutputEncoding = [System.Text.UTF8Encoding]::new($false)
chcp 65001 | Out-Null

$projectRoot = $PSScriptRoot
$apiRoot = Join-Path $projectRoot 'smart-admin-api'
$mavenRepository = 'D:\m2\repository'
$dockerRoot = 'D:\docker'
$dbComposeFile = Join-Path $dockerRoot 'compose.db.yaml'
$cacheComposeFile = Join-Path $dockerRoot 'compose.cache.yaml'

foreach ($requiredPath in @($apiRoot, $mavenRepository, $dockerRoot, $dbComposeFile, $cacheComposeFile)) {
    if (-not (Test-Path -LiteralPath $requiredPath)) {
        throw "Required path not found: $requiredPath"
    }
}

if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
    throw 'Docker CLI was not found in PATH.'
}
if (-not (Get-Command mvn.cmd -ErrorAction SilentlyContinue)) {
    throw 'Maven (mvn.cmd) was not found in PATH.'
}
if (-not (Get-Command java.exe -ErrorAction SilentlyContinue)) {
    throw 'Java (java.exe) was not found in PATH.'
}

# Check the daemon before any network/container operation so permission and
# Docker Desktop startup errors are reported directly.
$null = & cmd.exe /d /c 'docker info >nul 2>nul'
if ($LASTEXITCODE -ne 0) {
    throw 'Docker daemon is unavailable. Start Docker Desktop and ensure this shell can access it.'
}

$sharedNetwork = docker network ls --filter 'name=^shared-services$' --format '{{.Name}}'
if ($LASTEXITCODE -ne 0) {
    throw 'Unable to inspect Docker networks.'
}
if (-not $sharedNetwork) {
    docker network create shared-services | Out-Null
    if ($LASTEXITCODE -ne 0) {
        throw 'Unable to create the shared-services Docker network.'
    }
}

Push-Location $dockerRoot
try {
    $mysqlRunning = docker inspect --format '{{.State.Running}}' mw-db-mysql 2>$null
    if ($mysqlRunning -ne 'true') {
        Write-Host 'Starting MySQL only...' -ForegroundColor Cyan
        docker compose -f $dbComposeFile up -d --pull never --wait mysql
        if ($LASTEXITCODE -ne 0) {
            throw 'MySQL startup failed.'
        }
    } else {
        Write-Host 'MySQL is already running; skipping startup.' -ForegroundColor DarkGray
    }

    $redisRunning = docker inspect --format '{{.State.Running}}' mw-cache-redis 2>$null
    if ($redisRunning -ne 'true') {
        Write-Host 'Starting Redis only...' -ForegroundColor Cyan
        docker compose -f $cacheComposeFile up -d --pull never --wait redis
        if ($LASTEXITCODE -ne 0) {
            throw 'Redis startup failed.'
        }
    } else {
        Write-Host 'Redis is already running; skipping startup.' -ForegroundColor DarkGray
    }
} finally {
    Pop-Location
}

foreach ($containerName in @('mw-db-mysql', 'mw-cache-redis')) {
    $running = docker inspect --format '{{.State.Running}}' $containerName 2>$null
    if ($LASTEXITCODE -ne 0 -or $running -ne 'true') {
        throw "Required middleware container is not running: $containerName"
    }
}

Push-Location $apiRoot
try {
    Write-Host 'Building backend with Maven...' -ForegroundColor Cyan
    & mvn.cmd "-Dmaven.repo.local=$mavenRepository" -Pdev clean package -DskipTests
    if ($LASTEXITCODE -ne 0) {
        throw "Backend build failed with exit code $LASTEXITCODE."
    }

    $jar = Get-ChildItem -LiteralPath (Join-Path $apiRoot 'sa-admin\target') -Filter 'sa-admin-*.jar' -File |
        Where-Object { $_.Name -notlike '*-original.jar' } |
        Sort-Object LastWriteTime -Descending |
        Select-Object -First 1
    if ($null -eq $jar) {
        throw 'Backend JAR was not produced by the Maven build.'
    }

    Write-Host "Starting backend in the foreground: $($jar.Name)" -ForegroundColor Green
    $mysqlUrl = 'jdbc:p6spy:mysql://127.0.0.1:3306/smart_admin_v3?autoReconnect=true&useServerPreparedStmts=false&rewriteBatchedStatements=true&characterEncoding=UTF-8&useSSL=false&allowMultiQueries=true&allowPublicKeyRetrieval=true&serverTimezone=Asia/Shanghai'
    & java.exe '-Dfile.encoding=UTF-8' '-Dsun.stdout.encoding=UTF-8' '-Dsun.stderr.encoding=UTF-8' -jar $jar.FullName --spring.profiles.active=dev --spring.datasource.url=$mysqlUrl
    exit $LASTEXITCODE
}
finally {
    Pop-Location
}
