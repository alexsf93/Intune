<#
=====================================================================================================
    DETECTION SCRIPT: PLANES DE ENERGÍA HABITUALES EN WINDOWS
-----------------------------------------------------------------------------------------------------
Este script detecta si los planes de energía estándar de Windows están presentes en el sistema:

- Equilibrado (Balanced)
- Alto rendimiento (High Performance)
- Economizador (Power Saver)

Está diseñado para ejecutarse con privilegios SYSTEM (por ejemplo, vía Intune) y
activar la remediación en caso de que falte alguno de los planes estándar.

-----------------------------------------------------------------------------------------------------
¿CÓMO FUNCIONA?
-----------------------------------------------------------------------------------------------------
- Define los GUIDs de los planes estándar.
- Obtiene los planes de energía instalados en el sistema (usando regex para ser independiente del idioma).
- Compara los planes instalados con los requeridos.
- Devuelve:
  * "OK" y código de salida 0 si todos los planes están presentes.
  * "NOK" y código de salida 1 si falta alguno.

-----------------------------------------------------------------------------------------------------
INSTRUCCIONES DE USO
-----------------------------------------------------------------------------------------------------
- Ejecutar con permisos SYSTEM para garantizar la detección correcta.
- Usar como Detection Rule en Intune u otros sistemas que interpreten exit codes.
- Un exit code 0 indica que los planes de energía estándar están presentes.
- Un exit code 1 indica que falta al menos un plan y se debe aplicar el script de remediación.

-----------------------------------------------------------------------------------------------------
AUTOR: Alejandro Suárez (@alexsf93)
=====================================================================================================
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
} else {
    Write-Output "NOK - Faltan planes de energía: $($missing -join ', ')"
    exit 1
}
