<#
.SYNOPSIS
    DETECTION SCRIPT: DETECTAR LA APLICACION "OP AUTO CLICKER"

.DESCRIPTION
    Este script comprueba si la aplicacion "OP Auto Clicker" (tambien conocida como
    "OP Auto Clicker - Auto Tap") esta instalada en el sistema, ya sea como paquete
    UWP/AppX de la Microsoft Store o como ejecutable standalone.

    Busca en:
      - Paquetes AppX instalados para todos los usuarios
      - Paquetes AppX provisionados del sistema
      - Procesos activos relacionados
      - Claves de registro Uninstall (standalone con Inno Setup y otros)
      - Directorio de instalacion comun de standalone (Program Files, LocalAppData)
      - Directorio de instalacion Inno Setup en AppData\Roaming de todos los perfiles
        (patron: AutoClicker.exe + unins000.exe + unins000.dat)

    Salida:
      - Exit 1: Aplicacion detectada -> Intune lanza el script de Remediation
      - Exit 0: Dispositivo limpio -> no se requiere accion

.PARAMETER
    Ninguno.

.EXAMPLE
    Executes as Intune Detection Script.

.NOTES
    Name: Script Remediation - Desinstalar OP Auto Clicker - Detection.ps1
    Author: Alejandro Suarez (@alexsf93)
    Version: 1.1.0
    Date: 2026-06-24
    Context: System
#>

$OutputEncoding = [System.Text.Encoding]::UTF8

if ([Environment]::Is64BitOperatingSystem -and -not [Environment]::Is64BitProcess) {
    Write-Host "Ejecutando en proceso de 32 bits. Relanzando en PowerShell de 64 bits..."
    $powershell64 = Join-Path $env:SystemRoot "Sysnative\WindowsPowerShell\v1.0\powershell.exe"
    if (Test-Path $powershell64) {
        $arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`""
        Start-Process -FilePath $powershell64 -ArgumentList $arguments -Wait -NoNewWindow
        exit $LASTEXITCODE
    } else {
        Write-Host "No se pudo encontrar PowerShell de 64 bits en Sysnative. Continuando en modo actual."
    }
}

$detected = $false
$Reasons  = [System.Collections.Generic.List[string]]::new()

# Patrones de nombre de paquete AppX conocidos para OP Auto Clicker
$AppxNamePatterns = @(
    "*AutoClicker*",
    "*OPAutoClicker*",
    "*OP*AutoClicker*",
    "*AutoTap*"
)

# Patrones de DisplayName para busqueda en registro (standalone)
$DisplayNamePatterns = @(
    "*OP Auto Clicker*",
    "*OPAutoClicker*",
    "*Auto Clicker*Auto Tap*"
)

# Nombres de proceso relacionados
$ProcessPatterns = @(
    "opautoclicker*",
    "autoclicker*",
    "AutoTap*"
)

# =============================================================================
# 1. Paquetes AppX (todos los usuarios)
# =============================================================================
try {
    foreach ($pattern in $AppxNamePatterns) {
        $pkgs = Get-AppxPackage -AllUsers -Name $pattern -ErrorAction SilentlyContinue
        foreach ($pkg in $pkgs) {
            $detected = $true
            $Reasons.Add("Paquete AppX (todos los usuarios) detectado: $($pkg.PackageFullName)")
        }
    }
} catch {
    Write-Host "Advertencia al buscar paquetes AppX (AllUsers): $_"
}

# =============================================================================
# 2. Paquetes AppX provisionados (imagen del sistema)
# =============================================================================
try {
    foreach ($pattern in $AppxNamePatterns) {
        $provPkgs = Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue |
            Where-Object { $_.DisplayName -like $pattern }
        foreach ($pkg in $provPkgs) {
            $detected = $true
            $Reasons.Add("Paquete AppX provisionado detectado: $($pkg.PackageName)")
        }
    }
} catch {
    Write-Host "Advertencia al buscar paquetes provisionados: $_"
}

# =============================================================================
# 3. Procesos activos
# =============================================================================
foreach ($pattern in $ProcessPatterns) {
    $procs = Get-Process -Name $pattern -ErrorAction SilentlyContinue
    foreach ($proc in $procs) {
        $detected = $true
        $Reasons.Add("Proceso activo detectado: $($proc.Name) (PID: $($proc.Id))")
    }
}

# =============================================================================
# 4. Claves de registro Uninstall (instalacion standalone)
# =============================================================================
$UninstallPaths = @(
    "HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall",
    "HKLM:\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall",
    "HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall"
)
foreach ($basePath in $UninstallPaths) {
    if (-not (Test-Path $basePath)) { continue }
    try {
        Get-ChildItem -Path $basePath -ErrorAction SilentlyContinue | ForEach-Object {
            $displayName = $_.GetValue("DisplayName")
            foreach ($pattern in $DisplayNamePatterns) {
                if ($displayName -like $pattern) {
                    $detected = $true
                    $Reasons.Add("Clave Uninstall detectada: $basePath -> $($_.PSChildName) ($displayName)")
                }
            }
        }
    } catch {
        Write-Host "Advertencia al buscar en $basePath : $_"
    }
}

# =============================================================================
# 5. Directorio de instalacion standalone comun
# =============================================================================
$StandalonePaths = @(
    "$env:LOCALAPPDATA\Programs\OP Auto Clicker",
    "$env:ProgramFiles\OP Auto Clicker",
    "${env:ProgramFiles(x86)}\OP Auto Clicker"
)
foreach ($path in $StandalonePaths) {
    if (Test-Path $path -ErrorAction SilentlyContinue) {
        $detected = $true
        $Reasons.Add("Directorio standalone detectado: $path")
    }
}

# =============================================================================
# 5b. Instalacion Inno Setup en AppData\Roaming de todos los perfiles de usuario
#     (patron: %APPDATA%\OP Auto Clicker\AutoClicker.exe + unins000.exe)
# =============================================================================
Get-ChildItem -Path "C:\Users" -Directory -ErrorAction SilentlyContinue |
    Where-Object { $_.Name -notin @("All Users","Default","Default User","Public") } | ForEach-Object {
    $innoPath    = Join-Path $_.FullName "AppData\Roaming\OP Auto Clicker"
    $uninsExe    = Join-Path $innoPath "unins000.exe"
    $acExe       = Join-Path $innoPath "AutoClicker.exe"
    if ((Test-Path $innoPath -ErrorAction SilentlyContinue) -and
        ((Test-Path $uninsExe -ErrorAction SilentlyContinue) -or (Test-Path $acExe -ErrorAction SilentlyContinue))) {
        $detected = $true
        $Reasons.Add("Instalacion Inno Setup detectada en perfil '$($_.Name)': $innoPath")
    }
}

# =============================================================================
# Evaluacion final
# =============================================================================
if ($detected) {
    Write-Host "Detected: OP Auto Clicker encontrado en el sistema."
    foreach ($reason in $Reasons) { Write-Host " - $reason" }
    exit 1
} else {
    Write-Host "No se ha encontrado ninguna traza de OP Auto Clicker."
    exit 0
}
