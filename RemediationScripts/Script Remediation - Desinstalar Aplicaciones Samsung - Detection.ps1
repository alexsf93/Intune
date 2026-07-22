<#
.SYNOPSIS
    DETECTION SCRIPT: DETECTAR APLICACIONES DE SAMSUNG (UWP/STORE)

.DESCRIPTION
    Este script audita el sistema de forma exhaustiva para comprobar si existen
    aplicaciones de Samsung (paquetes AppX/MSIX) instaladas para cualquier usuario
    o provisionadas en la imagen del sistema.

.PARAMETER
    Ninguno.

.EXAMPLE
    Executes as Intune Detection Script.

.NOTES
    Name: Script Remediation - Desinstalar Aplicaciones Samsung - Detection.ps1
    Author: Alejandro Suárez (@alexsf93)
    Version: 1.0.0
    Date: 2026-07-16
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

$SamsungDetected = $false
$Reasons = [System.Collections.Generic.List[string]]::new()

Write-Host "DETECCION: Iniciando auditoria de aplicaciones Samsung en el sistema..."

# 2. Comprobacion de paquetes AppX/MSIX (UWP/Microsoft Store) para todos los usuarios
try {
    $appxPackages = Get-AppxPackage -AllUsers -Name "*Samsung*" -ErrorAction SilentlyContinue
    if ($appxPackages) {
        $SamsungDetected = $true
        foreach ($pkg in $appxPackages) {
            $userinfo = if ($pkg.PackageUserInformation) {
                ($pkg.PackageUserInformation | ForEach-Object { $_.UserSecurityId.Username }) -join ", "
            } else {
                "Desconocido"
            }
            $Reasons.Add("Paquete AppX detectado: $($pkg.PackageFullName) (Usuario(s): $userinfo)")
        }
    }
} catch {
    Write-Host "DETECCION: Advertencia al comprobar paquetes AppX de usuarios: $_"
}

# 3. Comprobacion de paquetes AppX provisionados (para nuevos perfiles)
try {
    $provPackages = Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -like "*Samsung*" }
    if ($provPackages) {
        $SamsungDetected = $true
        foreach ($pkg in $provPackages) {
            $Reasons.Add("Paquete AppX provisionado detectado: $($pkg.DisplayName)")
        }
    }
} catch {
    Write-Host "DETECCION: Advertencia al comprobar paquetes AppX provisionados: $_"
}

# 4. Comprobacion de aplicaciones de Samsung en el registro (Win32)
Write-Host "DETECCION: Comprobando aplicaciones Win32 de Samsung registradas en el sistema..."
try {
    $registryPaths = @(
        "HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*",
        "HKLM:\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*",
        "HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*",
        "HKCU:\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*"
    )
    
    # Exclusiones de controladores y herramientas esenciales
    $Exclusions = @("NVMe", "USB Driver", "Printer", "Print", "Magician", "SSD", "Display", "Graphics", "Audio", "WLAN", "Bluetooth")
    
    $installedApps = Get-ItemProperty -Path $registryPaths -ErrorAction SilentlyContinue | Where-Object {
        $_.DisplayName -and (
            ($_.DisplayName -like "*Samsung*") -or ($_.Publisher -like "*Samsung*")
        )
    }
    
    if ($installedApps) {
        foreach ($app in $installedApps) {
            $displayName = $app.DisplayName
            $matchExclusion = $false
            foreach ($exclusion in $Exclusions) {
                if ($displayName -like "*$exclusion*") {
                    $matchExclusion = $true
                    break
                }
            }
            if (-not $matchExclusion) {
                $SamsungDetected = $true
                $versionInfo = if ($app.DisplayVersion) { " (Version: $($app.DisplayVersion))" } else { "" }
                $Reasons.Add("Aplicacion Win32 detectada en el registro: $displayName$versionInfo")
            }
        }
    }
} catch {
    Write-Host "DETECCION: Advertencia al comprobar aplicaciones en el registro: $_"
}

# 5. Evaluacion final y salida
if ($SamsungDetected) {
    Write-Host "DETECCION: No conforme. Se detectaron aplicaciones de Samsung en el sistema."
    foreach ($reason in $Reasons) {
        Write-Host "DETECCION: Detalle -> $reason"
    }
    exit 1
} else {
    Write-Host "DETECCION: Conforme. No se ha encontrado ninguna aplicacion de Samsung."
    exit 0
}
