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

##Elevarlo si es necesario

If (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]'Administrator')) {
    Write-Host "You didn't run this script as an Administrator. This script will self elevate to run as an Administrator and continue."
    Start-Sleep 1
    Write-Host "                                               3"
    Start-Sleep 1
    Write-Host "                                               2"
    Start-Sleep 1
    Write-Host "                                               1"
    Start-Sleep 1
    Start-Process powershell.exe -ArgumentList ("-NoProfile -ExecutionPolicy Bypass -File `"{0}`" -WhitelistApps {1}" -f $PSCommandPath, ($WhitelistApps -join ',')) -Verb RunAs
    Exit
}

#sin errores
$ErrorActionPreference = 'silentlycontinue'

$locale = Get-WinSystemLocale | Select-Object -expandproperty Name

##Activar la configuración regional para configurar las variables
switch ($locale) {
    "de-DE" {
        $everyone = "Jeder"
        $builtin = "Integriert"
    }
    "en-US" {
        $everyone = "Everyone"
        $builtin = "Builtin"
    }    
    "en-GB" {
        $everyone = "Everyone"
        $builtin = "Builtin"
    }
    default {
        $everyone = "Everyone"
        $builtin = "Builtin"
    }
}

Set-ItemProperty -Path HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Themes\Personalize -Name SystemUsesLightTheme -Value 0 -Force
Set-ItemProperty -Path HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Themes\Personalize -Name AppsUseLightTheme -Value 0 -Force
