<#
=====================================================================================================
    REMEDIATION SCRIPT: REGISTRO DE ALERTA SI SECURE BOOT ESTÁ DESHABILITADO
-----------------------------------------------------------------------------------------------------
Este script verifica si Secure Boot está habilitado en el equipo.  
Si está deshabilitado, registra una alerta con fecha y nombre del equipo en un archivo de log 
ubicado en `C:\ProgramData\IntuneLogs\SecureBootCheck.log`.  

Está pensado para usarse como remediación en Intune u otros sistemas de gestión para auditoría 
y seguimiento de cumplimiento.

-----------------------------------------------------------------------------------------------------
REQUISITOS
-----------------------------------------------------------------------------------------------------
- Compatible con PowerShell 5.1 y 7.x.
- Debe ejecutarse en equipos con firmware UEFI.
- Requiere permisos para crear carpetas y archivos en `C:\ProgramData`.

-----------------------------------------------------------------------------------------------------
¿CÓMO FUNCIONA?
-----------------------------------------------------------------------------------------------------
- Comprueba el estado de Secure Boot con `Confirm-SecureBootUEFI`.
- Si está deshabilitado:
  * Crea (si no existe) la carpeta `C:\ProgramData\IntuneLogs`.
  * Añade una entrada en `SecureBootCheck.log` con fecha, hora y nombre del equipo.
- Siempre devuelve exit code 0 para no interrumpir la ejecución en Intune.

-----------------------------------------------------------------------------------------------------
RESULTADOS
-----------------------------------------------------------------------------------------------------
- "OK" (exit code 0) → Secure Boot habilitado o log actualizado si está deshabilitado.
- Log local → Contiene una línea de alerta por cada vez que se detecta Secure Boot deshabilitado.

-----------------------------------------------------------------------------------------------------
INSTRUCCIONES DE USO
-----------------------------------------------------------------------------------------------------
- Ejecutar como Remediation Script en Intune u otros sistemas de gestión.
- Revisar el log en `C:\ProgramData\IntuneLogs\SecureBootCheck.log` para identificar equipos afectados.
- El script es silencioso y no muestra mensajes en pantalla.

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
