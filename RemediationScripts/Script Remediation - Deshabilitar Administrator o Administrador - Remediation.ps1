<#
===============================================================================================
      REMEDIACIÓN: DESHABILITAR CUENTAS "ADMINISTRADOR"/"ADMINISTRATOR" LOCALES - POWERSHELL
-----------------------------------------------------------------------------------------------
Este script deshabilita cualquier cuenta local llamada "Administrador" (ES) o "Administrator" (EN)
si están habilitadas, reforzando la seguridad del sistema contra accesos locales no controlados.

-----------------------------------------------------------------------------------------------
¿CÓMO FUNCIONA?
-----------------------------------------------------------------------------------------------
- Busca cuentas locales llamadas "Administrador" y "Administrator".
- Si existen y están habilitadas, las deshabilita automáticamente.
- Si ya están deshabilitadas o no existen, no realiza cambios.

-----------------------------------------------------------------------------------------------
INSTRUCCIONES DE USO
-----------------------------------------------------------------------------------------------
- Ejecuta el script como Remediation Script en Intune, o manualmente en PowerShell.
- **Requiere privilegios de administrador.**

-----------------------------------------------------------------------------------------------
AUTOR
-----------------------------------------------------------------------------------------------
- Alejandro Suárez (@alexsf93)
===============================================================================================
#>

$usuarios = @("Administrador", "Administrator")

foreach ($nombre in $usuarios) {
    $cuenta = Get-LocalUser -Name $nombre -ErrorAction SilentlyContinue
    if ($cuenta -and $cuenta.Enabled) {
        Disable-LocalUser -Name $nombre
        Write-Host "Cuenta '$nombre' deshabilitada."
    }
}
