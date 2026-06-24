<#
.SYNOPSIS
    DETECTION SCRIPT: Script de deteccion para la limpieza de almacenamiento.

.DESCRIPTION
    Calcula el espacio ocupado por componentes de Windows Update, cache de entrega,
    archivos temporales, miniaturas, volcados DMP, informes WER y logs de recuperacion.

.PARAMETER
    Ninguno.

.EXAMPLE
    Executes as Intune Detection Script.

.NOTES
    Name: Script Remediation - WindowsUpdateCleanup - Detection.ps1
    Author: Alejandro Suarez (@alexsf93)
    Version: 3.6.1
    Date: 2026-06-15
    Context: System
#>

$storageThresholdMB = 400
$totalBytes = 0

$targetDirectories = @(
    "C:\Windows\SoftwareDistribution\Download",
    "C:\Windows\SoftwareDistribution\PostRebootEventCache.V2",
    "C:\Windows\Logs\WindowsUpdate",
    "C:\Windows\Temp",
    "C:\Windows\Prefetch",
    "C:\ProgramData\Microsoft\Windows\DeliveryOptimization\Cache",
    "C:\ProgramData\Microsoft\Windows Defender\Scans\History\Results",
    "C:\Windows\Downloaded Program Files",
    "C:\Windows\Minidump",
    "C:\ProgramData\Microsoft\Windows\WER\ReportArchive",
    "C:\ProgramData\Microsoft\Windows\WER\ReportQueue",
    "C:\ProgramData\Microsoft\Windows\WER\Temp",
    "C:\$Recycle.Bin",
    "C:\$Windows.~BT\Sources\Rollback",
    "C:\Windows\System32\LogFiles\Setupcln"
)

$targetFiles = @()

if (Test-Path "C:\Windows\MEMORY.DMP") {
    $targetFiles += "C:\Windows\MEMORY.DMP"
}

$userProfiles = Get-ChildItem -Path "C:\Users" -ErrorAction SilentlyContinue
foreach ($profile in $userProfiles) {
    $userTemp = Join-Path $profile.FullName "AppData\Local\Temp"
    if (Test-Path $userTemp) { $targetDirectories += $userTemp }

    $userNetCache = Join-Path $profile.FullName "AppData\Local\Microsoft\Windows\INetCache"
    if (Test-Path $userNetCache) { $targetDirectories += $userNetCache }

    $userDirectX = Join-Path $profile.FullName "AppData\Local\D3DSCache"
    if (Test-Path $userDirectX) { $targetDirectories += $userDirectX }

    $userThumbs = Join-Path $profile.FullName "AppData\Local\Microsoft\Windows\Explorer"
    if (Test-Path $userThumbs) {
        $thumbs = Get-ChildItem -Path $userThumbs -Filter "thumbcache_*.db" -ErrorAction SilentlyContinue
        $icons = Get-ChildItem -Path $userThumbs -Filter "iconcache_*.db" -ErrorAction SilentlyContinue
        
        foreach ($f in $thumbs) { $targetFiles += $f.FullName }
        foreach ($f in $icons) { $targetFiles += $f.FullName }
    }
}

foreach ($dir in $targetDirectories) {
    if (Test-Path $dir) {
        $size = Get-ChildItem -Path $dir -Recurse -File -ErrorAction SilentlyContinue | 
                Measure-Object -Property Length -Sum -ErrorAction SilentlyContinue | 
                Select-Object -ExpandProperty Sum
        if ($size) { $totalBytes += $size }
    }
}

foreach ($file in $targetFiles) {
    if (Test-Path $file) {
        $size = (Get-Item -Path $file -ErrorAction SilentlyContinue).Length
        if ($size) { $totalBytes += $size }
    }
}

$updateCleanupSizeMB = [math]::Round($totalBytes / 1MB, 2)

if ($updateCleanupSizeMB -gt $storageThresholdMB) {
    Write-Host "Deteccion: Se han encontrado ($updateCleanupSizeMB MB) acumulados. Requiere remediacion."
    exit 1
} else {
    Write-Host "Deteccion: El sistema esta limpio. Espacio detectado ($updateCleanupSizeMB MB), por debajo del umbral."
    exit 0
}
