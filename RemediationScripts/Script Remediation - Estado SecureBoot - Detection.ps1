<#
=====================================================================================================
    DETECTION SCRIPT: COMPROBACIÓN DE SECURE BOOT Y REGISTRO EN LOG LOCAL
-----------------------------------------------------------------------------------------------------
Este script verifica si Secure Boot está habilitado en el equipo.  
Si está deshabilitado, añade un mensaje de alerta con fecha y nombre del equipo en un archivo 
de log ubicado en `C:\ProgramData\IntuneLogs\SecureBootCheck.log`.  

Está pensado para auditoría y compliance en entornos gestionados, compatible con Intune.

-----------------------------------------------------------------------------------------------------
REQUISITOS
-----------------------------------------------------------------------------------------------------
- Compatible con PowerShell 5.1 y 7.x.
- Debe ejecutarse en equipos con firmware UEFI.
- Requiere permisos para crear carpetas y archivos en `C:\ProgramData`.

-----------------------------------------------------------------------------------------------------
¿CÓMO FUNCIONA?
-----------------------------------------------------------------------------------------------------
- Comprueba el estado de Secure Boot mediante `Confirm-SecureBootUEFI`.
- Si Secure Boot está deshabilitado:
  * Genera un log con marca de tiempo y nombre del equipo.
  * Escribe la alerta en `C:\ProgramData\IntuneLogs\SecureBootCheck.log`.
- Devuelve siempre exit code 0 para evitar que el script falle en Intune.

-----------------------------------------------------------------------------------------------------
RESULTADOS
-----------------------------------------------------------------------------------------------------
- "OK" (exit code 0) → Secure Boot habilitado o log actualizado si está deshabilitado.
- Log local → Contiene una entrada por cada detección de Secure Boot deshabilitado.

-----------------------------------------------------------------------------------------------------
INSTRUCCIONES DE USO
-----------------------------------------------------------------------------------------------------
- Ejecutar como Detection Rule en Intune o como script de auditoría.
- Revisar el archivo de log en `C:\ProgramData\IntuneLogs\SecureBootCheck.log` para identificar equipos afectados.
- El script no modifica el código de salida (siempre `0`).

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
