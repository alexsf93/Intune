<#
=====================================================================================================
    DETECTION SCRIPT: CUENTAS LOCALES "ADMINISTRADOR" O "ADMINISTRATOR" HABILITADAS
-----------------------------------------------------------------------------------------------------
Este script detecta si existen cuentas locales con nombre "Administrador" o "Administrator" y 
comprueba si alguna de ellas está habilitada en el sistema. Está pensado para tareas de compliance, 
hardening y remediación automatizada (compatible con Intune).

-----------------------------------------------------------------------------------------------------
REQUISITOS
-----------------------------------------------------------------------------------------------------
- Debe ejecutarse con permisos SYSTEM o privilegios de administrador local.
- Compatible con PowerShell 5.1 o superior.
- Requiere el módulo de cuentas locales (`Get-LocalUser`).

-----------------------------------------------------------------------------------------------------
¿CÓMO FUNCIONA?
-----------------------------------------------------------------------------------------------------
- Busca cuentas locales llamadas exactamente "Administrador" (ES) o "Administrator" (EN).
- Evalúa el estado de la propiedad Enabled.
- Devuelve:
  * Exit code 1 → Alguna cuenta está habilitada.
  * Exit code 0 → No existen o todas están deshabilitadas.

-----------------------------------------------------------------------------------------------------
RESULTADOS
-----------------------------------------------------------------------------------------------------
- "OK" (exit code 0) → Todas las cuentas "Administrador"/"Administrator" están deshabilitadas o no existen.
- "NOK" (exit code 1) → Alguna cuenta "Administrador"/"Administrator" está habilitada.

-----------------------------------------------------------------------------------------------------
INSTRUCCIONES DE USO
-----------------------------------------------------------------------------------------------------
- Usar como Detection Rule en Intune Remediations o auditorías de seguridad.
- Interpretar exit codes para aplicar el script de remediación correspondiente.

-----------------------------------------------------------------------------------------------------
AUTOR: Alejandro Suárez (@alexsf93)
=====================================================================================================
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
