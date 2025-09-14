<#
=====================================================================================================
    REMEDIATION SCRIPT: DESHABILITAR CUENTAS LOCALES "ADMINISTRADOR"/"ADMINISTRATOR"
-----------------------------------------------------------------------------------------------------
Este script deshabilita cualquier cuenta local llamada "Administrador" (ES) o "Administrator" (EN) 
si se encuentra habilitada, reforzando la seguridad del sistema contra accesos locales no controlados. 
Está pensado para ejecutarse en escenarios de hardening o como parte de políticas de seguridad 
automatizadas en Intune.

-----------------------------------------------------------------------------------------------------
REQUISITOS
-----------------------------------------------------------------------------------------------------
- Debe ejecutarse con privilegios de administrador o SYSTEM.
- Compatible con PowerShell 5.1 o superior.
- Requiere el módulo de cuentas locales (`Disable-LocalUser`).

-----------------------------------------------------------------------------------------------------
¿CÓMO FUNCIONA?
-----------------------------------------------------------------------------------------------------
- Busca cuentas locales llamadas "Administrador" y "Administrator".
- Comprueba si están habilitadas.
- Si alguna lo está, la deshabilita automáticamente.
- Si ya están deshabilitadas o no existen, no realiza cambios.

-----------------------------------------------------------------------------------------------------
RESULTADOS
-----------------------------------------------------------------------------------------------------
- "OK" (exit code 0 implícito) → Todas las cuentas están deshabilitadas o no existen.
- Mensajes en salida estándar → Se muestra el nombre de cada cuenta deshabilitada.

-----------------------------------------------------------------------------------------------------
INSTRUCCIONES DE USO
-----------------------------------------------------------------------------------------------------
- Ejecutar como Remediation Script en Intune o manualmente en PowerShell.
- Requiere privilegios de administrador local o SYSTEM.
- Revisar los mensajes de salida para confirmar acciones realizadas.

-----------------------------------------------------------------------------------------------------
AUTOR: Alejandro Suárez (@alexsf93)
=====================================================================================================
#>

$usuarios = @("Administrador", "Administrator")

foreach ($nombre in $usuarios) {
    $cuenta = Get-LocalUser -Name $nombre -ErrorAction SilentlyContinue
    if ($cuenta -and $cuenta.Enabled) {
        Disable-LocalUser -Name $nombre
        Write-Host "Cuenta '$nombre' deshabilitada."
    }
}
