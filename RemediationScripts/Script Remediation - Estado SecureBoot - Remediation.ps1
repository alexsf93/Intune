<#
=====================================================================================================
    REMEDIACIÓN: REGISTRO DE ALERTA SI SECURE BOOT ESTÁ DESHABILITADO
-----------------------------------------------------------------------------------------------------
Este script verifica si Secure Boot está habilitado en el equipo. Si está deshabilitado, registra una alerta
con fecha y nombre del equipo en un archivo de log ubicado en
C:\ProgramData\IntuneLogs\SecureBootCheck.log.

Pensado para usarse como remediación en Intune u otros sistemas de gestión para auditoría y seguimiento.

-----------------------------------------------------------------------------------------------------
INSTRUCCIONES DE USO
-----------------------------------------------------------------------------------------------------
- Ejecuta este script como remediación en Intune o scripts de usuario.
- Requiere permisos para crear archivos y carpetas en C:\ProgramData.
- Siempre devuelve código de salida `0` para evitar fallos en la ejecución.

-----------------------------------------------------------------------------------------------------
AUTOR: Alejandro Suárez (@alexsf93)
=====================================================================================================
#>

$logPath = "C:\ProgramData\IntuneLogs"
$logFile = Join-Path $logPath "SecureBootCheck.log"

# Crear carpeta si no existe
if (-not (Test-Path $logPath)) {
    New-Item -Path $logPath -ItemType Directory -Force | Out-Null
}

try {
    $secureBootEnabled = Confirm-SecureBootUEFI
} catch {
    $secureBootEnabled = $false
}

if (-not $secureBootEnabled) {
    $message = "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - ALERT: Secure Boot DESHABILITADO en $env:COMPUTERNAME"
    Add-Content -Path $logFile -Value $message
}

exit 0
