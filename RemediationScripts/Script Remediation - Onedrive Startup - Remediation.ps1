<#
.SYNOPSIS
    REMEDIATION SCRIPT: INICIO AUTOMÁTICO Y CONFIGURACIÓN DE ONEDRIVE (M365 / ENTERPRISE)

.DESCRIPTION
    Este script configura Microsoft OneDrive para iniciarse automáticamente con Windows.
    Asegura que exista el registro de inicio en la clave Run (HKLM para SYSTEM o HKCU para Usuario),
    remueve bloqueos de StartupApproved y activa la política SilentAccountConfig para el inicio de sesión silencioso M365.

.PARAMETER
    Ninguno.

.EXAMPLE
    Executes as Intune Remediation Script.

.NOTES
    Name: Script Remediation - Onedrive Startup - Remediation.ps1
    Author: Alejandro Suárez (@alexsf93)
    Version: 1.1.1
    Date: 2026-06-21
    Context: User
#>

# 1. Comprobar si OneDrive está instalado
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
    Write-Output "OneDrive no está instalado en este dispositivo. No es posible remediar."
    exit 0
}

# Determinar contexto de ejecución
$isSystem = ([Security.Principal.WindowsIdentity]::GetCurrent().Name -match "SYSTEM")
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

try {
    # 2. Configurar la clave de registro de inicio automático (Run Key)
    # Si somos SYSTEM o Administrador, preferimos escribir en HKLM (afecta a todos los usuarios del dispositivo).
    # Si somos un usuario estándar, escribimos en HKCU.
    if ($isSystem -or $isAdmin) {
        $runKeyPath = "HKLM:\Software\Microsoft\Windows\CurrentVersion\Run"
        Write-Output "Ejecutando como Administrador/SYSTEM. Se configurará el inicio automático en HKLM."
    }
    else {
        $runKeyPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run"
        Write-Output "Ejecutando como Usuario estándar. Se configurará el inicio automático en HKCU."
    }

    $runValueName = "OneDrive"
    $targetValue = "`"$InstalledPath`" /background"

    if (-not (Test-Path $runKeyPath)) {
        New-Item -Path $runKeyPath -Force | Out-Null
    }
    Set-ItemProperty -Path $runKeyPath -Name $runValueName -Value $targetValue -Type String -Force
    Write-Output "Se ha configurado el inicio automático en '$runKeyPath' con valor '$targetValue'."

    # 3. Eliminar cualquier deshabilitación en el Administrador de Tareas (StartupApproved) para el usuario actual
    $startupApprovedPaths = @(
        "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\Run",
        "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\Run32"
    )

    foreach ($approvedPath in $startupApprovedPaths) {
        if (Test-Path $approvedPath) {
            $approvedValue = Get-ItemProperty -Path $approvedPath -Name $runValueName -ErrorAction SilentlyContinue
            if ($approvedValue) {
                Remove-ItemProperty -Path $approvedPath -Name $runValueName -Force -ErrorAction SilentlyContinue
                Write-Output "Se ha eliminado la restricción de inicio en '$approvedPath'."
            }
        }
    }

    # 4. Habilitar la política SilentAccountConfig (inicio de sesión automático M365)
    # Habilitamos tanto en HKLM (si somos administradores) como en HKCU para asegurar la configuración corporativa.
    $policyValueName = "SilentAccountConfig"
    
    if ($isSystem -or $isAdmin) {
        $policyPaths = @(
            "HKLM:\SOFTWARE\Policies\Microsoft\OneDrive",
            "HKCU:\SOFTWARE\Policies\Microsoft\OneDrive"
        )
    }
    else {
        $policyPaths = @("HKCU:\SOFTWARE\Policies\Microsoft\OneDrive")
    }

    foreach ($policyPath in $policyPaths) {
        try {
            if (-not (Test-Path $policyPath)) {
                New-Item -Path $policyPath -Force -ErrorAction Stop | Out-Null
            }
            Set-ItemProperty -Path $policyPath -Name $policyValueName -Value 1 -Type DWord -Force -ErrorAction Stop
            Write-Output "Se ha habilitado la política SilentAccountConfig en '$policyPath'."
        }
        catch {
            Write-Warning "No se pudo configurar la política SilentAccountConfig en '$policyPath' (requiere privilegios elevados/directivas de grupo): $_"
        }
    }

    Write-Output "Remediación corporativa de OneDrive completada con éxito."
    exit 0
}
catch {
    Write-Error "Error al aplicar la remediación corporativa: $_"
    exit 1
}
