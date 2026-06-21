<#
.SYNOPSIS
    DETECTION SCRIPT: INSTALACIÓN DE DROPBOX

.DESCRIPTION
    Este script comprueba si la aplicación **Dropbox** está instalada en el sistema Windows.
    Está pensado para usarse en entornos gestionados (Intune, Autopilot, remediaciones, etc.) 
    para validar el estado de la instalación de Dropbox de forma silenciosa y automatizable.

.PARAMETER
    Ninguno.

.EXAMPLE
    Executes as Intune Detection Script.

.NOTES
    Name: Script Remediation - Desinstalar Dropbox - Detection.ps1
    Author: Alejandro Suárez (@alexsf93)
    Version: 1.0.0
    Date: 2026-01-21
    Context: User
#>

# Detectar si Dropbox está instalado en el sistema
$dropbox = Get-AppxPackage *Dropbox*

if ($dropbox) {
    Exit 1  # Está instalado
}
else {
    Exit 0  # No está instalado
}
