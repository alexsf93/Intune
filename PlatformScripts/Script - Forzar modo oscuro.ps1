<#
Este script está diseñado para ser utilizado en entornos gestionados con Microsoft Intune.

**Propósito:**  
Modifica la apariencia del tema de Windows, activando el modo oscuro tanto para el sistema como para las aplicaciones.

**Consideraciones y requisitos:**

1. **Permisos de Administrador:**  
   El script requiere ejecución con privilegios de administrador. Si no se ejecuta como administrador, intentará autoelevarse automáticamente.

2. **Exclusión en Intune:**  
   Antes de ejecutar este script, asegúrate de que el equipo esté incluido en un grupo de exclusión dentro de **Intune** para evitar que las políticas de configuración de Intune sobrescriban los cambios realizados por el script.

3. **Compatibilidad de Idioma:**  
   El script detecta automáticamente el idioma del sistema para establecer variables relacionadas con grupos de seguridad. Si el idioma del sistema no está contemplado (en-US, en-GB, de-DE), se utilizarán los valores en inglés por defecto.

4. **Parámetro opcional:**  
   Puedes incluir una lista personalizada de aplicaciones en la variable `$customwhitelist` si tu flujo de trabajo lo requiere.

5. **Uso:**
   Puedes desplegarlo como un PlatformScript en Microsoft Intune

6. **Advertencia:**  
   Revisa el script antes de desplegarlo masivamente. Ejecuta siempre bajo supervisión.

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
