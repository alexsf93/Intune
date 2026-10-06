<#
.SYNOPSIS
    Configuracion de informacion de soporte corporativo de Inkoova Digital Solutions en Windows.

.DESCRIPTION
    Este script esta diseñado para ejecutarse como Platform Script en Microsoft Intune bajo contexto SYSTEM.
    Realiza las siguientes acciones:
    1. Configura las claves de soporte en HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\OEMInformation:
       - Manufacturer: Inkoova Digital Solutions
       - SupportHours: Lunes a Viernes 08:00 a 18:00
       - SupportPhone: Email: managedservices@inkoova.com
       - SupportURL: https://inkoova.soporte.inkoova.com/
    2. Personaliza la ventana "Acerca de Windows" (winver) con el nombre de la organizacion.

.EXAMPLE
    Ejecucion a traves de Intune Platform Scripts:
    - Run this script using the logged on credentials: No (SYSTEM)
    - Enforce script signature check: No
    - Run script in 64 bit PowerShell Host: Yes

.NOTES
    Nombre:       Script - Configuracion_OEM_Informacion_Soporte.ps1
    Autor:        Alejandro Suarez (@alexsf93)
    Empresa:      Inkoova Digital Solutions
    Version:      2.0 (Optimizada sin descarga de logo)
    Requisitos:   PowerShell 5.1+, Windows 10/11, Contexto SYSTEM (Intune Platform Script / 64-bit).
#>

[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

try {
    Write-Output "Iniciando configuracion de soporte corporativo para Inkoova Digital Solutions..."

    $regOEMPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\OEMInformation"

    # 1. Asegurar la existencia de la rama de registro
    if (-not (Test-Path -Path $regOEMPath)) {
        New-Item -Path $regOEMPath -Force | Out-Null
    }

    # 2. Si existiera un valor antiguo de Logo, lo eliminamos para dejar el registro limpio
    if ((Get-ItemProperty -Path $regOEMPath -Name "Logo" -ErrorAction SilentlyContinue)) {
        Remove-ItemProperty -Path $regOEMPath -Name "Logo" -Force -ErrorAction SilentlyContinue
    }

    # 3. Asignar metadatos corporativos de soporte
    $oemProperties = @{
        "Manufacturer" = "Inkoova Digital Solutions"
        "SupportHours" = "Lunes a Viernes 08:00 a 18:00"
        "SupportPhone" = "Email: managedservices@inkoova.com"
        "SupportURL"   = "https://inkoova.soporte.inkoova.com/"
    }

    foreach ($entry in $oemProperties.GetEnumerator()) {
        Set-ItemProperty -Path $regOEMPath -Name $entry.Key -Value $entry.Value -Type String -Force
        Write-Output "Propiedad OEM asignada: $($entry.Key) = $($entry.Value)"
    }

    # 4. Configurar la ventana de 'Acerca de Windows' (winver)
    $regWinverPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion"
    Set-ItemProperty -Path $regWinverPath -Name "RegisteredOrganization" -Value "Inkoova Digital Solutions" -Force
    Set-ItemProperty -Path $regWinverPath -Name "RegisteredOwner" -Value "Dispositivo Corporativo" -Force
    Write-Output "Datos de organizacion en winver actualizados con exito."

    Write-Output "Configuracion corporativa de soporte aplicada exitosamente."
    exit 0
}
catch {
    Write-Error "Error durante la aplicacion de la configuracion corporativa: $_"
    exit 1
}
