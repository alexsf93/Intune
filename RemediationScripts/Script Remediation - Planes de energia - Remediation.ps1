<#
=====================================================================================================
    REMEDIACIÓN: RESTAURACIÓN DE PLANES DE ENERGÍA HABITUALES EN WINDOWS
-----------------------------------------------------------------------------------------------------
Este script restaura los planes de energía estándar de Windows si alguno no está presente:

- Equilibrado (Balanced)
- Alto rendimiento (High Performance)
- Economizador (Power Saver)

Está diseñado para ejecutarse con privilegios SYSTEM (por ejemplo, vía Intune Remediations) y
asegurar que los planes de energía estándar estén disponibles en el sistema.

-----------------------------------------------------------------------------------------------------
¿CÓMO FUNCIONA?
-----------------------------------------------------------------------------------------------------
- Define los planes estándar con sus GUIDs.
- Obtiene los planes de energía actualmente instalados (independiente del idioma).
- Restaura los planes faltantes usando `powercfg -duplicatescheme`.
- Informa el estado de cada plan tras la ejecución.
- Devuelve siempre código de salida 0.

-----------------------------------------------------------------------------------------------------
INSTRUCCIONES DE USO
-----------------------------------------------------------------------------------------------------
- Ejecutar con permisos SYSTEM para garantizar restauración correcta.
- Usar como script de remediación en Intune o sistemas similares.

-----------------------------------------------------------------------------------------------------
AUTOR: Alejandro Suárez (@alexsf93)
=====================================================================================================
#>

# Detener en errores no controlados dentro de los try/catch
$ErrorActionPreference = 'Stop'

# Lista de planes: GUID y nombre
$powerPlans = @(
    @{ Name = "Balanced";         GUID = "381b4222-f694-41f0-9685-ff5bb260df2e" }
    @{ Name = "High Performance"; GUID = "8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c" }
    @{ Name = "Power Saver";      GUID = "a1841308-3541-4fab-bc81-f71556f20b4a" }
)

# Regex para extraer GUIDs (independiente del idioma de la salida)
$guidRegex = '[0-9a-fA-F]{8}(-[0-9a-fA-F]{4}){3}-[0-9a-fA-F]{12}'

# Obtener GUIDs de planes existentes
$existingGUIDs = powercfg /list |
    Select-String -Pattern $guidRegex -AllMatches |
    ForEach-Object { $_.Matches.Value.ToLowerInvariant() } |
    Select-Object -Unique

foreach ($plan in $powerPlans) {
    $planGuidLower = $plan.GUID.ToLowerInvariant()
    if ($existingGUIDs -notcontains $planGuidLower) {
        try {
            powercfg -duplicatescheme $plan.GUID | Out-Null
            Write-Output "Plan restaurado: $($plan.Name)"
        } catch {
            Write-Output "Error restaurando $($plan.Name): $($_.Exception.Message)"
        }
    } else {
        Write-Output "Plan ya presente: $($plan.Name)"
    }
}

exit 0
