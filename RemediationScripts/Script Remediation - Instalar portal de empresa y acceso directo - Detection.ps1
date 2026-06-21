<#
.SYNOPSIS
    DETECTION SCRIPT: ¿ESTÁ INSTALADO EL COMPANY PORTAL (PORTAL DE EMPRESA)?

.DESCRIPTION
    Este script detecta si la aplicación **Company Portal** de Microsoft está instalada en el equipo
    en formato AppX/MSIX. Está orientado a escenarios de remediación y compliance con Microsoft Intune.

.PARAMETER
    Ninguno.

.EXAMPLE
    Executes as Intune Detection Script.

.NOTES
    Name: Script Remediation - Instalar portal de empresa y acceso directo - Detection.ps1
    Author: Alejandro Suárez (@alexsf93)
    Version: 1.0.0
    Date: 2026-01-21
    Context: System
#>

$cp = Get-AppxPackage -Name "Microsoft.CompanyPortal" -ErrorAction SilentlyContinue
if ($cp) {
    Exit 0  # Está instalado
}
else {
    Exit 1  # NO está instalado (necesita remediación)
}
