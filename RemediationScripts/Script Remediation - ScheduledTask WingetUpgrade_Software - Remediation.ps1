<#
=====================================================================================================
    SCRIPT: CREAR TAREA PROGRAMADA PARA WINGET UPGRADE (OCULTA, VIERNES 12:00)
-----------------------------------------------------------------------------------------------------
Crea o actualiza la tarea "ScheduledTask-Inkoova-WingetUpgradeSoftware" que ejecuta:

winget upgrade --all --silent --accept-source-agreements --accept-package-agreements --disable-interactivity

Ejecuta en el contexto del usuario logeado, cada viernes a las 12:00,
sin mostrar ventana, y guarda la salida en: C:\Winget_Upgrade.log
=====================================================================================================
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$TaskName = 'ScheduledTask-Inkoova-WingetUpgradeSoftware'
$LogPath  = 'C:\Winget_Upgrade.log'

# Comando PowerShell que se ejecutará de forma oculta
$PsCommand = @"
`$Date = (Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
Add-Content -Path '$LogPath' -Value "`$Date"
winget upgrade --all --silent --accept-source-agreements --accept-package-agreements --disable-interactivity |
    Out-File -FilePath '$LogPath' -Append -Encoding UTF8
"@

# Argumentos del proceso PowerShell (modo oculto)
$PsArgs = "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -Command `$ErrorActionPreference='Stop'; $PsCommand"

# Acción: lanzar PowerShell oculto
$Action = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument $PsArgs

# Trigger: todos los viernes a las 12:00
$Trigger = New-ScheduledTaskTrigger -Weekly -DaysOfWeek Friday -At '12:00'

# Principal: todos los usuarios (BUILTIN\Users) con privilegios elevados
$Principal = New-ScheduledTaskPrincipal -GroupId 'S-1-5-32-545' -RunLevel Highest

# Configuración de la tarea
$Settings = New-ScheduledTaskSettingsSet `
  -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable `
  -MultipleInstances IgnoreNew -ExecutionTimeLimit (New-TimeSpan -Hours 6) -Hidden

# Crear o actualizar la tarea
try {
    if (Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue) {
        Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false | Out-Null
    }

    Register-ScheduledTask -TaskName $TaskName -Action $Action -Trigger $Trigger `
      -Settings $Settings -Principal $Principal | Out-Null

    Write-Host "Tarea '$TaskName' creada o actualizada correctamente."
    Write-Host "Se ejecutará cada viernes a las 12:00 sin mostrar ventana."
    Write-Host "El resultado se guardará en: $LogPath"
    exit 0
}
catch {
    Write-Host "ERROR: No se pudo crear la tarea '$TaskName': $($_.Exception.Message)"
    exit 1
}
