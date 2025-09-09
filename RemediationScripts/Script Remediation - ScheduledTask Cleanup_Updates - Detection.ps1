<#
===============================================================================================
 DETECCIÓN: ¿EXISTE Y ESTÁ CORRECTA LA TAREA "ScheduledTask-Inkoova-CleanUpdates"?
-----------------------------------------------------------------------------------------------
Este script detecta si la tarea programada "ScheduledTask-Inkoova-CleanUpdates"
existe y está configurada correctamente (para Intune PR o compliance).
Autor: Alejandro Suárez (@alexsf93)
===============================================================================================
#>

[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$TaskName     = 'ScheduledTask-Inkoova-CleanUpdates'
$ExpectedDay  = 'Friday'
$ExpectedHour = 11
$ExpectedMin  = 0
$ScriptTarget = 'C:\ProgramData\Inkoova\CleanUpdates.ps1'

# 1) Obtener la tarea
try {
    $task = Get-ScheduledTask -TaskName $TaskName -ErrorAction Stop
} catch {
    Write-Host "No existe la tarea '$TaskName'."
    exit 1
}

# 2) Validar principal (SYSTEM + RunLevel Highest)
$uid = $task.Principal.UserId
$run = $task.Principal.RunLevel
if (@('SYSTEM','NT AUTHORITY\SYSTEM') -notcontains $uid -or $run -ne 'Highest') {
    Write-Host "Principal no conforme."
    exit 1
}

# 3) Validar trigger semanal (viernes 11:00) y habilitado
$triggers = $task.Triggers | Where-Object Enabled
if (-not $triggers) {
    Write-Host "La tarea no tiene triggers habilitados."
    exit 1
}

$weeklyOk = $false
foreach ($t in $triggers) {
    if ($t.TriggerType -ne 'Weekly') { continue }
    if ($t.DaysOfWeek -notmatch $ExpectedDay) { continue }

    $time = if ($t.PSObject.Properties.Name -contains 'At') {
        if ($t.At -is [datetime]) { $t.At.TimeOfDay }
        elseif ($t.At -is [timespan]) { $t.At }
        else { $null }
    } else {
        try { ([datetime]$t.StartBoundary).TimeOfDay } catch { $null }
    }

    if ($null -ne $time -and $time.Hours -eq $ExpectedHour -and $time.Minutes -eq $ExpectedMin) {
        $weeklyOk = $true
        break
    }
}
if (-not $weeklyOk) {
    Write-Host "Trigger no conforme."
    exit 1
}

# 4) Validar acción (powershell.exe + CleanUpdates.ps1 + -RunCleanup)
$act = $task.Actions | Select-Object -First 1
if (-not $act) {
    Write-Host "Acción no definida."
    exit 1
}

$exeOk   = $act.Execute -match '(?i)powershell\.exe$'
$args    = [string]$act.Arguments
$hasFile = $args -match '(?i)CleanUpdates\.ps1'
$hasRun  = $args -match '(?i)\-RunCleanup(\s|$)'
if (-not ($exeOk -and $hasFile -and $hasRun)) {
    Write-Host "Acción no conforme."
    exit 1
}

# 5) Validar existencia del script objetivo
if (-not (Test-Path $ScriptTarget)) {
    Write-Host "El script objetivo no existe: $ScriptTarget"
    exit 1
}

# 6) Conforme
Write-Host "OK: '$TaskName' existe y está correctamente configurada."
exit 0
