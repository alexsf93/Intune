<#
.SYNOPSIS
    REMEDIATION SCRIPT: DESHABILITAR CUENTAS LOCALES "ADMINISTRADOR"/"ADMINISTRATOR"

.DESCRIPTION
    Este script deshabilita cualquier cuenta local llamada "Administrador" (ES) o "Administrator" (EN) 
    si se encuentra habilitada, reforzando la seguridad del sistema contra accesos locales no controlados.

.PARAMETER
    Ninguno.

.EXAMPLE
    Executes as Intune Remediation Script.

.NOTES
    Name: Script Remediation - Deshabilitar Administrator o Administrador - Remediation.ps1
    Author: Alejandro Suárez (@alexsf93)
    Version: 1.0.0
    Date: 2026-01-21
    Context: System
#>

# Deshabilitar la cuenta de administrador integrada por SID (RID 500)
$builtInAdmin = Get-LocalUser | Where-Object { $_.SID.Value -match '-500$' }
if ($builtInAdmin -and $builtInAdmin.Enabled) {
    Disable-LocalUser -Name $builtInAdmin.Name
    Write-Host "Cuenta '$($builtInAdmin.Name)' (RID 500) deshabilitada."
}
