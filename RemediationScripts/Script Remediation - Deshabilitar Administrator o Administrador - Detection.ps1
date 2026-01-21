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
}
else {
    Exit 0   # Todas deshabilitadas o no existen (OK)
}
