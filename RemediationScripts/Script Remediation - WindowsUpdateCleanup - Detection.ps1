<#
.SYNOPSIS
    DETECTION SCRIPT: COMPROBACION FISICA DE WINDOWS UPDATE CLEANUP

.DESCRIPTION
    Este script analiza el tamano fisico real y la presencia de actualizaciones pendientes 
    en el sistema de distribucion de parches. Si la remediacion ya ha vaciado estas rutas, 
    el script informara que el equipo esta limpio, evitando bucles falsos de DISM.

.PARAMETER
    Ninguno.

.EXAMPLE
    Executes as Intune Detection Script.

.NOTES
    Name: Script Remediation - WindowsUpdateCleanup - Detection.ps1
    Author: Alejandro Suarez (@alexsf93)
    Version: 2.1.1
    Date: 2026-06-14
#>

# Define el umbral en Megabytes (MB) para evitar activar la remediacion por archivos residuales insignificantes
$storageThresholdMB = 50

# Rutas criticas de almacenamiento de descargas e instalaciones de parches
$targetPaths = @(
    "C:\Windows\SoftwareDistribution\Download",
    "C:\Windows\SoftwareDistribution\PostRebootEventCache.V2"
)

$totalBytes = 0

foreach ($path in $targetPaths) {
    if (Test-Path $path) {
        # Sumamos los archivos reales de estas rutas de actualizacion
        $size = Get-ChildItem -Path $path -Recurse -File -ErrorAction SilentlyContinue | 
                Measure-Object -Property Length -Sum | 
                Select-Object -ExpandProperty Sum
        
        if ($size) { $totalBytes += $size }
    }
}

# Convertimos los bytes totales a Megabytes (MB)
$updateCleanupSizeMB = [math]::Round($totalBytes / 1MB, 2)

# Logica de deteccion inteligente:
if ($updateCleanupSizeMB -gt $storageThresholdMB) {
    Write-Host "Deteccion: Windows Update Cleanup acumula ($updateCleanupSizeMB MB). Requiere remediacion."
    exit 1
} else {
    Write-Host "Deteccion: El entorno de actualizaciones de Windows esta limpio o por debajo del umbral ($updateCleanupSizeMB MB)."
    exit 0
}