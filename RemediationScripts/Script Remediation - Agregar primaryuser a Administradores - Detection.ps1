<#
=====================================================================================================
    DETECTION SCRIPT: ¿ES EL “PRIMARY USER” ADMINISTRADOR LOCAL? (INTUNE COMPATIBLE)
-----------------------------------------------------------------------------------------------------
Este script detecta si el usuario principal ("primary user") del dispositivo pertenece al grupo de 
administradores locales. Está pensado para usarse en escenarios de compliance o remediaciones 
proactivas con Microsoft Intune en dispositivos gestionados.

-----------------------------------------------------------------------------------------------------
REQUISITOS
-----------------------------------------------------------------------------------------------------
- Debe ejecutarse con privilegios de administrador/SYSTEM.
- Compatible con PowerShell 5.1 o superior.
- Requiere acceso a los grupos locales del sistema.

-----------------------------------------------------------------------------------------------------
¿CÓMO FUNCIONA?
-----------------------------------------------------------------------------------------------------
- Obtiene el usuario más habitual del dispositivo (“primary user” aproximado).
- Comprueba si el usuario está en el grupo de administradores locales.
- Devuelve:
  * Exit code 0 → El usuario es administrador o no hay usuario detectado.
  * Exit code 1 → El usuario no es administrador.

-----------------------------------------------------------------------------------------------------
RESULTADOS
-----------------------------------------------------------------------------------------------------
- "OK" (exit code 0) → El primary user ya es administrador local o no se ha podido determinar usuario.
- "NOK" (exit code 1) → El primary user no es administrador local.

-----------------------------------------------------------------------------------------------------
INSTRUCCIONES DE USO
-----------------------------------------------------------------------------------------------------
- Usar como Detection Rule en Intune u otras plataformas de compliance.
- Interpretar los códigos de salida para decidir si aplicar un script de remediación.
- Debe ejecutarse en contexto SYSTEM para garantizar una detección correcta.

-----------------------------------------------------------------------------------------------------
AUTOR: Alejandro Suárez (@alexsf93)
=====================================================================================================
#>

# 1. Obtener el usuario con más sesiones (aproximación "primary user")
$users = Get-WmiObject -Class Win32_ComputerSystem | Select-Object -ExpandProperty UserName
if (-not $users) {
    # Alternativa: sacar el último usuario logueado a partir del registro
    $reg = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Authentication\LogonUI"
    $primaryUser = (Get-ItemProperty -Path $reg -Name LastLoggedOnUser -ErrorAction SilentlyContinue).LastLoggedOnUser
    if ($primaryUser) {
        $primaryUser = $primaryUser -replace "^.+\\", "" # Solo el nombre, sin dominio
    }
} else {
    $primaryUser = $users -replace "^.+\\", "" # Solo el nombre, sin dominio
}

if (-not $primaryUser) {
    Exit 0  # No hay usuario, nada que hacer
}

# 2. Comprobar si está en el grupo de administradores locales
$localAdmins = (Get-LocalGroupMember -Group "Administradores" -ErrorAction SilentlyContinue).Name + (Get-LocalGroupMember -Group "Administrators" -ErrorAction SilentlyContinue).Name
$alreadyAdmin = $localAdmins -contains $primaryUser

if ($alreadyAdmin) {
    Exit 0  # Ya es administrador
} else {
    Exit 1  # No es administrador, requiere remediation
}