<#
=====================================================================================================
    REMEDIATION SCRIPT: RESTAURACIÓN DE PLANES DE ENERGÍA HABITUALES EN WINDOWS
-----------------------------------------------------------------------------------------------------
Este script restaura los planes de energía estándar de Windows si alguno no está presente:
- Equilibrado (Balanced)
- Alto rendimiento (High Performance)
- Economizador (Power Saver)

Está diseñado para ejecutarse con privilegios SYSTEM (por ejemplo, vía Intune Remediations) y asegurar
que los planes de energía estándar estén disponibles en el sistema.

-----------------------------------------------------------------------------------------------------
REQUISITOS
-----------------------------------------------------------------------------------------------------
- PowerShell 5.1 o 7.x.
- Ejecución como SYSTEM o administrador local.
- Herramienta `powercfg` disponible (Windows).

-----------------------------------------------------------------------------------------------------
¿CÓMO FUNCIONA?
-----------------------------------------------------------------------------------------------------
- Define los planes estándar con sus GUIDs.
- Obtiene los planes de energía instalados (independiente del idioma mediante regex).
- Restaura los planes faltantes con `powercfg -duplicatescheme`.
- Informa en la salida el estado de cada plan.

-----------------------------------------------------------------------------------------------------
RESULTADOS
-----------------------------------------------------------------------------------------------------
- "OK" (exit code 0) → Planes estándar presentes o restaurados correctamente.
- Mensajes en salida estándar → Indican “Plan restaurado” / “Plan ya presente” / “Error restaurando …”.

-----------------------------------------------------------------------------------------------------
INSTRUCCIONES DE USO
-----------------------------------------------------------------------------------------------------
- Ejecutar como Remediation Script en Intune u otros sistemas de gestión.
- Revisar la salida estándar para confirmar la restauración de cada plan.
- El script devuelve siempre exit code 0.

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
