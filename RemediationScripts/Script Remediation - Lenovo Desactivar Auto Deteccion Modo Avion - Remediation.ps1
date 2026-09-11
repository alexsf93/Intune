<#
.SYNOPSIS
    REMEDIATION SCRIPT: DESACTIVAR AUTO DETECCIÓN DE MODO AVIÓN (LENOVO POWER MANAGER)

.DESCRIPTION
    Este script deshabilita la opción "Detección automática de Modo Avión" de Lenovo Power Manager
    estableciendo el valor 'AutoDetectionNewCheckBox' = 0 (DWORD) en el registro.
    Esto elimina las consultas continuas a la API de ubicación de Windows, evitando que aparezca
    el icono de localización constantemente en la barra de tareas.

.PARAMETER
    Ninguno.

.EXAMPLE
    Executes as Intune Remediation Script.

.NOTES
    Name: Script Remediation - Lenovo Desactivar Auto Deteccion Modo Avion - Remediation.ps1
    Author: Alejandro Suárez (@alexsf93)
    Version: 1.0.0
    Date: 2026-09-01
    Context: System
#>

$registryPath = "HKLM:\SOFTWARE\WOW6432Node\Lenovo\PWRMGRV\ConfKeys\Data\AirplaneMode"
$valueName    = "AutoDetectionNewCheckBox"

try {
    # 1. Crear la ruta de registro si no existe
    if (-not (Test-Path $registryPath)) {
        New-Item -Path $registryPath -Force | Out-Null
    }

    # 2. Establecer el valor a 0 (DWord)
    Set-ItemProperty -Path $registryPath -Name $valueName -Value 0 -Type DWord -Force

    # 3. Validar que se ha aplicado correctamente
    $checkVal = (Get-ItemProperty -Path $registryPath -Name $valueName -ErrorAction Stop).$valueName

    if ($null -ne $checkVal -and [int]$checkVal -eq 0) {
        Exit 0
    }
    else {
        Exit 1
    }
}
catch {
    Exit 1
}
