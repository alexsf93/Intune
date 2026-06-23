<#
.SYNOPSIS
    REMEDIATION SCRIPT: LIMPIAR MOTOR POLICYMANAGER Y RECREAR CLAVES DE AUTOPATCH

.DESCRIPTION
    Este script elimina la clave de registro corrupta o bloqueada HKLM:\SOFTWARE\Microsoft\PolicyManager\current\device\Update
    y seguidamente fuerza una sincronización MDM con Intune a través de la tarea programada PushLaunch para recrear
    la configuración limpia de Windows Autopatch.

.PARAMETER
    Ninguno.

.EXAMPLE
    Executes as Intune Remediation Script.

.NOTES
    Name: Script Remediation - Windows Autopatch PolicyManager Deadlines - Remediation.ps1
    Author: Alejandro Suárez (@alexsf93)
    Version: 1.0.0
    Date: 2026-06-23
    Context: System
#>

# Forzar el uso de codificación UTF-8
$OutputEncoding = [System.Text.Encoding]::UTF8

# 1. Asegurar entorno de ejecución de 64 bits para evitar redirecciones de registro (WOW6432Node)
if ([Environment]::Is64BitOperatingSystem -and -not [Environment]::Is64BitProcess) {
    Write-Host "Ejecutando en proceso de 32 bits en SO de 64 bits. Relanzando en PowerShell de 64 bits..."
    $powershell64 = Join-Path $env:SystemRoot "Sysnative\WindowsPowerShell\v1.0\powershell.exe"
    if (Test-Path $powershell64) {
        $arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`""
        Start-Process -FilePath $powershell64 -ArgumentList $arguments -Wait -NoNewWindow
        exit $LASTEXITCODE
    } else {
        Write-Warning "No se pudo encontrar el ejecutable de PowerShell de 64 bits en Sysnative. Continuando en modo actual..."
    }
}

$RegistryPath = "HKLM:\SOFTWARE\Microsoft\PolicyManager\current\device\Update"

Write-Host "Iniciando remediación de PolicyManager para Windows Autopatch..."

# 2. Eliminación segura y recursiva de la subclave Update
if (Test-Path -Path $RegistryPath -ErrorAction SilentlyContinue) {
    Write-Host "Detectada la subclave 'Update'. Intentando eliminarla de forma recursiva..."
    try {
        # Eliminar recursivamente y con fuerza la subclave
        Remove-Item -Path $RegistryPath -Recurse -Force -ErrorAction Stop
        Write-Host "Subclave 'Update' eliminada correctamente."
    }
    catch {
        Write-Host "ERROR CRÍTICO: No se pudo eliminar la clave de registro debido a un bloqueo o falta de permisos: $_"
        Write-Host "Remediación abortada debido a fallo en la limpieza del registro."
        Exit 1
    }
} else {
    Write-Host "La subclave 'Update' no existe. No se requiere limpieza previa."
}

# 3. Forzar sincronización MDM inmediata
Write-Host "Forzando sincronización MDM con Intune para recrear la configuración..."
$syncTriggered = $false

try {
    # Buscar dinámicamente la tarea scheduled 'PushLaunch' dentro del path de EnterpriseMgmt
    $tasks = Get-ScheduledTask -ErrorAction SilentlyContinue | Where-Object { $_.TaskPath -like "*EnterpriseMgmt*" -and $_.TaskName -eq "PushLaunch" }
    
    if ($tasks) {
        foreach ($task in $tasks) {
            Write-Host "Ejecutando tarea programada: $($task.TaskPath)$($task.TaskName)"
            Start-ScheduledTask -InputObject $task -ErrorAction Stop
            $syncTriggered = $true
        }
        Write-Host "Sincronización MDM iniciada con éxito a través de PushLaunch."
    } else {
        Write-Warning "No se localizó la tarea programada PushLaunch bajo Microsoft\Windows\EnterpriseMgmt."
    }
}
catch {
    Write-Host "Advertencia al intentar iniciar la tarea PushLaunch: $_"
}

# Fallback en caso de que PushLaunch no se haya podido iniciar o no exista
if (-not $syncTriggered) {
    Write-Host "Intentando forzar la sincronización usando deviceenroller.exe como fallback..."
    try {
        # Ejecutar deviceenroller para la sincronización MDM
        Start-Process -FilePath "$env:SystemRoot\System32\deviceenroller.exe" -ArgumentList "/c /mobileenrollment" -Wait -NoNewWindow -ErrorAction Stop
        Write-Host "Sincronización MDM iniciada con deviceenroller.exe."
    }
    catch {
        Write-Host "ERROR: Tampoco se pudo iniciar la sincronización mediante deviceenroller.exe: $_"
        Exit 1
    }
}

Write-Host "Remediación finalizada de manera conforme."
Exit 0
