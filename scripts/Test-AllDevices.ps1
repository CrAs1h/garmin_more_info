<#
.SYNOPSIS
    批量编译并测试所有 Garmin 表盘设备。

.DESCRIPTION
    从 manifest.xml 自动读取所有设备 ID，然后逐一编译。
    默认按"系列+分辨率"分组，相同组只随机挑选一台测试，减少重复。
    可选模式：
      - build : 仅编译，验证所有机型无编译错误（默认）
      - sim   : 编译后启动模拟器，运行表盘并自动截图

.PARAMETER Mode
    运行模式：build（仅编译） 或 sim（编译+模拟器截图）

.PARAMETER Device
    可选。指定单个设备 ID 进行测试，不指定则测试所有设备。

.PARAMETER ScreenshotDelay
    模拟器截图前等待的秒数，默认 6 秒（给表盘初始化时间）。

.PARAMETER NoDedup
    禁用去重，测试 manifest 中所有设备。

.EXAMPLE
    .\Test-AllDevices.ps1
    .\Test-AllDevices.ps1 -Mode sim
    .\Test-AllDevices.ps1 -Mode build -Device fenix7
    .\Test-AllDevices.ps1 -Mode sim -ScreenshotDelay 8
    .\Test-AllDevices.ps1 -NoDedup
#>
param(
    [ValidateSet("build", "sim")]
    [string] $Mode = "build",

    [string] $Device = "",

    [int] $ScreenshotDelay = 6,

    [switch] $NoDedup
)

# --- 路径配置 ---
$projectRoot   = Resolve-Path (Join-Path $PSScriptRoot "..")
& python (Join-Path $PSScriptRoot "generate_device_settings.py")
if ($LASTEXITCODE -ne 0) { throw "Device settings generation failed" }
$manifestPath  = Join-Path $projectRoot "manifest.xml"
$junglePath    = Join-Path $projectRoot "monkey.jungle"
$keyPath       = Join-Path $projectRoot "developer_key.der"
$outputDir     = Join-Path $projectRoot "bin\test"
$screenshotDir = Join-Path $projectRoot "bin\screenshots"

