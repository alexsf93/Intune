<#
.SYNOPSIS
    DETECTION SCRIPT: COMPROBAR PRIMARY USER EN ADMINISTRADORES Y ESCRITORIO REMOTO

.DESCRIPTION
    Este script detecta si el usuario principal ("primary user") pertenece al grupo de 
    Administradores o al grupo de Usuarios de Escritorio Remoto (por SID individual o nombre).

.PARAMETER
    Ninguno.

.EXAMPLE
    Executes as Intune Detection Script.

.NOTES
    Name: Script Remediation - Quitar primaryuser de Administradores - Detection.ps1
    Author: Alejandro Suárez (@alexsf93)
    Version: 1.4.0
    Date: 2026-08-14
    Context: System
#>

# 1. Obtener el usuario principal (primary user)
$primaryUserFullName = Get-CimInstance -ClassName Win32_ComputerSystem | Select-Object -ExpandProperty UserName
if (-not $primaryUserFullName) {
    $reg = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Authentication\LogonUI"
    $primaryUserFullName = (Get-ItemProperty -Path $reg -Name LastLoggedOnUser -ErrorAction SilentlyContinue).LastLoggedOnUser
}

if (-not $primaryUserFullName) {
    Exit 0  # No hay usuario, nada que hacer
}

$primaryUser = $primaryUserFullName -replace "^.+\\", "" # Solo el nombre, sin dominio

# 2. Obtener el SID del usuario principal (soporta cuentas locales, dominio y Entra ID S-1-12-1-...)
$userSid = $null
try {
    $userSid = (Get-CimInstance -ClassName Win32_UserProfile -ErrorAction SilentlyContinue | Where-Object { $_.LocalPath -like "*\$primaryUser" -or $_.LocalPath -like "*\$primaryUser.*" }).SID
} catch {}

if (-not $userSid) {
    try {
        $ntAccount = New-Object System.Security.Principal.NTAccount($primaryUserFullName)
        $userSid = $ntAccount.Translate([System.Security.Principal.SecurityIdentifier]).Value
    } catch {
        try {
            $ntAccount = New-Object System.Security.Principal.NTAccount($primaryUser)
            $userSid = $ntAccount.Translate([System.Security.Principal.SecurityIdentifier]).Value
        } catch {}
    }
}

# Helper function para comprobar la membresia de un usuario en un grupo por SID o nombre
function Test-UserInGroup {
    param (
        [string]$GroupSid
    )

    try {
        $sidObj = New-Object System.Security.Principal.SecurityIdentifier($GroupSid)
        $groupName = $sidObj.Translate([System.Security.Principal.NTAccount]).Value.Split('\')[-1]
        $members = Get-LocalGroupMember -Group $groupName -ErrorAction SilentlyContinue

        if ($members) {
            foreach ($m in $members) {
                # Comprobar por SID del usuario (incluye SIDs de Entra ID S-1-12-1-...)
                if ($userSid -and $m.SID -and $m.SID.Value -eq $userSid) {
                    return $true
                }
                # Comprobar por nombre completo o nombre simple
                $mNameClean = $m.Name -replace "^.+\\", ""
                if ($m.Name -eq $primaryUserFullName -or $m.Name -eq $primaryUser -or $mNameClean -eq $primaryUser) {
                    return $true
                }
            }
        }
    } catch {}

    return $false
}

# 3. Comprobar Administradores (S-1-5-32-544) y Usuarios de Escritorio Remoto (S-1-5-32-555)
$inAdmin = Test-UserInGroup -GroupSid "S-1-5-32-544"
$inRdp   = Test-UserInGroup -GroupSid "S-1-5-32-555"

if ($inAdmin -or $inRdp) {
    Write-Host "El usuario '$primaryUser' (SID: $userSid) pertenece a grupos restringidos (Administradores: $inAdmin, Escritorio Remoto: $inRdp). Se requiere remediacion."
    Exit 1  # Requiere remediacion
}
else {
    Write-Host "El usuario '$primaryUser' (SID: $userSid) no esta directamente en Administradores ni en Usuarios de Escritorio Remoto."
    Exit 0  # Cumple la directiva
}
