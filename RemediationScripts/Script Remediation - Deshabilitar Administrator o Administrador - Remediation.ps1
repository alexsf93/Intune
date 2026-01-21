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
#>

$usuarios = @("Administrador", "Administrator")

foreach ($nombre in $usuarios) {
    $cuenta = Get-LocalUser -Name $nombre -ErrorAction SilentlyContinue
    if ($cuenta -and $cuenta.Enabled) {
        Disable-LocalUser -Name $nombre
        Write-Host "Cuenta '$nombre' deshabilitada."
    }
}
