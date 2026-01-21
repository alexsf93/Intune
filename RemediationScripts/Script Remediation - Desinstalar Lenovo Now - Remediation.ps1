<#
.SYNOPSIS
    REMEDIATION SCRIPT: DESINSTALAR LENOVO NOW

.DESCRIPTION
    Este script desinstala la aplicación **Lenovo Now** de sistemas Windows de forma silenciosa. 
    Está pensado para automatizaciones, remediaciones con Intune o limpieza manual de bloatware 
    en dispositivos gestionados.

.PARAMETER
    Ninguno.

.EXAMPLE
    Executes as Intune Remediation Script.

.NOTES
    Name: Script Remediation - Desinstalar Lenovo Now - Remediation.ps1
    Author: Alejandro Suárez (@alexsf93)
    Version: 1.0.0
    Date: 2026-01-21
#>

$path = 'C:\Program Files (x86)\Lenovo\LenovoNow\unins000.exe'
$params = "/SILENT"

if (Test-Path -Path $path) {
    Start-Process -FilePath $path -ArgumentList $params -Wait
}
