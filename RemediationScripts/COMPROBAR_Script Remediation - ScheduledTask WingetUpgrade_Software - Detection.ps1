<#
=====================================================================================================
    DETECTION SCRIPT: EXISTENCIA DE TAREA PROGRAMADA + SYSTEM + SCRIPT PRESENTE
-----------------------------------------------------------------------------------------------------
Este script verifica la presencia y configuración mínima de la tarea programada
**ScheduledTask-Inkoova-WingetUpgradeSoftware**, comprobando que exista, que se
ejecute bajo la cuenta SYSTEM y que el script objetivo esté presente en la ruta indicada.

-----------------------------------------------------------------------------------------------------
REQUISITOS
-----------------------------------------------------------------------------------------------------
- PowerShell 5.1 o 7.x.
- Permisos para consultar tareas programadas y el sistema de archivos.
- Nombre de tarea y ruta del script objetivo definidos en el propio script.

-----------------------------------------------------------------------------------------------------
¿CÓMO FUNCIONA?
-----------------------------------------------------------------------------------------------------
- Busca la tarea programada por nombre.
- Valida que el principal de la tarea sea SYSTEM.
- Comprueba que el archivo de script exista en `C:\ProgramData\Inkoova\WingetUpgradeSoftware.ps1`.
- Devuelve:
  * Exit code 0 → Todo conforme.
  * Exit code 1 → Falta la tarea, el principal no es SYSTEM o el script no existe.

-----------------------------------------------------------------------------------------------------
RESULTADOS
-----------------------------------------------------------------------------------------------------
- "OK" (exit code 0) → La tarea existe, corre como SYSTEM y el script está presente.
- "NOK" (exit code 1) → No se cumple alguna de las condiciones anteriores.

-----------------------------------------------------------------------------------------------------
INSTRUCCIONES DE USO
-----------------------------------------------------------------------------------------------------
- Usar como Detection Rule en Intune u otros sistemas de compliance.
- Ajustar `$TaskName` y `$ScriptTarget` si fuese necesario para otros casos.
- Interpretar el exit code para decidir la aplicación de remediación.

-----------------------------------------------------------------------------------------------------
AUTOR: Alejandro Suárez (@alexsf93)
=====================================================================================================
#>

[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# --- Parámetros mínimos ---
$TaskName     = 'ScheduledTask-Inkoova-WingetUpgradeSoftware'
$ScriptTarget = 'C:\ProgramData\Inkoova\WingetUpgradeSoftware.ps1'

# 1) La tarea existe
try {
    $task = Get-ScheduledTask -TaskName $TaskName -ErrorAction Stop
} catch {
    Write-Host "No existe la tarea '$TaskName'."
    exit 1
}

# 2) Corre como SYSTEM
$uid = [string]$task.Principal.UserId
if (@('SYSTEM','NT AUTHORITY\SYSTEM') -notcontains $uid) {
    Write-Host "Principal no conforme: se esperaba SYSTEM y es '$uid'."
    exit 1
}

# 3) Existe el script en ProgramData
if (-not (Test-Path -LiteralPath $ScriptTarget)) {
    Write-Host "El script objetivo no existe: $ScriptTarget"
    exit 1
}

# Conforme
Write-Host "OK: '$TaskName' existe, corre como SYSTEM y el script está presente."
exit 0
