<#
.SYNOPSIS
    DETECTION SCRIPT: DETECTAR LA APLICACION "MOVE MOUSE" (UWP Y PORTABLE)

.DESCRIPTION
    Este script audita el sistema de forma exhaustiva para comprobar si la aplicacion
    "Move Mouse" esta presente. Busca en perfiles de usuario, paquetes AppX/MSIX,
    procesos activos y directorios comunes.

.PARAMETER
    Ninguno.

.EXAMPLE
    Executes as Intune Detection Script.

.NOTES
    Name: Script Remediation - Desinstalar Move Mouse - Detection.ps1
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

$MoveMouseDetected = $false
$Reasons = [System.Collections.Generic.List[string]]::new()

Write-Host "DETECCION: Iniciando auditoria de 'Move Mouse' en el sistema..."

# 2. Comprobacion de paquetes AppX/MSIX (UWP/Microsoft Store) para todos los usuarios
try {
    $appxPackages = Get-AppxPackage -AllUsers -Name "*MoveMouse*" -ErrorAction SilentlyContinue
    if ($appxPackages) {
        $MoveMouseDetected = $true
        foreach ($pkg in $appxPackages) {
            $Reasons.Add("Paquete AppX detectado: $($pkg.PackageFullName) (Usuario: $($pkg.PackageUserInformation.UserSecurityId.Username))")
        }
    }
} catch {
    Write-Host "DETECCION: Advertencia al comprobar paquetes AppX de usuarios: $_"
}

# 3. Comprobacion de paquetes AppX provisionados (para nuevos perfiles)
try {
    $provPackages = Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -like "*MoveMouse*" }
    if ($provPackages) {
        $MoveMouseDetected = $true
        foreach ($pkg in $provPackages) {
            $Reasons.Add("Paquete AppX provisionado detectado: $($pkg.DisplayName)")
        }
    }
} catch {
    Write-Host "DETECCION: Advertencia al comprobar paquetes AppX provisionados: $_"
}

# 4. Comprobacion de procesos activos
$processes = Get-Process -ErrorAction SilentlyContinue | Where-Object { $_.Name -like "*MoveMouse*" -or $_.Description -like "*Move Mouse*" }
if ($processes) {
    $MoveMouseDetected = $true
    foreach ($proc in $processes) {
        $Reasons.Add("Proceso activo detectado: $($proc.Name) (PID: $($proc.Id))")
    }
}

# 5. Comprobacion de directorios comunes y perfiles de usuario
$ProfilePaths = Get-ChildItem -Path "C:\Users" -ErrorAction SilentlyContinue | Where-Object { $_.PSIsContainer }
$ScanPaths = [System.Collections.Generic.List[string]]::new()

# Directorio de instalacion de WindowsApps y Program Files
$ScanPaths.Add("$env:ProgramFiles\WindowsApps")
$ScanPaths.Add("$env:ProgramFiles\Move Mouse")
$ScanPaths.Add("${env:ProgramFiles(x86)}\Move Mouse")
$ScanPaths.Add("$env:ProgramData\Move Mouse")

# Anadir rutas especificas de perfiles de usuario
foreach ($profile in $ProfilePaths) {
    $userPath = $profile.FullName
    
    # Omitir perfiles del sistema por defecto
    if ($profile.Name -in @("All Users", "Default", "Default User", "Public")) { continue }

    $ScanPaths.Add("$userPath\AppData\Local\Packages")
    $ScanPaths.Add("$userPath\AppData\Local\Move Mouse")
    $ScanPaths.Add("$userPath\AppData\Roaming\Move Mouse")
    $ScanPaths.Add("$userPath\Downloads")
    $ScanPaths.Add("$userPath\Desktop")
}

# Evaluar existencia de carpetas u archivos de Move Mouse
foreach ($path in $ScanPaths) {
    if (Test-Path $path -ErrorAction SilentlyContinue) {
        if ($path -like "*WindowsApps" -or $path -like "*Packages") {
            # En carpetas de contenedores, buscar subcarpetas que coincidan con MoveMouse
            $subDirs = Get-ChildItem -Path $path -Filter "*MoveMouse*" -Directory -ErrorAction SilentlyContinue
            if ($subDirs) {
                $MoveMouseDetected = $true
                foreach ($dir in $subDirs) {
                    $Reasons.Add("Carpeta residual detectada: $($dir.FullName)")
                }
            }
        } elseif ($path -like "*Downloads" -or $path -like "*Desktop") {
            # En descargas y escritorio, buscar ejecutables especificos
            $executables = Get-ChildItem -Path $path -Filter "*MoveMouse*.exe" -File -ErrorAction SilentlyContinue
            if ($executables) {
                $MoveMouseDetected = $true
                foreach ($exe in $executables) {
                    $Reasons.Add("Ejecutable portable detectado: $($exe.FullName)")
                }
            }
        } else {
            # Otras carpetas directas
            $MoveMouseDetected = $true
            $Reasons.Add("Carpeta de aplicacion detectada: $path")
        }
    }
}

# 6. Evaluacion final y salida
if ($MoveMouseDetected) {
    Write-Host "DETECCION: No conforme. Se detecto Move Mouse en el sistema."
    foreach ($reason in $Reasons) {
        Write-Host "DETECCION: Detalle -> $reason"
    }
    exit 1
} else {
    Write-Host "DETECCION: Conforme. No se ha encontrado ninguna traza de Move Mouse."
    exit 0
}
