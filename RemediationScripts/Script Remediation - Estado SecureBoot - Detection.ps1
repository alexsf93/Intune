<#
.SYNOPSIS
    DETECTION SCRIPT: COMPROBACIÓN DE SECURE BOOT Y REGISTRO EN LOG LOCAL

.DESCRIPTION
    Este script verifica si Secure Boot está habilitado en el equipo.  
    Si está deshabilitado, añade un mensaje de alerta con fecha y nombre del equipo en un archivo 
    de log ubicado en `C:\ProgramData\IntuneLogs\SecureBootCheck.log`.

.PARAMETER
    Ninguno.

.EXAMPLE
    Executes as Intune Detection Script.

.NOTES
    Name: Script Remediation - Estado SecureBoot - Detection.ps1
    Author: Alejandro Suárez (@alexsf93)
    Version: 1.0.0
    Date: 2026-01-21
    Context: System
#>

$logPath = "C:\ProgramData\IntuneLogs"
$logFile = Join-Path $logPath "SecureBootCheck.log"

# Crear carpeta si no existe
if (-not (Test-Path $logPath)) {
    New-Item -Path $logPath -ItemType Directory -Force | Out-Null
}

try {
    $secureBootEnabled = Confirm-SecureBootUEFI
}
catch {
    $secureBootEnabled = $false
}

if (-not $secureBootEnabled) {
    $message = "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - ALERT: Secure Boot DESHABILITADO en $env:COMPUTERNAME"
    Add-Content -Path $logFile -Value $message
}

exit 0
