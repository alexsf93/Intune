<#
.SYNOPSIS
    REMEDIATION SCRIPT: ADICIÓN DE USUARIO ENTRA ID / PRIMARY USER A ADMINISTRADORES DE HYPER-V

.DESCRIPTION
    Este script añade automáticamente la cuenta activa de Entra ID (Azure AD) / Primary User 
    al grupo local de Administradores de Hyper-V cuando la detección identifica que no pertenece a él,
    notifica al usuario en pantalla y programa un reinicio en 10 minutos para aplicar los cambios.

.PARAMETER
    Ninguno.

.EXAMPLE
    Executes as Intune Remediation Script.

.NOTES
    Name: Script Remediation - Agregar primaryuser a Hyper-V - Remediation.ps1
    Author: Alejandro Suárez (@alexsf93)
    Version: 1.2.0
    Date: 2026-08-25
    Context: System
#>

try {
    # 1. Localizar el grupo Hyper-V por su SID estándar (S-1-5-32-578)
    $hypervSid = New-Object System.Security.Principal.SecurityIdentifier("S-1-5-32-578")
    try {
        $GroupName = $hypervSid.Translate([System.Security.Principal.NTAccount]).Value.Split('\')[-1]
    } catch {
        Write-Error "El grupo local de Hyper-V (S-1-5-32-578) no existe en este equipo."
        exit 1
    }

    # 2. Obtener la cuenta activa / primary user
    $primaryUserFullName = Get-CimInstance -ClassName Win32_ComputerSystem | Select-Object -ExpandProperty UserName
    if (-not $primaryUserFullName) {
        $regLogon = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Authentication\LogonUI"
        $primaryUserFullName = (Get-ItemProperty -Path $regLogon -Name LastLoggedOnUser -ErrorAction SilentlyContinue).LastLoggedOnUser
    }
    if (-not $primaryUserFullName) {
        $upn = (Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Provisioning\Diagnostics\Autopilot" -Name "Upn" -ErrorAction SilentlyContinue).Upn
        if ($upn) { $primaryUserFullName = "AzureAD\$upn" }
    }

    if (-not $primaryUserFullName) {
        Write-Error "No se pudo recuperar la cuenta de usuario activa para agregar al grupo de Hyper-V."
        exit 1
    }

    $primaryUser = $primaryUserFullName -replace "^.+\\", ""

    # 3. Intentar añadir el usuario al grupo probando distintos formatos de nombre de cuenta
    $added = $false

    # Opción A: Nombre completo (ej: AzureAD\juan.perez@empresa.com o DOMAIN\usuario)
    try {
        Add-LocalGroupMember -Group $GroupName -Member $primaryUserFullName -ErrorAction Stop
        Write-Output "El usuario '$primaryUserFullName' se ha añadido correctamente al grupo '$GroupName'."
        $added = $true
    } catch {
        # Opción B: Nombre simple (ej: usuario o juan.perez)
        try {
            Add-LocalGroupMember -Group $GroupName -Member $primaryUser -ErrorAction Stop
            Write-Output "El usuario '$primaryUser' se ha añadido correctamente al grupo '$GroupName'."
            $added = $true
        } catch {
            # Opción C: Formato explícito AzureAD\usuario
            if ($primaryUserFullName -notlike "AzureAD\*") {
                try {
                    $aadUser = "AzureAD\$primaryUser"
                    Add-LocalGroupMember -Group $GroupName -Member $aadUser -ErrorAction Stop
                    Write-Output "El usuario '$aadUser' se ha añadido correctamente al grupo '$GroupName'."
                    $added = $true
                } catch {}
            }
        }
    }

    # 4. Notificar al usuario y programar reinicio en 10 minutos para aplicar los cambios de grupo
    if ($added) {
        $notificationText = "Se han actualizado los permisos de su cuenta de usuario (adición al grupo de Administradores de Hyper-V). El sistema se reiniciará automáticamente en 10 minutos para aplicar los cambios."

        # Mostrar mensaje interactivo en pantalla si hay sesión de usuario activa
        try {
            msg.exe * /TIME:30 $notificationText 2>$null
        } catch {}

        # Programar reinicio a los 10 minutos (600 s) con aviso de sistema
        shutdown.exe /r /t 600 /c $notificationText
        Write-Output "Se ha notificado al usuario y programado el reinicio del sistema en 10 minutos."
        exit 0
    } else {
        Write-Error "No se pudo añadir el usuario '$primaryUserFullName' ($primaryUser) al grupo '$GroupName'."
        exit 1
    }
}
catch {
    Write-Error "Error durante la ejecución de la remediación: $_"
    exit 1
}
