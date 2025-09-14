<#
=====================================================================================================
    REMEDIATION SCRIPT: ZONA HORARIA MADRID Y SINCRONIZACIÓN DE HORA (INTUNE)
-----------------------------------------------------------------------------------------------------
Este script configura la zona horaria de Madrid ("Romance Standard Time"), asegura que el servicio
de hora de Windows esté en inicio automático y en ejecución, y fuerza una sincronización de hora.

Compatible con Intune Remediations. Debe ejecutarse como SYSTEM.

-----------------------------------------------------------------------------------------------------
REQUISITOS
-----------------------------------------------------------------------------------------------------
- PowerShell 5.1 o 7.x.
- Permisos de administrador/SYSTEM.
- Herramienta `w32tm` disponible (Windows Time Service).

-----------------------------------------------------------------------------------------------------
¿CÓMO FUNCIONA?
-----------------------------------------------------------------------------------------------------
- Verifica que el contexto sea administrador/SYSTEM.
- Establece la zona horaria a "Romance Standard Time".
- Configura `W32Time` con inicio `Automatic` y lo inicia si es necesario.
- Ejecuta `w32tm /resync /nowait` para forzar la sincronización.

-----------------------------------------------------------------------------------------------------
RESULTADOS
-----------------------------------------------------------------------------------------------------
- "OK" (exit code 0) → Zona horaria aplicada, servicio activo y sincronización solicitada.
- "NOK" (exit code 1) → El script no se ejecutó con privilegios adecuados.

-----------------------------------------------------------------------------------------------------
INSTRUCCIONES DE USO
-----------------------------------------------------------------------------------------------------
- Ejecutar como Remediation Script en Intune (contexto SYSTEM).
- Revisar la salida estándar para confirmar las acciones realizadas.
- Emparejar con el Detection Script correspondiente para validar conformidad.

-----------------------------------------------------------------------------------------------------
AUTOR: Alejandro Suárez (@alexsf93)
=====================================================================================================
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
