# Trading Journal - Release Build Script
# Usage: .\tool\build-release.ps1 -Target [web|android|windows|all]

param(
    [Parameter(Mandatory=$true)]
    [ValidateSet("web", "android", "windows", "all")]
    [string]$Target,
    
    [string]$ApiKey = "",
    [string]$ApiBaseUrl = "https://finnhub.io/api/v1",
    [string]$WsUrl = "wss://ws.finnhub.io"
)

$ErrorActionPreference = "Stop"

Write-Host "=== Trading Journal Release Build ===" -ForegroundColor Cyan
Write-Host "Target: $Target" -ForegroundColor Yellow

# Build dart-define arguments
$dartDefines = @()
if ($ApiKey) {
    $dartDefines += "--dart-define=FINNHUB_API_KEY=$ApiKey"
}
$dartDefines += "--dart-define=API_BASE_URL=$ApiBaseUrl"
$dartDefines += "--dart-define=WS_URL=$WsUrl"

function Build-Web {
    Write-Host "`n>>> Building Web (CanvasKit)..." -ForegroundColor Green
    flutter build web --release --web-renderer canvaskit $dartDefines
    if ($LASTEXITCODE -ne 0) { throw "Web build failed" }
    Write-Host "Web build complete: build/web/" -ForegroundColor Green
}

function Build-Android {
    Write-Host "`n>>> Building Android AAB..." -ForegroundColor Green
    
    # Check for key.properties
    if (-not (Test-Path "android/key.properties")) {
        Write-Host "ERROR: android/key.properties not found!" -ForegroundColor Red
        Write-Host "Copy android/key.properties.example and fill in your signing credentials" -ForegroundColor Yellow
        throw "Missing key.properties"
    }
    
    # Check for google-services.json
    if (-not (Test-Path "android/app/google-services.json")) {
        Write-Host "WARNING: android/app/google-services.json not found!" -ForegroundColor Yellow
        Write-Host "Firebase features may not work. Download from Firebase Console." -ForegroundColor Yellow
    }
    
    flutter build appbundle --release $dartDefines
    if ($LASTEXITCODE -ne 0) { throw "Android build failed" }
    Write-Host "Android build complete: build/app/outputs/bundle/release/app-release.aab" -ForegroundColor Green
}

function Build-Windows {
    Write-Host "`n>>> Building Windows..." -ForegroundColor Green
    flutter build windows --release $dartDefines
    if ($LASTEXITCODE -ne 0) { throw "Windows build failed" }
    Write-Host "Windows build complete: build/windows/x64/runner/Release/" -ForegroundColor Green
}

# Clean and get dependencies
Write-Host "`n>>> Cleaning and fetching dependencies..." -ForegroundColor Blue
flutter clean
flutter pub get

# Run smoke tests
Write-Host "`n>>> Running smoke tests..." -ForegroundColor Blue
flutter test test/smoke_test.dart
if ($LASTEXITCODE -ne 0) { 
    Write-Host "Smoke tests failed! Fix before deploying." -ForegroundColor Red
    exit 1
}
Write-Host "Smoke tests passed!" -ForegroundColor Green

# Build targets
switch ($Target) {
    "web" { Build-Web }
    "android" { Build-Android }
    "windows" { Build-Windows }
    "all" {
        Build-Web
        Build-Android
        Build-Windows
    }
}

Write-Host "`n=== Build Complete ===" -ForegroundColor Cyan

