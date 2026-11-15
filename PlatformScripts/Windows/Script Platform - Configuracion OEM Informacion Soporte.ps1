<#
.SYNOPSIS
    Configuración de información de soporte corporativo OEM en Windows.

.DESCRIPTION
    Este script está diseñado para ejecutarse como Platform Script en Microsoft Intune bajo contexto SYSTEM.
    Realiza las siguientes acciones:
    1. Configura las claves de soporte en HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\OEMInformation:
       - Manufacturer: Inkoova Digital Solutions
       - SupportHours: Lunes a Viernes 08:00 a 18:00
       - SupportPhone: Email: managedservices@inkoova.com
       - SupportURL: https://inkoova.soporte.inkoova.com/
    2. Elimina cualquier clave antigua o residual de 'Logo' para mantener limpio el registro.
    3. Personaliza la ventana "Acerca de Windows" (winver) con el nombre de la organización corporativa.

.PARAMETER
    Ninguno.

.EXAMPLE
    .\Script Platform - Configuracion OEM Informacion Soporte.ps1

.NOTES
    Name: Script Platform - Configuracion OEM Informacion Soporte.ps1
    Author: Alejandro Suárez (@alexsf93)
    Version: 1.0.0
    Date: 2026-11-10
#>

[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

try {
    Write-Output "Iniciando configuración de soporte corporativo para Inkoova Digital Solutions..."

    $regOEMPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\OEMInformation"

    # 1. Asegurar la existencia de la rama de registro
    if (-not (Test-Path -Path $regOEMPath)) {
        New-Item -Path $regOEMPath -Force | Out-Null
    }

    # 2. Si existiera un valor antiguo de Logo, lo eliminamos para dejar el registro limpio
    if (Get-ItemProperty -Path $regOEMPath -Name "Logo" -ErrorAction SilentlyContinue) {
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
    Write-Output "Datos de organización en winver actualizados con éxito."

    Write-Output "Configuración corporativa de soporte aplicada exitosamente."
    exit 0
}
catch {
    Write-Error "Error durante la aplicación de la configuración corporativa: $_"
    exit 1
}
