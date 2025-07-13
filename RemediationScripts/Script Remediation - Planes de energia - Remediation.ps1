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
- Define los planes estándar con sus GUIDs y comandos para restaurarlos.
- Obtiene los planes de energía actualmente instalados.
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

# Lista de planes: GUID, nombre, comando para restaurar
$powerPlans = @(
    @{ Name = "Balanced";        GUID = "381b4222-f694-41f0-9685-ff5bb260df2e"; Command = { powercfg -duplicatescheme $_.GUID } },
    @{ Name = "High Performance"; GUID = "8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c"; Command = { powercfg -duplicatescheme $_.GUID } },
    @{ Name = "Power Saver";      GUID = "a1841308-3541-4fab-bc81-f71556f20b4a"; Command = { powercfg -duplicatescheme $_.GUID } }
)

# Obtener GUIDs de planes existentes
$existingGUIDs = powercfg /list | Select-String "Power Scheme GUID" | ForEach-Object {
    ($_ -split ":")[1].Trim().Split()[0]
}

foreach ($plan in $powerPlans) {
    if ($plan.GUID -notin $existingGUIDs) {
        try {
            & $plan.Command.Invoke($plan)
            Write-Output "✅ Plan restaurado: $($plan.Name)"
        } catch {
            Write-Output "❌ Error restaurando $($plan.Name): $_"
        }
    } else {
        Write-Output "✔️ Plan ya presente: $($plan.Name)"
    }
}

exit 0
