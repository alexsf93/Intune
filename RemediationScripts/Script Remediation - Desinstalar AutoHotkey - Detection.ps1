<#
.SYNOPSIS
    DETECTION SCRIPT: DETECTAR LA APLICACION "AUTOHOTKEY"

.DESCRIPTION
    Este script audita el sistema de forma exhaustiva para comprobar si la aplicacion
    "AutoHotkey" esta presente. Busca claves de desinstalacion en el registro HKLM,
    directorios en Program Files, Program Files (x86) y Local AppData (incluyendo perfiles
    de usuario), y procesos activos que coincidan con "AutoHotkey*".

.PARAMETER
    Ninguno.

.EXAMPLE
    Executes as Intune Detection Script.

.NOTES
    Name: Script Remediation - Desinstalar AutoHotkey - Detection.ps1
    Author: Alejandro Suarez (@alexsf93)
    Version: 1.0.0
    Date: 2026-06-23
    Context: System
#>

# Forzar codificacion UTF-8 para evitar problemas de caracteres en los logs
$OutputEncoding = [System.Text.Encoding]::UTF8

# 1. Asegurar entorno de ejecucion de 64 bits para evitar redireccion de carpetas y registro
if ([Environment]::Is64BitOperatingSystem -and -not [Environment]::Is64BitProcess) {
    Write-Host "DETECCION: Ejecutando en proceso de 32 bits. Relanzando en PowerShell de 64 bits..."
    $powershell64 = Join-Path $env:SystemRoot "Sysnative\WindowsPowerShell\v1.0\powershell.exe"
    if (Test-Path $powershell64) {
        $arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`""
        Start-Process -FilePath $powershell64 -ArgumentList $arguments -Wait -NoNewWindow
        exit $LASTEXITCODE
    } else {
        Write-Host "DETECCION: No se pudo encontrar el ejecutable de PowerShell de 64 bits en Sysnative. Continuando en modo actual."
    }
}

$ahkDetected = $false
$Reasons = [System.Collections.Generic.List[string]]::new()

Write-Host "DETECCION: Iniciando auditoria de 'AutoHotkey' en el sistema..."

# 2. Comprobacion de claves de registro (HKLM)
$UninstallPaths = @(
    "HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall",
    "HKLM:\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall"
)
foreach ($basePath in $UninstallPaths) {
    if (Test-Path $basePath) {
        $keys = Get-ChildItem -Path $basePath -ErrorAction SilentlyContinue
        foreach ($key in $keys) {
            $name = $key.PSChildName
            $displayName = $key.GetValue("DisplayName")
            if ($name -like "*AutoHotkey*" -or $displayName -like "*AutoHotkey*") {
                $ahkDetected = $true
                $Reasons.Add("Registro de desinstalacion HKLM detectado en $($basePath): $name (Nombre: $displayName)")
            }
        }
    }
}

# 3. Comprobacion de directorios comunes
$ScanPaths = [System.Collections.Generic.List[string]]::new()
if ($env:ProgramFiles) { $ScanPaths.Add((Join-Path $env:ProgramFiles "AutoHotkey")) }
if (${env:ProgramFiles(x86)}) { $ScanPaths.Add((Join-Path ${env:ProgramFiles(x86)} "AutoHotkey")) }
if ($env:LocalAppData) { $ScanPaths.Add((Join-Path $env:LocalAppData "AutoHotkey")) }

# Perfiles de usuario AppData\Local
$ProfilePaths = Get-ChildItem -Path "C:\Users" -ErrorAction SilentlyContinue | Where-Object { $_.PSIsContainer }
foreach ($profile in $ProfilePaths) {
    if ($profile.Name -in @("All Users", "Default", "Default User", "Public")) { continue }
    $userPath = $profile.FullName
    $ScanPaths.Add((Join-Path $userPath "AppData\Local\AutoHotkey"))
    $ScanPaths.Add((Join-Path $userPath "AppData\Local\Programs\AutoHotkey"))
}

foreach ($path in $ScanPaths) {
    if (Test-Path $path -ErrorAction SilentlyContinue) {
        $ahkDetected = $true
        $Reasons.Add("Directorio de AutoHotkey detectado: $path")
    }
}

# 4. Comprobacion de procesos activos
$processes = Get-Process -Name "AutoHotkey*" -ErrorAction SilentlyContinue
if ($processes) {
    $ahkDetected = $true
    foreach ($proc in $processes) {
        $Reasons.Add("Proceso activo detectado: $($proc.Name) (PID: $($proc.Id))")
    }
}

# 5. Evaluacion final y salida
if ($ahkDetected) {
    Write-Host "DETECCION: No conforme. Se detectaron trazas de AutoHotkey."
    foreach ($reason in $Reasons) {
        Write-Host "DETECCION: Detalle -> $reason"
    }
    exit 1
} else {
    Write-Host "DETECCION: Conforme. No se ha encontrado ninguna traza de AutoHotkey."
    exit 0
}
