<#
.SYNOPSIS
    REMEDIATION SCRIPT: AÑADIR "PRIMARY USER" AL GRUPO DE ADMINISTRADORES LOCALES

.DESCRIPTION
    Este script añade el "primary user" (usuario más frecuente o último logueado) al grupo de 
    administradores locales si aún no lo está.

.PARAMETER
    Ninguno.

.EXAMPLE
    Executes as Intune Remediation Script.

.NOTES
    Name: Script Remediation - Agregar primaryuser a Administradores - Remediation.ps1
    Author: Alejandro Suárez (@alexsf93)
    Version: 1.0.0
    Date: 2026-01-21
    Context: System
#>

# 1. Obtener el primary user como en el detection
$primaryUserFullName = Get-CimInstance -ClassName Win32_ComputerSystem | Select-Object -ExpandProperty UserName
if (-not $primaryUserFullName) {
    $reg = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Authentication\LogonUI"
    $primaryUserFullName = (Get-ItemProperty -Path $reg -Name LastLoggedOnUser -ErrorAction SilentlyContinue).LastLoggedOnUser
}

if ($primaryUserFullName) {
    $primaryUser = $primaryUserFullName -replace "^.+\\", "" # Solo el nombre, sin dominio

    # 2. Añadirlo como administrador local (soporta dominio/local/AAD) resolviendo el grupo por SID
    $adminSid = New-Object System.Security.Principal.SecurityIdentifier("S-1-5-32-544")
    $adminGroupName = $adminSid.Translate([System.Security.Principal.NTAccount]).Value.Split('\')[-1]

    try {
        Add-LocalGroupMember -Group $adminGroupName -Member $primaryUserFullName -ErrorAction Stop
        Write-Host "Añadido '$primaryUserFullName' al grupo de administradores locales ($adminGroupName)."
    }
    catch {
        try {
            Add-LocalGroupMember -Group $adminGroupName -Member $primaryUser -ErrorAction Stop
            Write-Host "Añadido '$primaryUser' al grupo de administradores locales ($adminGroupName)."
        }
        catch {
            Write-Host "No se pudo añadir a $primaryUserFullName ($primaryUser) al grupo de administradores locales ($adminGroupName): $_"
        }
    }
}
