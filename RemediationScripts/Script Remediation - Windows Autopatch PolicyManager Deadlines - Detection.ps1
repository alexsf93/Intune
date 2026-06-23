<#
.SYNOPSIS
    DETECTION SCRIPT: VALIDAR MOTOR POLICYMANAGER (DEADLINES DE WINDOWS AUTOPATCH)

.DESCRIPTION
    Este script detecta si existen inconsistencias, valores faltantes o corrupción/bloqueo en las claves de
    configuración de plazos (deadlines) dentro de PolicyManager, específicamente en la ruta:
    HKLM:\SOFTWARE\Microsoft\PolicyManager\current\device\Update.

.PARAMETER
    Ninguno.

.EXAMPLE
    Executes as Intune Detection Script.

.NOTES
    Name: Script Remediation - Windows Autopatch PolicyManager Deadlines - Detection.ps1
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
$RequiredValues = @("ConfigureDeadlineForQualityUpdates", "UpdateNotificationLevel", "ConfigureDeadlineGracePeriod")

Write-Host "Iniciando detección del estado de PolicyManager para Windows Autopatch..."
Write-Host "Ruta a evaluar: $RegistryPath"

# 2. Comprobar si la ruta de registro existe y es accesible
if (-not (Test-Path -Path $RegistryPath -ErrorAction SilentlyContinue)) {
    Write-Host "PROBLEMA: La ruta de registro no existe o no es accesible. Autopatch podría no estar configurado correctamente o la clave está corrupta."
    Exit 1
}

# 3. Validar consistencia y lectura de los valores
$corruptedOrMissing = $false

try {
    foreach ($valueName in $RequiredValues) {
        # Intentar obtener la propiedad
        $val = Get-ItemProperty -Path $RegistryPath -Name $valueName -ErrorAction Stop
        if ($null -eq $val -or -not $val.PSObject.Properties[$valueName]) {
            Write-Host "PROBLEMA: Falta el valor crítico o no es accesible: $valueName"
            $corruptedOrMissing = $true
        } else {
            $valueData = $val.$valueName
            Write-Host "Valor detectado: $valueName = $valueData"
        }
    }
}
catch {
    Write-Host "ERROR: Se produjo una excepción al intentar acceder a la clave de registro: $_"
    Write-Host "Esto indica una posible corrupción o bloqueo del motor PolicyManager local."
    $corruptedOrMissing = $true
}

if ($corruptedOrMissing) {
    Write-Host "ESTADO: No conforme. Se detectaron inconsistencias, valores faltantes o corrupción. Activando remediación."
    Exit 1
} else {
    Write-Host "ESTADO: Conforme. PolicyManager contiene las directivas requeridas y es accesible."
    Exit 0
}
