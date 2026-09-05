# Garmin Watch Face - Export IQ Package
# Exit codes: 0 = Success, 1 = Error

$projectRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
& python (Join-Path $PSScriptRoot "generate_device_settings.py")
if ($LASTEXITCODE -ne 0) { throw "Device settings generation failed" }
$junglePath  = Join-Path $projectRoot "monkey.jungle"
$keyPath     = Join-Path $projectRoot "developer_key.der"
$outputDir   = Join-Path $projectRoot "bin"
$outputFile  = Join-Path $outputDir "garmin_more_info.iq"

$sdkBase   = "$env:APPDATA\Garmin\ConnectIQ"
$sdkConfig = Join-Path $sdkBase "current-sdk.cfg"

Write-Host "========================================"
Write-Host "  Garmin Watch Face - Export IQ Package"
Write-Host "========================================"
Write-Host ""

if (-not (Test-Path $sdkConfig)) {
    Write-Host "[ERROR] Garmin SDK config not found: $sdkConfig"
    exit 1
}

$sdkPath = (Get-Content $sdkConfig).Trim().TrimEnd('\')
$monkeyc = Join-Path $sdkPath "bin\monkeyc.bat"

if (-not (Test-Path $monkeyc)) {
    Write-Host "[ERROR] monkeyc compiler not found: $monkeyc"
    exit 1
}

if (-not (Test-Path $keyPath)) {
    Write-Host "[ERROR] Developer key not found: $keyPath"
    Write-Host "Please generate developer_key.der and place it in the project root."
    exit 1
}

if (-not (Test-Path $outputDir)) {
    New-Item -ItemType Directory -Force -Path $outputDir | Out-Null
}

Write-Host "SDK Path: $sdkPath"
Write-Host "Key Path: $keyPath"
Write-Host "Output:   $outputFile"
Write-Host "Exporting package for all devices, please wait..."

$buildArgs = @(
    "-e",
    "-f", $junglePath,
    "-y", $keyPath,
    "-o", $outputFile
)

$stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
$process = Start-Process -FilePath $monkeyc -ArgumentList $buildArgs -NoNewWindow -Wait -PassThru
$stopwatch.Stop()
$elapsed = [math]::Round($stopwatch.Elapsed.TotalSeconds, 1)

if ($process.ExitCode -eq 0 -and (Test-Path $outputFile)) {
    Write-Host ""
    Write-Host "[SUCCESS] Export completed successfully!"
    Write-Host "Output file: $outputFile"
    Write-Host "Time elapsed: ${elapsed}s"
    exit 0
} else {
    Write-Host ""
    Write-Host "[ERROR] Export failed with exit code: $($process.ExitCode)"
    exit 1
}
