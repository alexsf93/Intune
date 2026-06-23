<#
.SYNOPSIS
    DETECTION SCRIPT: DETECTAR LA APLICACION "PLAYSTATION ACCESSORIES"

.DESCRIPTION
    Este script comprueba si la aplicacion "PlayStation Accessories" de Sony esta instalada.
    Busca directorios de instalacion, procesos activos, claves Uninstall en HKLM/HKU,
    la base de datos de Windows Installer (Classes\Installer\Products, UserData)
    y carpetas de cache de InstallShield.

.PARAMETER
    Ninguno.

.EXAMPLE
    Executes as Intune Detection Script.

.NOTES
    Name: Script Remediation - Desinstalar PlayStation Accessories - Detection.ps1
    Author: Alejandro Suarez (@alexsf93)
    Version: 1.1.0
    Date: 2026-06-23
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
        Write-Host "No se pudo encontrar el ejecutable de PowerShell de 64 bits en Sysnative. Continuando en modo actual."
    }
}

$playStationDetected = $false
$Reasons = [System.Collections.Generic.List[string]]::new()

# GUID conocido del diagnostico
$KnownGuid     = "{A27B17B9-90C8-4B07-83C6-1303FC186B6B}"
$KnownSquished = "9B71B72A8C0970B4386C3130CF81B6B6"

Write-Host "Iniciando comprobacion de PlayStation Accessories..."

# --- Mapear HKU ---
if (-not (Get-PSDrive -Name HKU -ErrorAction SilentlyContinue)) {
    New-PSDrive -Name HKU -PSProvider Registry -Root HKEY_USERS -ErrorAction SilentlyContinue | Out-Null
}

$loadedUserSids = @()
if (Test-Path "HKU:\") {
    $loadedUserSids = Get-ChildItem -Path "HKU:\" -ErrorAction SilentlyContinue |
        Where-Object { $_.PSChildName -match "^S-1-5-21-\d+-\d+-\d+-\d+$" } |
        Select-Object -ExpandProperty PSChildName
}

# 1. Directorio de instalacion
$InstallationDir = "C:\Program Files\Sony\PlayStationAccessories"
if (Test-Path $InstallationDir) {
    $playStationDetected = $true
    $Reasons.Add("Directorio de instalacion detectado: $InstallationDir")
}

# 2. Procesos activos
$processes = Get-Process -Name "PlayStationAccessories*" -ErrorAction SilentlyContinue
if ($processes) {
    $playStationDetected = $true
    foreach ($proc in $processes) {
        $Reasons.Add("Proceso activo detectado: $($proc.Name) (PID: $($proc.Id))")
    }
}

# 3. Claves Uninstall (HKLM + HKU)
$UninstallPaths = @(
    "HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall",
    "HKLM:\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall"
)
foreach ($sid in $loadedUserSids) {
    $UninstallPaths += "HKU:\$sid\Software\Microsoft\Windows\CurrentVersion\Uninstall"
    $UninstallPaths += "HKU:\$sid\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall"
}
foreach ($basePath in $UninstallPaths) {
    if (-not (Test-Path $basePath)) { continue }
    Get-ChildItem -Path $basePath -ErrorAction SilentlyContinue | ForEach-Object {
        $name        = $_.PSChildName
        $displayName = $_.GetValue("DisplayName")
        if ($name -like "*PlayStationAccessories*" -or $name -like "*PlayStation Accessories*" -or
            $name -eq $KnownGuid -or
            $displayName -like "*PlayStationAccessories*" -or $displayName -like "*PlayStation*") {
            $playStationDetected = $true
            $Reasons.Add("Clave Uninstall detectada en $($basePath): $name")
        }
    }
}

# 4. Base de datos Windows Installer: Classes\Installer\Products
$classesProductsPath = "HKLM:\SOFTWARE\Classes\Installer\Products"
if (Test-Path $classesProductsPath) {
    Get-ChildItem -Path $classesProductsPath -ErrorAction SilentlyContinue | ForEach-Object {
        $productName = $_.GetValue("ProductName")
        if ($_.PSChildName -eq $KnownSquished -or
            $productName -like "*PlayStationAccessories*" -or $productName -like "*PlayStation*") {
            $playStationDetected = $true
            $Reasons.Add("Entrada en Classes\Installer\Products detectada: $($_.PSChildName) ($productName)")
        }
    }
}

# 5. Base de datos Windows Installer: UserData
$userDataPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Installer\UserData"
if (Test-Path $userDataPath) {
    Get-ChildItem -Path $userDataPath -ErrorAction SilentlyContinue | ForEach-Object {
        $sidKey       = $_.PSChildName
        $productsPath = "$userDataPath\$sidKey\Products"
        if (Test-Path $productsPath) {
            Get-ChildItem -Path $productsPath -ErrorAction SilentlyContinue | ForEach-Object {
                $installProp = "$productsPath\$($_.PSChildName)\InstallProperties"
                if (Test-Path $installProp) {
                    $dn = (Get-ItemProperty -Path $installProp -ErrorAction SilentlyContinue).DisplayName
                    if ($dn -like "*PlayStationAccessories*" -or $dn -like "*PlayStation Accessories*") {
                        $playStationDetected = $true
                        $Reasons.Add("Entrada en UserData\$sidKey\Products detectada: $($_.PSChildName) ($dn)")
                    }
                }
            }
        }
    }
}

# 6. HKU\*\Software\Microsoft\Installer\Products
foreach ($sid in $loadedUserSids) {
    $hkuInstallerPath = "HKU:\$sid\Software\Microsoft\Installer\Products"
    if (Test-Path $hkuInstallerPath) {
        Get-ChildItem -Path $hkuInstallerPath -ErrorAction SilentlyContinue | ForEach-Object {
            $productName = $_.GetValue("ProductName")
            if ($productName -like "*PlayStationAccessories*" -or $productName -like "*PlayStation Accessories*") {
                $playStationDetected = $true
                $Reasons.Add("Entrada en HKU\$sid\...\Installer\Products detectada: $($_.PSChildName) ($productName)")
            }
        }
    }
}

# 7. Carpetas de cache de InstallShield
@("C:\Program Files (x86)\InstallShield Installation Information","C:\Program Files\InstallShield Installation Information") | ForEach-Object {
    if (-not (Test-Path $_)) { return }
    Get-ChildItem -Path $_ -Directory -Force -ErrorAction SilentlyContinue | ForEach-Object {
        $iniPath = Join-Path $_.FullName "setup.ini"
        if (Test-Path $iniPath) {
            $iniContent = Get-Content -Path $iniPath -ErrorAction SilentlyContinue
            if ($iniContent -like "*PlayStationAccessories*" -or $iniContent -like "*PlayStation Accessories*") {
                $playStationDetected = $true
                $Reasons.Add("Cache de InstallShield detectada: $($_.FullName)")
            }
        }
    }
}

# --- Evaluacion final ---
if ($playStationDetected) {
    Write-Host "Aplicacion detectada:"
    foreach ($reason in $Reasons) { Write-Host " - $reason" }
    exit 1
} else {
    Write-Host "No se ha encontrado ninguna traza de PlayStation Accessories."
    exit 0
}
