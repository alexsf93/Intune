<#
.SYNOPSIS
    DETECTION SCRIPT: ¿ES EL "PRIMARY USER" ADMINISTRADOR LOCAL?

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
}
else {
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
}
else {
    Exit 1  # No es administrador, requiere remediation
}