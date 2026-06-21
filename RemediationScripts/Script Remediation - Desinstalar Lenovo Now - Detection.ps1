<#
.SYNOPSIS
    DETECTION SCRIPT: INSTALACIÓN DE LENOVO NOW

.DESCRIPTION
    Este script detecta si la aplicación **Lenovo Now** está instalada en el sistema Windows. 
    Está pensado para usarse en escenarios de detección previa a remediaciones, despliegues con Intune 
    o procesos de inventario automatizados.

.PARAMETER
    Ninguno.

.EXAMPLE
    Executes as Intune Detection Script.

.NOTES
    Name: Script Remediation - Desinstalar Lenovo Now - Detection.ps1
    Author: Alejandro Suárez (@alexsf93)
    Version: 1.0.0
    Date: 2026-01-21
    Context: System
#>

# Detectar si Lenovo Now está instalado en el sistema
$lenovoNOW = Get-Package "Lenovo Now*" -ErrorAction SilentlyContinue

if ($lenovoNOW) {
    Exit 1  # Está instalado
}
else {
    Exit 0  # No está instalado
}
