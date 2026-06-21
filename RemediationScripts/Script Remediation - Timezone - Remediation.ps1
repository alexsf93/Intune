<#
.SYNOPSIS
    REMEDIATION SCRIPT: ZONA HORARIA MADRID Y SINCRONIZACIÓN DE HORA (INTUNE)

.DESCRIPTION
    Este script configura la zona horaria de Madrid ("Romance Standard Time"), asegura que el servicio
    de hora de Windows esté en inicio automático y en ejecución, y fuerza una sincronización de hora.

.PARAMETER
    Ninguno.

.EXAMPLE
    Executes as Intune Remediation Script.

.NOTES
    Name: Script Remediation - Timezone - Remediation.ps1
    Author: Alejandro Suárez (@alexsf93)
    Version: 1.0.0
    Date: 2026-01-21
    Context: System
#>

# Comprobar si el script tiene permisos de administrador/SYSTEM
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).
IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")
if (-not $isAdmin) {
    Write-Output "El script necesita ejecutarse con privilegios de administrador o como SYSTEM."
    exit 1
}

# Establecer zona horaria de Madrid
Set-TimeZone -Id "Romance Standard Time"

# Asegurar que el servicio de hora esté en automático y corriendo
Set-Service -Name W32Time -StartupType Automatic
Start-Service -Name W32Time

# Forzar sincronización con servidor de tiempo
w32tm /resync /nowait

Write-Output "Zona horaria configurada a Madrid, servicio de hora iniciado y sincronizado."
exit 0
