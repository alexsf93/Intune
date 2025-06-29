<#
===============================================================================================
       DETECCIÓN: CUENTAS LOCALES "ADMINISTRADOR" O "ADMINISTRATOR" HABILITADAS - POWERSHELL
-----------------------------------------------------------------------------------------------
Este script detecta si existen cuentas locales con nombre "Administrador" o "Administrator"
y si alguna de ellas está habilitada en el sistema.  
Pensado para tareas de compliance, hardening y remediación automatizada (Intune compatible).

-----------------------------------------------------------------------------------------------
¿CÓMO FUNCIONA?
-----------------------------------------------------------------------------------------------
- Busca cuentas locales llamadas exactamente "Administrador" (ES) o "Administrator" (EN).
- Si alguna está habilitada (Enabled: True), el script devuelve Exit 1.
- Si no existen o todas están deshabilitadas, devuelve Exit 0.

-----------------------------------------------------------------------------------------------
INSTRUCCIONES DE USO
-----------------------------------------------------------------------------------------------
- Usa este script como Detection Rule en Intune Remediations, o en auditorías de seguridad.

-----------------------------------------------------------------------------------------------
AUTOR
-----------------------------------------------------------------------------------------------
- Alejandro Suárez (@alexsf93)
===============================================================================================
#>

$usuarios = @("Administrador", "Administrator")
$habilitada = $false

foreach ($nombre in $usuarios) {
    $cuenta = Get-LocalUser -Name $nombre -ErrorAction SilentlyContinue
    if ($cuenta -and $cuenta.Enabled) {
        $habilitada = $true
        break
    }
}

if ($habilitada) {
    Exit 1   # Alguna cuenta está habilitada (requiere remediar)
} else {
    Exit 0   # Todas deshabilitadas o no existen (OK)
}
