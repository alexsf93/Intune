<#
=====================================================================================================
    REGLA DE DETECCIÓN Y LOGGING - COMPROBACIÓN DE SECURE BOOT Y REGISTRO EN LOG LOCAL
-----------------------------------------------------------------------------------------------------
Este script verifica si Secure Boot está habilitado en el equipo. Si está deshabilitado, añade un
mensaje de alerta con fecha y nombre del equipo en un archivo de log ubicado en
C:\ProgramData\IntuneLogs\SecureBootCheck.log.

Pensado para auditoría y compliance en entornos gestionados, compatible con Intune.

-----------------------------------------------------------------------------------------------------
INSTRUCCIONES DE USO
-----------------------------------------------------------------------------------------------------
- Ejecuta este script como Detection Rule o script de usuario en Intune u otros sistemas.
- Requiere permisos para crear archivos y carpetas en C:\ProgramData.
- No modifica el código de salida (siempre `0`) para evitar fallos en la ejecución.

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
