param(
    [string]$Tag = "latest",
    [string]$RemoteImage = "<dockerhub-user>/poc-ui",
    [string]$LocalImage = "poc-ui",
    [switch]$SkipLogin,
    [switch]$SkipPush
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
# A missing Docker Hub tag makes `docker manifest inspect` exit 1. That is expected.
$PSNativeCommandUseErrorActionPreference = $false
Set-Location $PSScriptRoot

if ($RemoteImage -match "[<>\s]") {
    throw "Set -RemoteImage to your Docker Hub image (for example yourname/poc-ui). '<dockerhub-user>/poc-ui' is a placeholder."
}

Write-Host "==> check docker"
if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
    throw "docker CLI not found. Install Docker and ensure it is on PATH."
}
docker info *> $null
if ($LASTEXITCODE -ne 0) {
    throw "Docker daemon is not running."
}

if (-not $SkipPush -and -not $SkipLogin) {
    Write-Host "==> check Docker Hub login"
    $dockerConfig = Join-Path $env:USERPROFILE ".docker\config.json"
    $loggedIn = $false
    if (Test-Path -LiteralPath $dockerConfig) {
        $config = Get-Content -LiteralPath $dockerConfig -Raw | ConvertFrom-Json
        # Docker Desktop keeps the token in credsStore and only lists the registry here.
        if ($config.PSObject.Properties.Name -contains "auths" -and $null -ne $config.auths) {
            foreach ($name in @($config.auths.PSObject.Properties.Name)) {
                if ($name -match "docker\.io") {
                    $loggedIn = $true
                }
            }
        }
    }
    if (-not $loggedIn) {
        docker login
        if ($LASTEXITCODE -ne 0) {
            throw "docker login failed (exit $LASTEXITCODE)."
        }
    }
}

if ($Tag -ne "latest" -and -not $SkipPush) {
    Write-Host "==> check remote tag ${RemoteImage}:${Tag}"
    docker manifest inspect "${RemoteImage}:${Tag}" *> $null
    if ($LASTEXITCODE -eq 0) {
        throw "${RemoteImage}:${Tag} already exists on Docker Hub. Versions are never overwritten."
    }
}

Write-Host "==> docker build"
docker build -t "${LocalImage}:${Tag}" .
if ($LASTEXITCODE -ne 0) {
    throw "docker build failed (exit $LASTEXITCODE)."
}

Write-Host "==> docker tag"
docker tag "${LocalImage}:${Tag}" "${RemoteImage}:${Tag}"
if ($LASTEXITCODE -ne 0) {
    throw "docker tag failed (exit $LASTEXITCODE)."
}
if ($Tag -ne "latest") {
    docker tag "${LocalImage}:${Tag}" "${RemoteImage}:latest"
    if ($LASTEXITCODE -ne 0) {
        throw "docker tag ${RemoteImage}:latest failed (exit $LASTEXITCODE)."
    }
}

if ($SkipPush) {
    Write-Host "Built ${LocalImage}:${Tag}"
    Write-Host "Tagged ${RemoteImage}:${Tag}"
    if ($Tag -ne "latest") {
        Write-Host "Tagged ${RemoteImage}:latest"
    }
    exit 0
}

Write-Host "==> docker push"
docker push "${RemoteImage}:${Tag}"
if ($LASTEXITCODE -ne 0) {
    throw "docker push ${RemoteImage}:${Tag} failed (exit $LASTEXITCODE)."
}
if ($Tag -ne "latest") {
    docker push "${RemoteImage}:latest"
    if ($LASTEXITCODE -ne 0) {
        throw "docker push ${RemoteImage}:latest failed (exit $LASTEXITCODE)."
    }
}
