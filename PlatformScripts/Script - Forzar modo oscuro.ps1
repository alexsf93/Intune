<#
============================================================
        Script: Activar modo oscuro en Windows 10/11
------------------------------------------------------------
Autor: Alejandro Suárez (@alexsf93)
============================================================

.DESCRIPCIÓN
    Este script activa el **modo oscuro** tanto para el sistema como para las aplicaciones en Windows.
    Está pensado para ser usado en entornos gestionados con Microsoft Intune, pero puede ejecutarse manualmente también.

.CONSIDERACIONES / REQUISITOS
    1. **Permisos de Administrador:**  
       Si no se ejecuta como admin, el script intentará auto-elevarse automáticamente.
    2. **Exclusión en Intune:**  
       Antes de desplegarlo, asegúrate de que el dispositivo esté en un grupo de exclusión de políticas que puedan sobrescribir el cambio de tema.
    3. **Compatibilidad de idioma:**  
       Detecta idioma del sistema (en-US, en-GB, de-DE) para ciertas variables, usa valores por defecto para otros idiomas.
    4. **Uso de whitelist personalizada:**  
       Puedes añadir una lista personalizada de apps a la variable `$customwhitelist` si tu flujo de trabajo lo requiere.

.EJEMPLO DE USO
    # Desplegar como Platform Script en Intune:
    .\Script - Forzar modo oscuro.ps1

.ADVERTENCIAS
    - **Revisa el script antes de desplegarlo masivamente.**
    - Ejecuta siempre bajo supervisión.

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
