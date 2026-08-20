<#
.SYNOPSIS
    REMEDIATION SCRIPT: QUITAR PRIMARY USER DE ADMINISTRADORES Y ESCRITORIO REMOTO

.DESCRIPTION
    Este script elimina al usuario principal ("primary user") de los grupos de Administradores 
    y Usuarios de Escritorio Remoto, notifica al usuario y programa un reinicio en 10 minutos.

.PARAMETER
    Ninguno.

.EXAMPLE
    Executes as Intune Remediation Script.

.NOTES
    Name: Script Remediation - Quitar primaryuser de Administradores - Remediation.ps1
    Author: Alejandro Suárez (@alexsf93)
    Version: 1.3.0
    Date: 2026-08-14
    Context: System
#>

# 1. Obtener el primary user
$primaryUserFullName = Get-CimInstance -ClassName Win32_ComputerSystem | Select-Object -ExpandProperty UserName
if (-not $primaryUserFullName) {
    $reg = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Authentication\LogonUI"
    $primaryUserFullName = (Get-ItemProperty -Path $reg -Name LastLoggedOnUser -ErrorAction SilentlyContinue).LastLoggedOnUser
}

if (-not $primaryUserFullName) {
    Exit 0
}

$primaryUser = $primaryUserFullName -replace "^.+\\", ""

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

# Helper function para quitar usuario de un grupo por SID
function Remove-UserFromGroup {
    param (
        [string]$GroupSid
    )

    try {
        $sidObj = New-Object System.Security.Principal.SecurityIdentifier($GroupSid)
        $groupName = $sidObj.Translate([System.Security.Principal.NTAccount]).Value.Split('\')[-1]
        $members = Get-LocalGroupMember -Group $groupName -ErrorAction SilentlyContinue

        $memberToDelete = $null
        if ($members) {
            foreach ($m in $members) {
                if (($userSid -and $m.SID -and $m.SID.Value -eq $userSid) -or 
                    ($m.Name -eq $primaryUserFullName) -or 
                    ($m.Name -eq $primaryUser) -or 
                    (($m.Name -replace "^.+\\", "") -eq $primaryUser)) {
                    $memberToDelete = $m
                    break
                }
            }
        }

        if ($memberToDelete) {
            # Intentar borrar por el identificador o SID especifico del miembro
            try {
                Remove-LocalGroupMember -Group $groupName -Member $memberToDelete.SID.Value -ErrorAction Stop
                Write-Host "Quitado el SID '$($memberToDelete.SID.Value)' del grupo '$groupName'."
                return $true
            } catch {
                try {
                    Remove-LocalGroupMember -Group $groupName -Member $primaryUserFullName -ErrorAction Stop
                    Write-Host "Quitado '$primaryUserFullName' del grupo '$groupName'."
                    return $true
                } catch {
                    try {
                        Remove-LocalGroupMember -Group $groupName -Member $primaryUser -ErrorAction Stop
                        Write-Host "Quitado '$primaryUser' del grupo '$groupName'."
                        return $true
                    } catch {
                        Write-Host "No se pudo quitar a $primaryUser del grupo '$groupName': $_"
                    }
                }
            }
        }
    } catch {}

    return $false
}

# 3. Remover de Administradores (S-1-5-32-544) y Usuarios de Escritorio Remoto (S-1-5-32-555)
$removedAdmin = Remove-UserFromGroup -GroupSid "S-1-5-32-544"
$removedRdp   = Remove-UserFromGroup -GroupSid "S-1-5-32-555"

# 4. Notificar al usuario y programar reinicio si se realizo algun cambio
if ($removedAdmin -or $removedRdp) {
    $notificationText = "Se han actualizado los permisos de su cuenta de usuario en este equipo. El sistema se reiniciara automaticamente en 10 minutos para aplicar los cambios."

    # Mostrar mensaje interactivo en pantalla si hay sesion de usuario activa
    try {
        msg.exe * /TIME:30 $notificationText 2>$null
    } catch {}

    # Programar reinicio a los 10 minutos (600 s) con aviso de sistema
    shutdown.exe /r /t 600 /c $notificationText
    Write-Host "Se ha notificado al usuario y programado el reinicio del sistema en 10 minutos."
}
