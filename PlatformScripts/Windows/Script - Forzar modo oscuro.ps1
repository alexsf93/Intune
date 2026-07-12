<#
.SYNOPSIS
    Activar modo oscuro en Windows 10/11.

.DESCRIPTION
    Este script activa el modo oscuro tanto para el sistema como para las aplicaciones en Windows.
    Está pensado para ser usado en entornos gestionados con Microsoft Intune, pero puede ejecutarse manualmente también.

.PARAMETER CustomWhitelist
    Lista personalizada de aplicaciones a excluir (opcional).

.EXAMPLE
    .\Script - Forzar modo oscuro.ps1

.NOTES
    Name: Script - Forzar modo oscuro.ps1
    Author: Alejandro Suárez (@alexsf93)
    Version: 1.0.0
    Date: 2026-01-21
#>


param (
    [string[]]$customwhitelist
)

# Configurar preferencia de error y asegurar que la ruta del registro exista
$ErrorActionPreference = 'Stop'
$RegistryPath = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Themes\Personalize"

try {
    if (-not (Test-Path $RegistryPath)) {
        New-Item -Path $RegistryPath -Force | Out-Null
    }

    Set-ItemProperty -Path $RegistryPath -Name SystemUsesLightTheme -Value 0 -Force | Out-Null
    Set-ItemProperty -Path $RegistryPath -Name AppsUseLightTheme -Value 0 -Force | Out-Null
    Write-Output "Modo oscuro forzado con éxito para el usuario actual."
}
catch {
    Write-Error "No se pudo configurar el modo oscuro en el registro del usuario actual: $($_.Exception.Message)"
    exit 1
}
