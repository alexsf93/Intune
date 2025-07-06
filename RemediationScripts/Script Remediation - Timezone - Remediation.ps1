<#
=====================================================================================================
    REMEDIACIÓN: ZONA HORARIA MADRID Y SINCRONIZACIÓN DE HORA (INTUNE)
-----------------------------------------------------------------------------------------------------
Este script configura la zona horaria de Madrid ("Romance Standard Time"), asegura que el servicio de
hora de Windows esté iniciado y en automático, y fuerza la sincronización de la hora.

Compatible con Intune Remediations. Debe ejecutarse como SYSTEM.
-----------------------------------------------------------------------------------------------------
AUTOR: Alejandro Suárez (@alexsf93)
=====================================================================================================
#>

# Comprobar si el script tiene permisos de administrador/SYSTEM
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")
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
