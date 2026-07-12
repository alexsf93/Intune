<#
.SYNOPSIS
    DETECTION SCRIPT: CUENTAS LOCALES "ADMINISTRADOR" O "ADMINISTRATOR" HABILITADAS

.DESCRIPTION
    Este script detecta si existen cuentas locales con nombre "Administrador" o "Administrator" y 
    comprueba si alguna de ellas está habilitada en el sistema.

.PARAMETER
    Ninguno.

.EXAMPLE
    Executes as Intune Detection Script.

.NOTES
    Name: Script Remediation - Deshabilitar Administrator o Administrador - Detection.ps1
    Author: Alejandro Suárez (@alexsf93)
    Version: 1.0.0
    Date: 2026-01-21
    Context: System
#>

# Buscar la cuenta de administrador integrada por SID (RID 500)
$builtInAdmin = Get-LocalUser | Where-Object { $_.SID.Value -match '-500$' }

if ($builtInAdmin -and $builtInAdmin.Enabled) {
    Exit 1   # La cuenta de administrador integrada está habilitada (requiere remediar)
}
else {
    Exit 0   # Deshabilitada o no existe (OK)
}
