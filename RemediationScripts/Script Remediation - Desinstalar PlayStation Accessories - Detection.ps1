<#
.SYNOPSIS
    DETECTION SCRIPT: DETECTAR LA APLICACION "PLAYSTATION ACCESSORIES"

.DESCRIPTION
    Este script comprueba si la aplicacion "PlayStation Accessories" de Sony está instalada.
    Busca directorios de instalacion especificos, procesos en ejecucion y claves en HKLM.

.PARAMETER
    Ninguno.

.EXAMPLE
    Executes as Intune Detection Script.

.NOTES
    Name: Script Remediation - Desinstalar PlayStation Accessories - Detection.ps1
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

$playStationDetected = $false
$Reasons = [System.Collections.Generic.List[string]]::new()

Write-Host "DETECCION: Iniciando auditoria de 'PlayStation Accessories' en el sistema..."

# 2. Comprobacion de carpetas de instalacion
$InstallationDir = "C:\Program Files\Sony\PlayStationAccessories"
if (Test-Path $InstallationDir) {
    $playStationDetected = $true
    $Reasons.Add("Directorio de instalacion detectado: $InstallationDir")
}

# 3. Comprobacion de procesos activos
$processes = Get-Process -Name "PlayStationAccessories*" -ErrorAction SilentlyContinue
if ($processes) {
    $playStationDetected = $true
    foreach ($proc in $processes) {
        $Reasons.Add("Proceso activo detectado: $($proc.Name) (PID: $($proc.Id))")
    }
}

# 4. Comprobacion de claves de registro (HKLM)
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
            if ($name -like "*PlayStationAccessories*" -or $name -like "*PlayStation Accessories*" -or $displayName -like "*PlayStationAccessories*" -or $displayName -like "*PlayStation Accessories*") {
                $playStationDetected = $true
                $Reasons.Add("Registro de desinstalacion HKLM detectado en $($basePath): $name (Nombre: $displayName)")
            }
        }
    }
}

# 5. Evaluacion final y salida
if ($playStationDetected) {
    Write-Host "DETECCION: No conforme. Se detectaron trazas de PlayStation Accessories."
    foreach ($reason in $Reasons) {
        Write-Host "DETECCION: Detalle -> $reason"
    }
    exit 1
} else {
    Write-Host "DETECCION: Conforme. No se ha encontrado ninguna traza de PlayStation Accessories."
    exit 0
}
