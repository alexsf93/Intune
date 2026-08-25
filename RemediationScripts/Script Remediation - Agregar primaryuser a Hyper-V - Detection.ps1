<#
.SYNOPSIS
    DETECTION SCRIPT: ADICIÓN DE USUARIO ENTRA ID / PRIMARY USER A ADMINISTRADORES DE HYPER-V

.DESCRIPTION
    Este script detecta si el usuario principal o activo de Entra ID (Azure AD) pertenece 
    al grupo local de Administradores de Hyper-V (identificado por su SID S-1-5-32-578).

.PARAMETER
    Ninguno.

.EXAMPLE
    Executes as Intune Detection Script.

.NOTES
    Name: Script Remediation - Agregar primaryuser a Hyper-V - Detection.ps1
    Author: Alejandro Suárez (@alexsf93)
    Version: 1.1.0
    Date: 2026-08-25
    Context: System
#>

try {
    # 1. Localizar el grupo Hyper-V por su SID estándar (S-1-5-32-578), independiente del idioma del OS
    $hypervSid = New-Object System.Security.Principal.SecurityIdentifier("S-1-5-32-578")
    try {
        $GroupName = $hypervSid.Translate([System.Security.Principal.NTAccount]).Value.Split('\')[-1]
    } catch {
        Write-Output "Hyper-V no está instalado o activado en este equipo (Grupo S-1-5-32-578 no encontrado)."
        exit 0
    }

    # 2. Obtener el usuario activo / primary user (soporta Entra ID, Dominio y Local)
    $primaryUserFullName = Get-CimInstance -ClassName Win32_ComputerSystem | Select-Object -ExpandProperty UserName
    if (-not $primaryUserFullName) {
        $regLogon = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Authentication\LogonUI"
        $primaryUserFullName = (Get-ItemProperty -Path $regLogon -Name LastLoggedOnUser -ErrorAction SilentlyContinue).LastLoggedOnUser
    }
    if (-not $primaryUserFullName) {
        $primaryUserFullName = (Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Provisioning\Diagnostics\Autopilot" -Name "Upn" -ErrorAction SilentlyContinue).Upn
        if ($primaryUserFullName) { $primaryUserFullName = "AzureAD\$primaryUserFullName" }
    }

    if (-not $primaryUserFullName) {
        Write-Output "No se detectó una sesión o cuenta de usuario activa."
        exit 0
    }

    $primaryUser = $primaryUserFullName -replace "^.+\\", "" # Nombre simple sin dominio/prefix

    # 3. Obtener el SID del usuario (si está disponible, soporta SIDs de Entra ID S-1-12-1-...)
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

    # 4. Validar la pertenencia al grupo de Hyper-V
    $members = Get-LocalGroupMember -Group $GroupName -ErrorAction SilentlyContinue

    $isMember = $false
    if ($members) {
        foreach ($m in $members) {
            # Coincidencia por SID de usuario (incluye SIDs S-1-12-1-... de Entra ID)
            if ($userSid -and $m.SID -and $m.SID.Value -eq $userSid) {
                $isMember = $true
                break
            }
            # Coincidencia por nombre completo, nombre simple o prefijo AzureAD
            $mNameClean = $m.Name -replace "^.+\\", ""
            if ($m.Name -eq $primaryUserFullName -or $m.Name -eq $primaryUser -or $mNameClean -eq $primaryUser -or $m.Name -eq "AzureAD\$primaryUser") {
                $isMember = $true
                break
            }
        }
    }

    if ($isMember) {
        Write-Output "El usuario '$primaryUserFullName' ya es miembro del grupo '$GroupName'."
        exit 0
    }
    else {
        Write-Output "El usuario '$primaryUserFullName' NO es miembro del grupo '$GroupName'. Se requiere remediación."
        exit 1
    }
}
catch {
    Write-Output "Error al evaluar la pertenencia al grupo local: $_"
    exit 1
}
