<#
.SYNOPSIS
    DETECTION SCRIPT: PLANES DE ENERGÍA HABITUALES EN WINDOWS

.DESCRIPTION
    Este script detecta si los planes de energía estándar de Windows están presentes en el sistema:
    - Equilibrado (Balanced)
    - Alto rendimiento (High Performance)
    - Economizador (Power Saver)

.PARAMETER
    Ninguno.

.EXAMPLE
    Executes as Intune Detection Script.

.NOTES
    Name: CORREGIR_Script Remediation - Planes de energia - Detection.ps1
    Author: Alejandro Suárez (@alexsf93)
    Version: 1.0.0
    Date: 2026-01-21
#>

# GUIDs de planes de energía esperados
$requiredPlans = @(
    "381b4222-f694-41f0-9685-ff5bb260df2e", # Equilibrado
    "8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c", # Alto rendimiento
    "a1841308-3541-4fab-bc81-f71556f20b4a"  # Economizador
) | ForEach-Object { $_.ToLowerInvariant() }

# Regex para extraer GUIDs (independiente del idioma de la salida)
$guidRegex = '[0-9a-fA-F]{8}(-[0-9a-fA-F]{4}){3}-[0-9a-fA-F]{12}'

# Obtener GUIDs de planes instalados
$installedPlans = powercfg /list |
Select-String -Pattern $guidRegex -AllMatches |
ForEach-Object { $_.Matches.Value.ToLowerInvariant() } |
Select-Object -Unique

# Verificar si falta alguno
$missing = $requiredPlans | Where-Object { $_ -notin $installedPlans }

if (-not $missing -or $missing.Count -eq 0) {
    Write-Output "OK"
    exit 0
}
else {
    Write-Output "NOK - Faltan planes de energía: $($missing -join ', ')"
    exit 1
}
