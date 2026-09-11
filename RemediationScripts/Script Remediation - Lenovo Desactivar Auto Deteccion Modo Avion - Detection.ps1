<#
.SYNOPSIS
    DETECTION SCRIPT: DESACTIVAR AUTO DETECCIÓN DE MODO AVIÓN (LENOVO POWER MANAGER)

.DESCRIPTION
    Este script detecta si la funcionalidad "Detección automática de Modo Avión" de Lenovo Power Manager
    está activa en equipos Lenovo ThinkPad. Esta opción consulta la ubicación del equipo continuamente
    (cada 30-60 segundos), provocando la aparición recurrente del icono de localización en la barra de tareas.
    
    Si el valor 'AutoDetectionNewCheckBox' no está en 0, el script finaliza con Exit 1 para remediar.

.PARAMETER
    Ninguno.

.EXAMPLE
    Executes as Intune Detection Script.

.NOTES
    Name: Script Remediation - Lenovo Desactivar Auto Deteccion Modo Avion - Detection.ps1
    Author: Alejandro Suárez (@alexsf93)
    Version: 1.0.0
    Date: 2026-09-01
    Context: System
#>

$registryPath = "HKLM:\SOFTWARE\WOW6432Node\Lenovo\PWRMGRV\ConfKeys\Data\AirplaneMode"
$valueName    = "AutoDetectionNewCheckBox"

# 1. Comprobar fabricante del equipo
$manufacturer = (Get-CimInstance -ClassName Win32_ComputerSystem -ErrorAction SilentlyContinue).Manufacturer
$isLenovo     = $manufacturer -match "Lenovo"

# Si no es Lenovo y no existe la ruta de Lenovo Power Manager, el equipo no aplica
if (-not $isLenovo -and -not (Test-Path $registryPath)) {
    Exit 0
}

# 2. Comprobar el valor en el registro
if (Test-Path $registryPath) {
    $currentVal = (Get-ItemProperty -Path $registryPath -Name $valueName -ErrorAction SilentlyContinue).$valueName

    if ($null -ne $currentVal -and [int]$currentVal -eq 0) {
        Exit 0  # Autodetección ya desactivada
    }
    else {
        Exit 1  # Autodetección activa o no configurada
    }
}
else {
    Exit 1  # Clave no encontrada en equipo Lenovo, requiere remediación
}
