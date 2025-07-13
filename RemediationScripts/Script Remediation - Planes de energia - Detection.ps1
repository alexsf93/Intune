<#
=====================================================================================================
    DETECTION SCRIPT — PLANES DE ENERGÍA HABITUALES
-----------------------------------------------------------------------------------------------------
Este script detecta si los planes estándar de energía están presentes en el sistema:

- Equilibrado
- Alto rendimiento
- Economizador

Si falta alguno de estos planes, devuelve "NOK" y código de salida 1 para activar la remediación.

-----------------------------------------------------------------------------------------------------
¿CÓMO FUNCIONA?
-----------------------------------------------------------------------------------------------------
- Define los GUIDs de los planes esperados.
- Obtiene la lista de planes de energía instalados en el sistema.
- Compara los planes instalados con los requeridos.
- Devuelve "OK" y exit code 0 si todos los planes están presentes.
- Devuelve "NOK" y exit code 1 si falta alguno.

-----------------------------------------------------------------------------------------------------
INSTRUCCIONES DE USO
-----------------------------------------------------------------------------------------------------
- Utilízalo como Detection Rule en Intune u otros sistemas que interpreten exit codes.
- Un exit code 0 indica que los planes de energía estándar están presentes.
- Un exit code 1 indica que falta al menos un plan, por lo que se debe remediar.

-----------------------------------------------------------------------------------------------------
AUTOR: Alejandro Suárez (@alexsf93)
=====================================================================================================
#>

# GUIDs de planes de energía esperados
$requiredPlans = @(
    "381b4222-f694-41f0-9685-ff5bb260df2e", # Equilibrado
    "8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c", # Alto rendimiento
    "a1841308-3541-4fab-bc81-f71556f20b4a"  # Economizador
)

# Obtener GUIDs de planes de energía instalados
$installedPlans = powercfg /list | Select-String -Pattern "Power Scheme GUID" | ForEach-Object {
    ($_ -split ":")[1].Trim().Split()[0]
}

# Verificar si falta alguno
$missing = $requiredPlans | Where-Object { $_ -notin $installedPlans }

if ($missing.Count -eq 0) {
    Write-Output "OK"
    exit 0
} else {
    Write-Output "NOK - Faltan planes de energía: $($missing -join ', ')"
    exit 1
}
