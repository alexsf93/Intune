<#
.SYNOPSIS
    DETECTION SCRIPT: INICIO AUTOMÁTICO Y CONFIGURACIÓN DE ONEDRIVE (M365 / ENTERPRISE)

.DESCRIPTION
    Este script verifica si Microsoft OneDrive está configurado para iniciarse automáticamente
    con Windows y si la política de configuración de cuenta silenciosa (SilentAccountConfig)
    está habilitada para entornos corporativos/M365.
    Comprueba tanto los registros de Run (HKLM/HKCU) como el estado de activación en el Administrador de Tareas.

.PARAMETER
    Ninguno.

.EXAMPLE
    Executes as Intune Detection Script.

.NOTES
    Name: Script Remediation - Onedrive Startup - Detection.ps1
    Author: Alejandro Suárez (@alexsf93)
    Version: 1.1.0
    Date: 2026-06-21
    Context: User (o System)
#>

# 1. Comprobar si OneDrive está instalado (soporta instalación de usuario y de máquina/M365)
$OneDrivePaths = @(
    "${env:ProgramFiles}\Microsoft OneDrive\OneDrive.exe",
    "${env:ProgramFiles(x86)}\Microsoft OneDrive\OneDrive.exe",
    "$env:LOCALAPPDATA\Microsoft\OneDrive\OneDrive.exe"
)

$InstalledPath = $null
foreach ($path in $OneDrivePaths) {
    if (Test-Path $path) {
        $InstalledPath = $path
        break
    }
}

if ($null -eq $InstalledPath) {
    Write-Output "OneDrive no está instalado en este dispositivo. No requiere remediación."
    exit 0
}

# Determinar contexto de ejecución (SYSTEM o Usuario)
$isSystem = ([Security.Principal.WindowsIdentity]::GetCurrent().Name -match "SYSTEM")
Write-Output "Contexto de ejecución: $(if ($isSystem) { 'SYSTEM' } else { 'Usuario' })"

# 2. Verificar si está registrado en el inicio automático (Run Key)
$runValueName = "OneDrive"
$isConfigured = $false

$runPaths = @(
    "HKLM:\Software\Microsoft\Windows\CurrentVersion\Run",
    "HKLM:\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Run",
    "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run"
)

foreach ($runPath in $runPaths) {
    if (Test-Path $runPath) {
        $runValue = Get-ItemProperty -Path $runPath -Name $runValueName -ErrorAction SilentlyContinue
        if ($runValue -and $runValue.OneDrive) {
            if ($runValue.OneDrive -match "OneDrive\.exe") {
                $isConfigured = $true
                Write-Output "Encontrado registro de inicio en: $runPath"
                break
            }
        }
    }
}

# 3. Verificar si el usuario ha deshabilitado el inicio automático en el Administrador de Tareas
$isEnabled = $true
$startupApprovedPaths = @(
    "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\Run",
    "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\Run32"
)

foreach ($approvedPath in $startupApprovedPaths) {
    if (Test-Path $approvedPath) {
        $approvedValue = Get-ItemProperty -Path $approvedPath -Name $runValueName -ErrorAction SilentlyContinue
        if ($approvedValue -and $approvedValue.OneDrive) {
            $bytes = $approvedValue.OneDrive
            if ($bytes -and $bytes.Length -gt 0 -and $bytes[0] -ne 0x02) {
                $isEnabled = $false
                Write-Output "OneDrive está marcado como deshabilitado en: $approvedPath"
            }
        }
    }
}

# 4. Verificar configuración corporativa / M365 (SilentAccountConfig)
# Esto asegura que OneDrive no solo se inicie, sino que inicie sesión de manera silenciosa con la cuenta de M365/Entra ID.
$policyValueName = "SilentAccountConfig"
$isSilentConfigured = $false

$policyPaths = @(
    "HKLM:\SOFTWARE\Policies\Microsoft\OneDrive",
    "HKCU:\SOFTWARE\Policies\Microsoft\OneDrive"
)

foreach ($policyPath in $policyPaths) {
    if (Test-Path $policyPath) {
        $policyValue = Get-ItemProperty -Path $policyPath -Name $policyValueName -ErrorAction SilentlyContinue
        if ($policyValue -and $policyValue.SilentAccountConfig -eq 1) {
            $isSilentConfigured = $true
            Write-Output "Política SilentAccountConfig habilitada en: $policyPath"
            break
        }
    }
}

# 5. Evaluación del estado de conformidad
if ($isConfigured -and $isEnabled -and $isSilentConfigured) {
    Write-Output "OneDrive y la política SilentAccountConfig están configurados correctamente."
    exit 0 # Cumple / Conforme
}
else {
    if (-not $isConfigured) {
        Write-Output "OneDrive no está registrado en ninguna de las claves Run de inicio automático."
    }
    if (-not $isEnabled) {
        Write-Output "OneDrive está deshabilitado por el usuario en el Administrador de Tareas."
    }
    if (-not $isSilentConfigured) {
        Write-Output "La política SilentAccountConfig (inicio de sesión silencioso M365) no está configurada."
    }
    exit 1 # No cumple / Requiere remediación
}