# SDK 路径
$sdkBase   = "$env:APPDATA\Garmin\ConnectIQ"
$sdkPath   = (Get-Content (Join-Path $sdkBase "current-sdk.cfg")).Trim().TrimEnd('\')
$monkeyc   = Join-Path $sdkPath "bin\monkeyc.bat"
$monkeydo  = Join-Path $sdkPath "bin\monkeydo.bat"
$simulator = Join-Path $sdkPath "bin\simulator.exe"

# --- 验证环境 ---
if (-not (Test-Path $monkeyc)) {
    Write-Host "[ERROR] monkeyc not found: $monkeyc" -ForegroundColor Red
    exit 1
}
if (-not (Test-Path $keyPath)) {
    Write-Host "[ERROR] developer key not found: $keyPath" -ForegroundColor Red
    exit 1
}

# --- 从 manifest.xml 提取设备列表 ---
[xml]$manifest = Get-Content $manifestPath
$ns = New-Object System.Xml.XmlNamespaceManager($manifest.NameTable)
$ns.AddNamespace("iq", "http://www.garmin.com/xml/connectiq")
$allDevices = $manifest.SelectNodes("//iq:product", $ns) | ForEach-Object { $_.id }

if ($Device) {
    if ($allDevices -notcontains $Device) {
        Write-Host "[ERROR] Device '$Device' not in manifest.xml." -ForegroundColor Red
        Write-Host "  Available: $($allDevices -join ', ')" -ForegroundColor Yellow
        exit 1
    }
    $devices = @($Device)
}
else {
    $devices = $allDevices
}

# --- 设备去重：按系列+分辨率分组，每组随机选一台 ---
function Get-DeviceGroupKey([string]$devId) {
    switch ($devId) {
        "approachs7042mm" { return "Approach_390" }
        "approachs7047mm" { return "Approach_454" }
        "d2mach1"         { return "D2_416" }
        "epix2"           { return "epix_416" }
        "fenix6spro"      { return "fenix_240" }
        "fenix6pro"       { return "fenix_260" }
        "fenix6xpro"      { return "fenix_280" }
        "fenix7s"         { return "fenix_240" }
        "fenix7"          { return "fenix_260" }
        "fenix7x"         { return "fenix_280" }
        "fr55"            { return "Forerunner_208" }
        "fr255s"          { return "Forerunner_218" }
        "fr255"           { return "Forerunner_260" }
        "fr265s"          { return "Forerunner_360" }
        "fr265"           { return "Forerunner_416" }
        "fr955"           { return "Forerunner_260" }
        "fr965"           { return "Forerunner_454" }
        "marq2"           { return "MARQ_390" }
        "venu2"           { return "Venu_416" }
        "venu2s"          { return "Venu_360" }
        "venu3"           { return "Venu_454" }
        "venu3s"          { return "Venu_390" }
        "vivoactive5"     { return "vivoactive_390" }
        default           { return "unknown_$devId" }
    }
}

if (-not $Device -and -not $NoDedup) {
    # 按 "系列_分辨率" 分组
    $groups = @{}
    foreach ($d in $allDevices) {
        $k = Get-DeviceGroupKey $d
        if (-not $groups.ContainsKey($k)) {
            $groups[$k] = @()
        }
        $groups[$k] += $d
    }

    $dedupList = @()
    $skippedList = @()

    foreach ($k in $groups.Keys) {
        $items = @($groups[$k])
        if ($items.Count -gt 1) {
            $pickIdx = Get-Random -Minimum 0 -Maximum $items.Count
            $picked = $items[$pickIdx]
            $dedupList += $picked
            for ($j = 0; $j -lt $items.Count; $j++) {
                if ($j -ne $pickIdx) {
                    $skippedList += $items[$j]
                }
            }
        } else {
            $dedupList += $items[0]
        }
    }

    $devices = $dedupList

    if ($skippedList.Count -gt 0) {
        Write-Host "  [Dedup] 相同系列+分辨率去重，跳过: $($skippedList -join ', ')" -ForegroundColor DarkYellow
        Write-Host "  [Dedup] 测试设备: $($devices.Count)/$($allDevices.Count)" -ForegroundColor DarkYellow
        Write-Host ""
    }
}

# --- 创建输出目录 ---
New-Item -ItemType Directory -Force -Path $outputDir | Out-Null
if ($Mode -eq "sim") {
    New-Item -ItemType Directory -Force -Path $screenshotDir | Out-Null
}

# --- 编译函数 ---
function Build-Device {
    param([string]$DeviceId)

    $prgFile = Join-Path $outputDir "$DeviceId.prg"
    $stdoutLog = Join-Path $outputDir "$DeviceId.stdout.log"
    $stderrLog = Join-Path $outputDir "$DeviceId.stderr.log"

    $buildArgs = @(
        "-f", $junglePath,
        "-d", $DeviceId,
        "-o", $prgFile,
        "-y", $keyPath,
        "-w"
    )

    $process = Start-Process -FilePath $monkeyc `
        -ArgumentList $buildArgs `
        -NoNewWindow -Wait -PassThru `
        -RedirectStandardOutput $stdoutLog `
        -RedirectStandardError  $stderrLog

    $stdoutContent = ""
    $stderrContent = ""
    if (Test-Path $stdoutLog) { $stdoutContent = Get-Content $stdoutLog -Raw -ErrorAction SilentlyContinue }
    if (Test-Path $stderrLog) { $stderrContent = Get-Content $stderrLog -Raw -ErrorAction SilentlyContinue }

    return @{
        ExitCode = $process.ExitCode;
        PrgFile  = $prgFile;
        StdOut   = $stdoutContent;
        StdErr   = $stderrContent
    }
}

# --- Windows API 截图 ---
Add-Type -Language CSharp -ReferencedAssemblies System.Drawing -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
using System.Drawing;
using System.Drawing.Imaging;
public class WinCapture {
    [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out RECT r);
    [DllImport("user32.dll")] public static extern bool PrintWindow(IntPtr h, IntPtr hdc, uint f);
    [StructLayout(LayoutKind.Sequential)] public struct RECT { public int L,T,R,B; }
    public static void Save(IntPtr h, string path) {
        RECT r; GetWindowRect(h, out r);
        int w=r.R-r.L, ht=r.B-r.T; if(w<=0||ht<=0) return;
        using(var b=new Bitmap(w,ht,PixelFormat.Format32bppArgb)){
            using(var g=Graphics.FromImage(b)){ var dc=g.GetHdc(); PrintWindow(h,dc,2); g.ReleaseHdc(dc); }
            b.Save(path,ImageFormat.Png);
        }
    }
}
'@ -ErrorAction SilentlyContinue

# --- 模拟器截图函数（单次启动） ---
function Invoke-SimScreenshot {
    param([string]$DeviceId, [string]$PrgFile)

    $screenshotFile = Join-Path $screenshotDir "$DeviceId.png"

    # 用 monkeydo 加载 PRG（异步启动，shell.exe 使用 -Wait 会挂起）
    Start-Process -FilePath $monkeydo -ArgumentList @($PrgFile, $DeviceId)
    Start-Sleep -Seconds $ScreenshotDelay

    # 截图
    $simProc = Get-Process -Name "simulator" -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($simProc -and $simProc.MainWindowHandle -ne [IntPtr]::Zero) {
        try { [WinCapture]::Save($simProc.MainWindowHandle, $screenshotFile) } catch {}
    }

    return (Test-Path $screenshotFile)
}

# --- 主流程 ---
$total   = $devices.Count
$success = 0
$failed  = 0
$results = @()

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Garmin Watch Face - Batch Test"         -ForegroundColor Cyan
Write-Host "  Mode: $Mode  |  Devices: $total"        -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# sim 模式：预先启动模拟器（只启动一次）
if ($Mode -eq "sim") {
    New-Item -ItemType Directory -Force -Path $screenshotDir | Out-Null
    Get-Process -Name "simulator" -ErrorAction SilentlyContinue | Stop-Process -Force
    Start-Sleep -Seconds 1
    Start-Process -FilePath $simulator
    Start-Sleep -Seconds 4
    Write-Host "  Simulator started (single instance)." -ForegroundColor Yellow
    Write-Host ""
}

$stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

for ($i = 0; $i -lt $total; $i++) {
    $dev = $devices[$i]
    $num = $i + 1
    Write-Host "[$num/$total] Building $dev ... " -NoNewline

    $buildResult = Build-Device -DeviceId $dev

    if ($buildResult.ExitCode -eq 0) {
        Write-Host "[OK]" -ForegroundColor Green -NoNewline

        if ($Mode -eq "sim") {
            Write-Host " -> Screenshot ... " -NoNewline
            $ok = Invoke-SimScreenshot -DeviceId $dev -PrgFile $buildResult.PrgFile
            if ($ok) { Write-Host "[SCREENSHOT OK]" -ForegroundColor Green }
            else     { Write-Host "[SCREENSHOT FAIL]" -ForegroundColor Yellow }
        }
        else {
            Write-Host ""
        }

        $success++
        $results += [PSCustomObject]@{
            Device = $dev;
            Status = "OK";
            Error  = ""
        }
    }
    else {
        Write-Host "[FAIL]" -ForegroundColor Red

        $errMsg = "Unknown error"
        if ($buildResult.StdErr -and $buildResult.StdErr.Length -gt 0) {
            $errMsg = ($buildResult.StdErr.Trim() -split "\r?\n")[0]
            Write-Host "         $errMsg" -ForegroundColor DarkRed
        }

        $failed++
        $results += [PSCustomObject]@{ Device = $dev; Status = "FAIL"; Error = $errMsg }
    }
}

# sim 模式结束后关闭模拟器
if ($Mode -eq "sim") {
    Get-Process -Name "simulator" -ErrorAction SilentlyContinue | Stop-Process -Force
}

$stopwatch.Stop()

# --- 输出结果摘要 ---
Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Test Summary"                            -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
$elapsed = [math]::Round($stopwatch.Elapsed.TotalSeconds, 1)
Write-Host "  Total: $total  |  OK: $success  |  FAIL: $failed  |  Time: ${elapsed}s" -ForegroundColor White
Write-Host ""

if ($failed -gt 0) {
    Write-Host "  Failed devices:" -ForegroundColor Red
    $results | Where-Object { $_.Status -eq "FAIL" } | ForEach-Object {
        Write-Host "    - $($_.Device): $($_.Error)" -ForegroundColor Red
    }
    Write-Host ""
    Write-Host "  Logs: $outputDir" -ForegroundColor Yellow
}

if ($Mode -eq "sim" -and (Test-Path $screenshotDir)) {
    $pngs = Get-ChildItem $screenshotDir -Filter "*.png" -ErrorAction SilentlyContinue
    $screenshotCount = 0
    if ($pngs) { $screenshotCount = @($pngs).Count }
    Write-Host "  Screenshots: $screenshotDir ($screenshotCount files)" -ForegroundColor Green
}

Write-Host ""

# 生成 CSV 报告
$reportFile = Join-Path $outputDir "test-report.csv"
$results | Export-Csv -Path $reportFile -NoTypeInformation -Encoding UTF8
Write-Host "  Report: $reportFile" -ForegroundColor Cyan
Write-Host ""

# 返回退出码
if ($failed -gt 0) { exit 1 } else { exit 0 }
