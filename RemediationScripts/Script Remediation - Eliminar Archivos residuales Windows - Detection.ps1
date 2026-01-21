<#
.SYNOPSIS
    DETECTION SCRIPT: ARCHIVOS/RESIDUOS DE INSTALACIONES DE WINDOWS

.DESCRIPTION
    Este script detecta la presencia de carpetas y archivos residuales de instalaciones o actualizaciones 
    anteriores de Windows (por ejemplo: Windows.old, $WINDOWS.~BT, $WINDOWS.~WS, carpetas de migración, etc.). 
    Está pensado para usarse como parte de procesos de remediación en Intune o comprobaciones de limpieza.

.PARAMETER
    Ninguno.

.EXAMPLE
    Executes as Intune Detection Script.

.NOTES
    Name: Script Remediation - Eliminar Archivos residuales Windows - Detection.ps1
    Author: Alejandro Suárez (@alexsf93)
    Version: 1.0.0
    Date: 2026-01-21
#>

$paths = @(
    "C:\Windows.old",
    "C:\$WINDOWS.~BT",
    "C:\$WINDOWS.~WS",
    "C:\$INPLACE.~TR",
    "C:\$GetCurrent",
    "C:\ESD",
    "C:\$SysReset",
    "C:\Windows10Upgrade",
    "C:\Recovery"
)

foreach ($path in $paths) {
    if (Test-Path $path) {
        Write-Output "Encontrado: $path"
        Exit 1
    }
}

Write-Output "No se detectan residuos de instalaciones previas de Windows."
Exit 0
