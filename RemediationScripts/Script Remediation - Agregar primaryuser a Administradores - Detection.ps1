<#
.SYNOPSIS
    DETECTION SCRIPT: Â¿ES EL "PRIMARY USER" ADMINISTRADOR LOCAL?

.DESCRIPTION
    Este script detecta si el usuario principal ("primary user") del dispositivo pertenece al grupo de 
    administradores locales. 

.PARAMETER
    Ninguno.

.EXAMPLE
    Executes as Intune Detection Script.

.NOTES
    Name: Script Remediation - Agregar primaryuser a Administradores - Detection.ps1
    Author: Alejandro Suárez (@alexsf93)
    Version: 1.0.0
    Date: 2026-01-21
    Context: System
#>

# 1. Obtener el usuario con más sesiones (aproximación "primary user")
$primaryUserFullName = Get-CimInstance -ClassName Win32_ComputerSystem | Select-Object -ExpandProperty UserName
if (-not $primaryUserFullName) {
    # Alternativa: sacar el último usuario logueado a partir del registro
    $reg = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Authentication\LogonUI"
    $primaryUserFullName = (Get-ItemProperty -Path $reg -Name LastLoggedOnUser -ErrorAction SilentlyContinue).LastLoggedOnUser
}

if (-not $primaryUserFullName) {
    Exit 0  # No hay usuario, nada que hacer
}

$primaryUser = $primaryUserFullName -replace "^.+\\", "" # Solo el nombre, sin dominio

# 2. Comprobar si está en el grupo de administradores locales (resolviendo el grupo por SID para soportar cualquier idioma de OS)
$adminSid = New-Object System.Security.Principal.SecurityIdentifier("S-1-5-32-544")
$adminGroupName = $adminSid.Translate([System.Security.Principal.NTAccount]).Value.Split('\')[-1]
$localAdmins = Get-LocalGroupMember -Group $adminGroupName -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Name

$alreadyAdmin = $false
if ($localAdmins) {
    if ($localAdmins -contains $primaryUserFullName -or $localAdmins -contains $primaryUser) {
        $alreadyAdmin = $true
    } else {
        $localAdminsClean = $localAdmins | ForEach-Object { $_ -replace "^.+\\", "" }
        if ($localAdminsClean -contains $primaryUser) {
            $alreadyAdmin = $true
        }
    }
}

if ($alreadyAdmin) {
    Exit 0  # Ya es administrador
}
else {
    Exit 1  # No es administrador, requiere remediation
}
