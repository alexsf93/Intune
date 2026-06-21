<#
.SYNOPSIS
    REMEDIATION SCRIPT: DESINSTALAR DROPBOX

.DESCRIPTION
    Este script elimina la aplicación **Dropbox** instalada como AppxPackage en sistemas Windows.
    Está pensado para escenarios de remediación, despliegue con Intune o automatizaciones de limpieza 
    en dispositivos gestionados.

.PARAMETER
    Ninguno.

.EXAMPLE
    Executes as Intune Remediation Script.

.NOTES
    Name: Script Remediation - Desinstalar Dropbox - Remediation.ps1
    Author: Alejandro Suárez (@alexsf93)
    Version: 1.0.0
    Date: 2026-01-21
    Context: User
#>

# Define la ruta del script temporal
$scriptPath = "C:\UninstallDropbox.ps1"

# Crear el contenido del script
$scriptContent = @"
Get-AppxPackage *Dropbox* | Remove-AppxPackage
"@

# Escribir el script en disco
Set-Content -Path $scriptPath -Value $scriptContent

# Ejecutar el script con ExecutionPolicy Bypass
powershell -ExecutionPolicy Bypass -File $scriptPath

# Eliminar el script temporal tras la ejecución
Remove-Item -Path $scriptPath -Force
