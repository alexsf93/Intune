<#
===============================================================================================
 DETECCIÓN MÍNIMA: existencia de la tarea y que corra como SYSTEM + script presente
-----------------------------------------------------------------------------------------------
- Tarea: ScheduledTask-Inkoova-CleanUpdates
- Principal: SYSTEM
- Script: C:\ProgramData\Inkoova\CleanUpdates.ps1
===============================================================================================
#>

[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# --- Parámetros mínimos ---
$TaskName    = 'ScheduledTask-Inkoova-CleanUpdates'
$ScriptTarget= 'C:\ProgramData\Inkoova\CleanUpdates.ps1'

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

# (Opcional) Si también quieres exigir RunLevel Highest, descomenta:
# if ([string]$task.Principal.RunLevel -ne 'Highest') {
#     Write-Host "RunLevel no conforme: se esperaba 'Highest'."
#     exit 1
# }

# 3) Existe el script en ProgramData
if (-not (Test-Path -LiteralPath $ScriptTarget)) {
    Write-Host "El script objetivo no existe: $ScriptTarget"
    exit 1
}

# Conforme
Write-Host "OK: '$TaskName' existe, corre como SYSTEM y el script está presente."
exit 0
