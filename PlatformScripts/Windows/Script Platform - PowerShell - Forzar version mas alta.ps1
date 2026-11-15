<#
.SYNOPSIS
    Deteccion y forzado de la version mas alta de PowerShell en Windows para Intune.

.DESCRIPTION
    Este script esta disenado para ejecutarse como Platform Script en Microsoft Intune bajo contexto SYSTEM
    o manualmente por un administrador desde PowerShell ISE.
    
    Realiza las siguientes acciones:
    1. Detecta todas las instalaciones de PowerShell en el equipo (MSI, Win32, AppX y Windows PowerShell 5.1).
    2. Determina de forma precisa la version mas alta disponible sin falsos positivos de compilacion de Windows.
    3. Elimina versiones intermedias obsoletas de PowerShell 7 (MSI), manteniendo unicamente PowerShell 5.1 y la mas reciente.
    4. Limpia los accesos directos obsoletos de 32 bits (x86) para evitar duplicados y confusion en la busqueda de Windows.
    5. Actualiza los accesos directos del sistema y de los perfiles de usuario garantizando el icono corporativo nativo.
    6. Antepone el directorio de la version mas alta a la variable de entorno PATH (Sistema y Usuario) y notifica al shell en caliente.
    7. Configura Windows Terminal para establecer la version moderna como perfil predeterminado.
    8. Dispone de modo simulacion (-DryRun) y sistema de reversion de accesos directos (-Restore).

.PARAMETER DryRun
    Ejecuta el script en modo de simulacion (solo lectura), detallando las acciones sin realizar cambios en el sistema.

.PARAMETER Force
    Aplica todos los cambios de forma desatendida sin solicitar confirmacion interactiva (requerido para despliegues de Intune).

.PARAMETER Restore
    Restaura los accesos directos originales desde la ultima copia de seguridad guardada.

.PARAMETER IconStyle
    Define el estilo del icono del acceso directo. Opciones: 'ClassicBlue' (icono azul tradicional de Windows PowerShell) o 'PowerShell7' (icono oscuro oficial). Por defecto: ClassicBlue.

.PARAMETER RemoveX86Shortcuts
    Elimina los accesos directos obsoletos de Windows PowerShell (x86) de los perfiles de usuario y Menu Inicio. Por defecto: $true.

.PARAMETER RemoveIntermediateVersions
    Desinstala versiones intermedias obsoletas de PowerShell 7.x dejando solo la 5.1 y la mas alta. Por defecto: $true.

.PARAMETER IncludeISE
    Si se especifica, actualiza tambien el acceso directo de Windows PowerShell ISE. Por defecto: $false para preservar el entorno de desarrollo.

.PARAMETER UpdateTerminal
    Si se detecta Windows Terminal, establece la version mas alta de PowerShell como perfil predeterminado. Por defecto: $true.

.EXAMPLE
    .\Script Platform - PowerShell - Forzar version mas alta.ps1

.EXAMPLE
    .\Script Platform - PowerShell - Forzar version mas alta.ps1 -Force -IconStyle ClassicBlue

.EXAMPLE
    powershell.exe -ExecutionPolicy Bypass -File ".\Script Platform - PowerShell - Forzar version mas alta.ps1" -Force

.EXAMPLE
    .\Script Platform - PowerShell - Forzar version mas alta.ps1 -Restore

.NOTES
    Name:       Script Platform - PowerShell - Forzar version mas alta.ps1
    Author:     Alejandro Suarez (@alexsf93)
    Date:       2026-11-14
    Version:    1.2.0
#>

[CmdletBinding(SupportsShouldProcess = $true)]
param (
    [switch]$DryRun,
    [switch]$Force,
    [switch]$Restore,
    [switch]$IncludeISE = $false,
    [switch]$UpdateTerminal = $true,
    [switch]$RemoveX86Shortcuts = $true,
    [switch]$RemoveIntermediateVersions = $true,
    [ValidateSet('ClassicBlue', 'PowerShell7')]
    [string]$IconStyle = 'ClassicBlue',
    [string]$BackupDirectory = (Join-Path $env:ProgramData 'PowerShellUpgrade\Backups'),
    [string]$LogDirectory    = (Join-Path $env:ProgramData 'PowerShellUpgrade\Logs')
)

$ErrorActionPreference = 'Stop'
$ScriptVersion = "1.2.0"
$Timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"

# Configuracion de carpetas de soporte y log
if (-not (Test-Path -Path $LogDirectory)) {
    New-Item -ItemType Directory -Path $LogDirectory -Force | Out-Null
}
$LogFile = Join-Path -Path $LogDirectory "PowerShell_Upgrade_$Timestamp.log"

function Write-Log {
    param (
        [Parameter(Mandatory = $true)]
        [string]$Message,
        [ValidateSet('INFO', 'SUCCESS', 'WARN', 'ERROR', 'DRYRUN')]
        [string]$Level = 'INFO'
    )

    $timeStr = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logLine = "[$timeStr] [$Level] $Message"

    switch ($Level) {
        'INFO'    { Write-Host "[$Level] " -ForegroundColor Cyan -NoNewline; Write-Host $Message }
        'SUCCESS' { Write-Host "[$Level] " -ForegroundColor Green -NoNewline; Write-Host $Message }
        'WARN'    { Write-Host "[$Level] " -ForegroundColor Yellow -NoNewline; Write-Host $Message }
        'ERROR'   { Write-Host "[$Level] " -ForegroundColor Red -NoNewline; Write-Host $Message }
        'DRYRUN'  { Write-Host "[$Level] " -ForegroundColor Magenta -NoNewline; Write-Host $Message }
    }

    try {
        Add-Content -Path $LogFile -Value $logLine -Encoding UTF8 -ErrorAction SilentlyContinue
    } catch {}
}

function Test-IsAdminOrSystemOrSystem {
    try {
        $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
        if ($identity.IsSystem) { return $true }
        $principal = New-Object Security.Principal.WindowsPrincipal($identity)
        return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    } catch {
        return $false
    }
}

function Get-RealUserProfiles {
    $profiles = [System.Collections.Generic.List[string]]::new()
    try {
        Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList\*" `
            -ErrorAction SilentlyContinue | Where-Object {
                $_.ProfileImagePath -like "C:\Users\*" -and
                $_.ProfileImagePath -notmatch '\\(Public|All Users|Default|Default User)$'
            } | ForEach-Object {
                if (Test-Path $_.ProfileImagePath) {
                    $profiles.Add($_.ProfileImagePath)
                }
            }
    } catch {}

    if ($profiles.Count -eq 0) {
        Get-ChildItem -Path "C:\Users" -Directory -ErrorAction SilentlyContinue | Where-Object {
            $_.Name -notmatch '^(Public|All Users|Default|Default User)$'
        } | ForEach-Object {
            $profiles.Add($_.FullName)
        }
    }
    return $profiles
}

# --- 1. Deteccion de versiones instaladas de PowerShell ---
function Get-InstalledPowerShellVersions {
    Write-Log "Buscando versiones de PowerShell instaladas en el equipo..." 'INFO'
    $detected = [System.Collections.Generic.List[PSCustomObject]]::new()

    # 1.1. Rutas estandar en Program Files (MSI / Win32)
    $searchPaths = @(
        "$env:ProgramFiles\PowerShell\*\pwsh.exe",
        "${env:ProgramFiles(x86)}\PowerShell\*\pwsh.exe",
        "$env:LOCALAPPDATA\Programs\PowerShell\*\pwsh.exe"
    )

    foreach ($path in $searchPaths) {
        Get-Item -Path $path -ErrorAction SilentlyContinue | ForEach-Object {
            $exePath = $_.FullName
            $vStr = if ($_.VersionInfo.FileVersion) { $_.VersionInfo.FileVersion } else { $_.VersionInfo.ProductVersion }

            if ($vStr -match '^(\d+(\.\d+){1,3})') {
                $parsedVer = [System.Version]$Matches[1]
                $detected.Add([PSCustomObject]@{
                    Version        = $parsedVer
                    DisplayVersion = $vStr.Trim()
                    ExecutablePath = $exePath
                    Directory      = $_.DirectoryName
                    IconSource     = $exePath
                    InstallType    = "PowerShell Core (MSI/Win32)"
                })
                Write-Log "Localizado MSI/Win32: $exePath (v$parsedVer)" 'INFO'
            }
        }
    }

    # 1.2. Registro de PowerShell Core
    $regKeys = @(
        "HKLM:\SOFTWARE\Microsoft\PowerShellCore\InstalledVersions",
        "HKLM:\SOFTWARE\WOW6432Node\Microsoft\PowerShellCore\InstalledVersions"
    )
    foreach ($regKey in $regKeys) {
        if (Test-Path -Path $regKey) {
            Get-ChildItem -Path $regKey -ErrorAction SilentlyContinue | ForEach-Object {
                $dir = (Get-ItemProperty -Path $_.PSPath -Name "InstallDir" -ErrorAction SilentlyContinue).InstallDir
                if ($dir) {
                    $exe = Join-Path $dir "pwsh.exe"
                    if ((Test-Path $exe) -and (-not ($detected | Where-Object { $_.ExecutablePath -ieq $exe }))) {
                        $item = Get-Item -Path $exe
                        $vStr = $item.VersionInfo.FileVersion
                        if ($vStr -match '^(\d+(\.\d+){1,3})') {
                            $parsedVer = [System.Version]$Matches[1]
                            $detected.Add([PSCustomObject]@{
                                Version        = $parsedVer
                                DisplayVersion = $vStr
                                ExecutablePath = $exe
                                Directory      = $item.DirectoryName
                                IconSource     = $exe
                                InstallType    = "PowerShell Core (Registry)"
                            })
                            Write-Log "Localizado Registro: $exe (v$parsedVer)" 'INFO'
                        }
                    }
                }
            }
        }
    }

    # 1.3. Paquetes AppX / Store
    try {
        Get-AppxPackage -AllUsers -Name "*PowerShell*" -ErrorAction SilentlyContinue | ForEach-Object {
            $appxExe = Join-Path $_.InstallLocation "pwsh.exe"
            if (Test-Path $appxExe) {
                if ($_.Version -match '^(\d+(\.\d+){1,3})') {
                    $parsedVer = [System.Version]$Matches[1]
                    $detected.Add([PSCustomObject]@{
                        Version        = $parsedVer
                        DisplayVersion = $_.Version
                        ExecutablePath = $appxExe
                        Directory      = Split-Path $appxExe -Parent
                        IconSource     = $appxExe
                        InstallType    = "PowerShell Core (AppX/Store)"
                    })
                    Write-Log "Localizado AppX/Store: $appxExe (v$parsedVer)" 'INFO'
                }
            }
        }
    } catch {}

    # 1.4. Windows PowerShell 5.1 integrado en el sistema
    $winPS = Join-Path $env:SystemRoot "System32\WindowsPowerShell\v1.0\powershell.exe"
    if (Test-Path $winPS) {
        # Se obtiene la version real del motor en registro para evitar el build number 10.0 de Win 10/11
        $psVerStr = (Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\PowerShell\3\PowerShellEngine" -Name "PowerShellVersion" -ErrorAction SilentlyContinue).PowerShellVersion
        if (-not $psVerStr) { $psVerStr = "5.1.0" }

        if ($psVerStr -match '^(\d+(\.\d+){1,3})') {
            $parsedVer = [System.Version]$Matches[1]
            $detected.Add([PSCustomObject]@{
                Version        = $parsedVer
                DisplayVersion = $psVerStr
                ExecutablePath = $winPS
                Directory      = Split-Path $winPS -Parent
                IconSource     = $winPS
                InstallType    = "Windows PowerShell (5.1 Integrado)"
            })
            Write-Log "Localizado Windows PowerShell integrado: $winPS (v$parsedVer)" 'INFO'
        }
    }

    return ($detected | Sort-Object -Property Version -Descending)
}

# --- 2. Desinstalacion de versiones intermedias obsoletas ---
function Remove-IntermediatePowerShellVersions {
    param (
        [Parameter(Mandatory = $true)]
        [System.Version]$HighestVersion,
        [switch]$DryRun
    )

    Write-Log "Verificando versiones intermedias de PowerShell anteriores a v$HighestVersion..." 'INFO'
    $regPaths = @(
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*",
        "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*"
    )
    $found = $false

    foreach ($path in $regPaths) {
        Get-ItemProperty $path -ErrorAction SilentlyContinue | Where-Object {
            $_.DisplayName -match '^PowerShell\s+\d+(\.\d+)?' -and $_.UninstallString
        } | ForEach-Object {
            $vStr = $_.DisplayVersion
            if ($vStr -match '^(\d+(\.\d+){1,3})') {
                $instVer = [System.Version]$Matches[1]
                if ($instVer -lt $HighestVersion) {
                    $found = $true
                    $name = $_.DisplayName
                    $code = $_.PSChildName
                    Write-Log "Version intermedia detectada para desinstalar: $name (v$instVer)" 'WARN'

                    if ($DryRun) {
                        Write-Log "[SIMULACION] Se desinstalaria: $name (ProductCode: $code)" 'DRYRUN'
                    } else {
                        try {
                            Write-Log "Ejecutando desinstalacion silenciosa de $name..." 'INFO'
                            $proc = Start-Process -FilePath "msiexec.exe" -ArgumentList "/x $code /qn /norestart" -Wait -PassThru
                            if ($proc.ExitCode -eq 0) {
                                Write-Log "Desinstalacion correcta: $name" 'SUCCESS'
                            } else {
                                Write-Log "Aviso: msiexec finalizo con codigo $($proc.ExitCode) para $name" 'WARN'
                            }
                        } catch {
                            Write-Log "Error al desinstalar $name`: $($_.Exception.Message)" 'ERROR'
                        }
                    }
                }
            }
        }
    }

    if (-not $found) {
        Write-Log "No existen versiones intermedias para desinstalar." 'INFO'
    }

    # Desactivar motor heredado e inseguro PowerShell 2.0 si se ejecuta con permisos de administrador
    if (Test-IsAdminOrSystem) {
        try {
            $ps2 = Get-WindowsOptionalFeature -Online -FeatureName "MicrosoftWindowsPowerShellV2Root" -ErrorAction SilentlyContinue
            if ($ps2 -and $ps2.State -eq 'Enabled') {
                if ($DryRun) {
                    Write-Log "[SIMULACION] Se deshabilitaria la caracteristica obsoleta PowerShell 2.0." 'DRYRUN'
                } else {
                    Write-Log "Deshabilitando caracteristica obsoleta PowerShell 2.0..." 'INFO'
                    Disable-WindowsOptionalFeature -Online -FeatureName "MicrosoftWindowsPowerShellV2Root" -NoRestart -ErrorAction SilentlyContinue | Out-Null
                    Write-Log "PowerShell 2.0 deshabilitado correctamente." 'SUCCESS'
                }
            }
        } catch {}
    }
}

# --- 3. Limpieza de accesos directos x86 obsoletos ---
function Remove-PowerShellX86Shortcuts {
    param (
        [switch]$DryRun
    )

    Write-Log "Comprobando y limpiando accesos directos obsoletos x86..." 'INFO'
    $searchDirs = [System.Collections.Generic.List[string]]::new()
    $searchDirs.Add("$env:ProgramData\Microsoft\Windows\Start Menu\Programs")
    $searchDirs.Add("$env:PUBLIC\Desktop")

    Get-RealUserProfiles | ForEach-Object {
        $searchDirs.Add((Join-Path $_ "AppData\Roaming\Microsoft\Windows\Start Menu\Programs"))
        $searchDirs.Add((Join-Path $_ "Desktop"))
    }

    $uniqueDirs = $searchDirs | Where-Object { Test-Path -Path $_ } | Select-Object -Unique

    foreach ($dir in $uniqueDirs) {
        Get-ChildItem -Path $dir -Filter "*powershell*x86*.lnk" -Recurse -ErrorAction SilentlyContinue | ForEach-Object {
            if ($_.Name -match '(?i)ISE' -and -not $IncludeISE) { return }

            $lnkPath = $_.FullName
            if ($DryRun) {
                Write-Log "[SIMULACION] Se eliminaria acceso directo x86: $lnkPath" 'DRYRUN'
            } else {
                try {
                    if (-not (Test-Path -Path $BackupDirectory)) {
                        New-Item -ItemType Directory -Path $BackupDirectory -Force | Out-Null
                    }
                    $bakFile = Join-Path $BackupDirectory ("DELETED_" + $_.Name + "_" + ([Guid]::NewGuid().ToString().Substring(0,8)) + ".bak")
                    Copy-Item -Path $lnkPath -Destination $bakFile -Force
                    Add-Content -Path (Join-Path $BackupDirectory "backup_index.txt") -Value "$lnkPath|$bakFile" -Encoding UTF8

                    Remove-Item -Path $lnkPath -Force
                    Write-Log "Acceso directo x86 eliminado: $lnkPath" 'SUCCESS'
                } catch {
                    Write-Log "Aviso al eliminar acceso directo ($($lnkPath)): $($_.Exception.Message)" 'WARN'
                }
            }
        }
    }
}

# --- 4. Busqueda de accesos directos candidatos a redirigir ---
function Get-PowerShellShortcuts {
    param (
        [switch]$IncludeISE
    )

    $wshShell = New-Object -ComObject WScript.Shell
    $shortcutList = [System.Collections.Generic.List[PSCustomObject]]::new()
    $candidateFolders = [System.Collections.Generic.List[string]]::new()

    $candidateFolders.Add("$env:ProgramData\Microsoft\Windows\Start Menu\Programs")
    $candidateFolders.Add("$env:PUBLIC\Desktop")

    Get-RealUserProfiles | ForEach-Object {
        $userBase = $_
        $candidateFolders.Add((Join-Path $userBase "AppData\Roaming\Microsoft\Windows\Start Menu\Programs"))
        $candidateFolders.Add((Join-Path $userBase "Desktop"))
        $candidateFolders.Add((Join-Path $userBase "AppData\Roaming\Microsoft\Internet Explorer\Quick Launch\User Pinned\TaskBar"))
    }

    $uniqueFolders = $candidateFolders | Where-Object { Test-Path -Path $_ } | Select-Object -Unique

    foreach ($folder in $uniqueFolders) {
        Get-ChildItem -Path $folder -Filter "*.lnk" -Recurse -ErrorAction SilentlyContinue | ForEach-Object {
            try {
                $shortcut = $wshShell.CreateShortcut($_.FullName)
                $target = $shortcut.TargetPath

                if ($target -match '(?i)(powershell\.exe|pwsh\.exe)$') {
                    $isISE = ($_.Name -match '(?i)ISE') -or ($target -match '(?i)powershell_ise\.exe')

                    if ($isISE -and -not $IncludeISE) {
                        Write-Log "Conservando acceso directo de ISE: $($_.FullName)" 'INFO'
                        return
                    }

                    $shortcutList.Add([PSCustomObject]@{
                        FileInfo       = $_
                        FullPath       = $_.FullName
                        Name           = $_.Name
                        CurrentTarget  = $target
                        CurrentIcon    = $shortcut.IconLocation
                    })
                }
            } catch {}
        }
    }

    return $shortcutList
}

# --- 5. Actualizacion de accesos directos ---
function Update-PowerShellShortcutItem {
    param (
        [Parameter(Mandatory = $true)]
        [PSCustomObject]$ShortcutInfo,
        [Parameter(Mandatory = $true)]
        [PSCustomObject]$TargetPowerShell,
        [string]$IconStyle = 'ClassicBlue',
        [switch]$DryRun
    )

    $lnkPath = $ShortcutInfo.FullPath
    $wshShell = New-Object -ComObject WScript.Shell
    $newTarget = $TargetPowerShell.ExecutablePath

    # Resolucion del icono para garantizar que siempre se muestre nitido
    $newIcon = if ($IconStyle -eq 'ClassicBlue') {
        Join-Path $env:SystemRoot "System32\WindowsPowerShell\v1.0\powershell.exe,0"
    } else {
        if ($TargetPowerShell.IconSource -match '(?i)WindowsApps') {
            $extractedIco = Join-Path $env:ProgramData "PowerShellUpgrade\pwsh7.ico"
            if (-not (Test-Path $extractedIco)) {
                try {
                    Add-Type -AssemblyName System.Drawing -ErrorAction SilentlyContinue
                    $iconObj = [System.Drawing.Icon]::ExtractAssociatedIcon($TargetPowerShell.IconSource)
                    if ($iconObj) {
                        $fs = New-Object System.IO.FileStream($extractedIco, [System.IO.FileMode]::Create)
                        $iconObj.Save($fs)
                        $fs.Close()
                    }
                } catch {}
            }
            if (Test-Path $extractedIco) { "$extractedIco,0" } else { Join-Path $env:SystemRoot "System32\WindowsPowerShell\v1.0\powershell.exe,0" }
        } else {
            "$($TargetPowerShell.IconSource),0"
        }
    }

    if ($DryRun) {
        Write-Log "[SIMULACION] Acceso directo: $lnkPath" 'DRYRUN'
        Write-Log "  Target actual: '$($ShortcutInfo.CurrentTarget)' --> Nuevo: '$newTarget'" 'DRYRUN'
        Write-Log "  Icono actual:  '$($ShortcutInfo.CurrentIcon)'   --> Nuevo: '$newIcon'" 'DRYRUN'
        return
    }

    try {
        if (-not (Test-Path -Path $BackupDirectory)) {
            New-Item -ItemType Directory -Path $BackupDirectory -Force | Out-Null
        }
        $backupName = [System.IO.Path]::GetFileNameWithoutExtension($lnkPath) + "_" + ([Guid]::NewGuid().ToString().Substring(0,8)) + ".lnk.bak"
        $backupDest = Join-Path $BackupDirectory $backupName
        Copy-Item -Path $lnkPath -Destination $backupDest -Force
        Add-Content -Path (Join-Path $BackupDirectory "backup_index.txt") -Value "$lnkPath|$backupDest" -Encoding UTF8

        $shortcut = $wshShell.CreateShortcut($lnkPath)
        $shortcut.TargetPath       = $newTarget
        $shortcut.WorkingDirectory = "%USERPROFILE%"
        $shortcut.IconLocation     = $newIcon
        $shortcut.Save()

        Write-Log "Actualizado correctamente: $lnkPath" 'SUCCESS'
    } catch {
        Write-Log "Error al actualizar acceso directo ($($lnkPath)): $($_.Exception.Message)" 'ERROR'
    }
}

# --- 6. Actualizacion de variables de entorno PATH ---
function Update-EnvironmentVariables {
    param (
        [Parameter(Mandatory = $true)]
        [PSCustomObject]$TargetPowerShell,
        [switch]$DryRun
    )

    $targetDir = $TargetPowerShell.Directory
    Write-Log "Actualizando variable PATH con el directorio: $targetDir" 'INFO'

    # PATH de Sistema (Machine)
    if (Test-IsAdminOrSystem) {
        try {
            $machinePath = [Environment]::GetEnvironmentVariable("Path", [EnvironmentVariableTarget]::Machine)
            $entries = $machinePath -split ';' | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
            $filtered = @($entries | Where-Object { $_.TrimEnd('\') -ine $targetDir.TrimEnd('\') })
            $newMachinePath = ($targetDir, $filtered) -join ';'

            if ($DryRun) {
                Write-Log "[SIMULACION] Se antepondra '$targetDir' al PATH del Sistema." 'DRYRUN'
            } else {
                [Environment]::SetEnvironmentVariable("Path", $newMachinePath, [EnvironmentVariableTarget]::Machine)
                Write-Log "PATH del Sistema actualizado con exito." 'SUCCESS'
            }
        } catch {
            Write-Log "Error al actualizar PATH del Sistema: $($_.Exception.Message)" 'ERROR'
        }
    }

    # PATH de Usuario (solo se aplica en ejecucion interactiva de usuario, no bajo SYSTEM)
    $isSystem = [Security.Principal.WindowsIdentity]::GetCurrent().IsSystem
    if (-not $isSystem) {
        try {
            $userPath = [Environment]::GetEnvironmentVariable("Path", [EnvironmentVariableTarget]::User)
            $userEntries = $userPath -split ';' | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
            $filteredUser = @($userEntries | Where-Object { $_.TrimEnd('\') -ine $targetDir.TrimEnd('\') })
            $newUserPath = (@($targetDir) + $filteredUser) -join ';'

            if ($DryRun) {
                Write-Log "[SIMULACION] Se antepondra '$targetDir' al PATH del Usuario." 'DRYRUN'
            } else {
                [Environment]::SetEnvironmentVariable("Path", $newUserPath, [EnvironmentVariableTarget]::User)
                Write-Log "PATH del Usuario actualizado con exito." 'SUCCESS'
            }
        } catch {
            Write-Log "Error al actualizar PATH del Usuario: $($_.Exception.Message)" 'ERROR'
        }
    }

    # Sesion actual
    $env:PATH = "$targetDir;$env:PATH"

    # Notificacion de actualizacion al sistema operativo (WM_SETTINGCHANGE)
    if (-not $DryRun) {
        try {
            $broadcastCode = @"
using System;
using System.Runtime.InteropServices;
public class EnvironmentNotifier {
    [DllImport("user32.dll", SetLastError = true, CharSet = CharSet.Auto)]
    public static extern IntPtr SendMessageTimeout(
        IntPtr hWnd, uint Msg, UIntPtr wParam, string lParam,
        uint fuFlags, uint uTimeout, out UIntPtr lpdwResult
    );
}
"@
            if (-not ([System.Management.Automation.PSTypeName]'EnvironmentNotifier').Type) {
                Add-Type -TypeDefinition $broadcastCode -ErrorAction SilentlyContinue
            }
            $HWND_BROADCAST = [IntPtr]0xffff
            $WM_SETTINGCHANGE = 0x001A
            $SMTO_ABORTIFHUNG = 0x0002
            [UIntPtr]$result = [UIntPtr]::Zero
            [EnvironmentNotifier]::SendMessageTimeout($HWND_BROADCAST, $WM_SETTINGCHANGE, [UIntPtr]::Zero, "Environment", $SMTO_ABORTIFHUNG, 3000, [ref]$result) | Out-Null
        } catch {}
    }
}

# --- 7. Configuracion de Windows Terminal ---
function Update-WindowsTerminalDefaultProfile {
    param (
        [switch]$DryRun
    )

    Get-RealUserProfiles | ForEach-Object {
        $userPackages = Join-Path $_ "AppData\Local\Packages"
        if (-not (Test-Path $userPackages)) { return }

        $terminalPackages = Get-ChildItem -Path $userPackages -Filter "Microsoft.WindowsTerminal*" -Directory -ErrorAction SilentlyContinue
        foreach ($pkg in $terminalPackages) {
            $settingsPath = Join-Path $pkg.FullName "LocalState\settings.json"
            if (Test-Path -Path $settingsPath) {
                try {
                    $rawContent = [System.IO.File]::ReadAllText($settingsPath, [System.Text.Encoding]::UTF8)
                    $cleanJson = $rawContent -replace '(?m)^\s*//.*$', ''
                    $settings = ConvertFrom-Json -InputObject $cleanJson

                $profilesList = $settings.profiles.list
                $pwshProfile = $profilesList | Where-Object {
                    $_.source -eq "Windows.Terminal.PowershellCore" -or
                    $_.commandline -match '(?i)pwsh\.exe' -or
                    ($_.name -ieq "PowerShell" -and $_.name -ine "Windows PowerShell")
                } | Select-Object -First 1

                if ($pwshProfile -and $pwshProfile.guid) {
                    if ($settings.defaultProfile -ne $pwshProfile.guid) {
                        if ($DryRun) {
                            Write-Log "[SIMULACION] Windows Terminal: defaultProfile cambiaria a $($pwshProfile.name)" 'DRYRUN'
                        } else {
                            $settings.defaultProfile = $pwshProfile.guid
                            $newJson = ConvertTo-Json -InputObject $settings -Depth 10
                            [System.IO.File]::WriteAllText($settingsPath, $newJson, [System.Text.Encoding]::UTF8)
                            Write-Log "Windows Terminal: Perfil predeterminado configurado a $($pwshProfile.name)" 'SUCCESS'
                        }
                    }
                }
            } catch {}
        }
    }
    }
}

# --- 8. Notificacion y refresco de iconos de Windows ---
function Refresh-WindowsIconCache {
    try {
        $shellCode = @"
using System;
using System.Runtime.InteropServices;
public class ShellIconRefresher {
    [DllImport("shell32.dll")]
    public static extern void SHChangeNotify(int wEventId, uint uFlags, IntPtr dwItem1, IntPtr dwItem2);
}
"@
        if (-not ([System.Management.Automation.PSTypeName]'ShellIconRefresher').Type) {
            Add-Type -TypeDefinition $shellCode -ErrorAction SilentlyContinue
        }
        [ShellIconRefresher]::SHChangeNotify(0x08000000, 0, [IntPtr]::Zero, [IntPtr]::Zero)
    } catch {}

    $ie4uinit = Join-Path $env:SystemRoot "System32\ie4uinit.exe"
    if (Test-Path $ie4uinit) {
        try { Start-Process -FilePath $ie4uinit -ArgumentList "-show" -WindowStyle Hidden -ErrorAction SilentlyContinue } catch {}
    }
}

# --- 9. Reversion / Restauracion desde Backup ---
function Restore-OriginalShortcuts {
    Write-Log "Iniciando restauracion de accesos directos desde copia de seguridad..." 'INFO'
    $indexPath = Join-Path $BackupDirectory "backup_index.txt"

    if (-not (Test-Path $indexPath)) {
        Write-Log "No se encontro el archivo de indice de respaldos en: $indexPath" 'ERROR'
        return
    }

    $entries = Get-Content -Path $indexPath -Encoding UTF8 -ErrorAction SilentlyContinue
    $count = 0

    foreach ($entry in $entries) {
        if ($entry -match '^(.+)\|(.+)$') {
            $orig = $Matches[1]
            $bak  = $Matches[2]

            if (Test-Path $bak) {
                try {
                    Copy-Item -Path $bak -Destination $orig -Force
                    Write-Log "Restaurado: $orig" 'SUCCESS'
                    $count++
                } catch {
                    Write-Log "Error al restaurar ($($orig)): $($_.Exception.Message)" 'ERROR'
                }
            }
        }
    }

    Refresh-WindowsIconCache
    Write-Log "Restauracion completada. Total ficheros recuperados: $count" 'SUCCESS'
}

# ==============================================================================
# EJECUCION PRINCIPAL
# ==============================================================================

if ($Restore) {
    Restore-OriginalShortcuts
    exit 0
}

Write-Log "Iniciando comprobacion y optimizacion de versiones de PowerShell..." 'INFO'

# 1. Comprobar elevacion
if (-not (Test-IsAdminOrSystem)) {
    Write-Log "Aviso: El script se ejecuta sin privilegios de administrador. Las claves globales de sistema requeriran elevacion." 'WARN'
}

# 2. Deteccion de versiones instaladas
$versions = Get-InstalledPowerShellVersions
if ($versions.Count -eq 0) {
    Write-Log "No se encontro ninguna version operativa de PowerShell." 'ERROR'
    exit 1
}

$highest = $versions | Select-Object -First 1
Write-Log "Version mas alta seleccionada: v$($highest.Version) ($($highest.InstallType)) en $($highest.ExecutablePath)" 'SUCCESS'

# 3. Localizar accesos directos
$shortcuts = Get-PowerShellShortcuts -IncludeISE:$IncludeISE
Write-Log "Accesos directos candidatos detectados: $($shortcuts.Count)" 'INFO'

# 4. Control de ejecucion: Pruebas interactivas (PowerShell ISE) vs Desatendido (Intune)
# En Intune (ejecutado por el agente IME bajo SYSTEM o Usuario), el script NUNCA debe pausarse ni esperar confirmacion.
$isISE = ($null -ne $psISE) -or ($Host.Name -match "ISE")
$isSystem = [Security.Principal.WindowsIdentity]::GetCurrent().IsSystem

# Si se ejecuta desde Intune o en segundo plano (fuera de ISE), forzar modo automatico desatendido
if (-not $isISE -or $isSystem) {
    $Force = $true
}

if (-not $Force -and -not $DryRun) {
    Write-Host "`nModo interactivo de pruebas detectado (PowerShell ISE):" -ForegroundColor Cyan
    Write-Host " [S] Aplicar cambios en este equipo" -ForegroundColor White
    Write-Host " [D] Ejecutar simulacion (Dry Run)" -ForegroundColor White
    Write-Host " [C] Cancelar" -ForegroundColor White

    $resp = Read-Host "Selecciona una opcion [S/D/C] (por defecto: D)"
    if ([string]::IsNullOrWhiteSpace($resp)) { $resp = 'D' }

    switch ($resp.ToUpper()) {
        'S' { $DryRun = $false }
        'D' { $DryRun = $true; Write-Log "Iniciando en modo Simulacion..." 'DRYRUN' }
        default { Write-Log "Operacion cancelada por el usuario." 'INFO'; exit 0 }
    }
}

# 5. Desinstalar versiones intermedias obsoletas
if ($RemoveIntermediateVersions) {
    Remove-IntermediatePowerShellVersions -HighestVersion $highest.Version -DryRun:$DryRun
}

# 6. Limpieza de accesos directos obsoletos x86
if ($RemoveX86Shortcuts) {
    Remove-PowerShellX86Shortcuts -DryRun:$DryRun
}

# 7. Actualizar accesos directos a la version mas alta
foreach ($sc in $shortcuts) {
    Update-PowerShellShortcutItem -ShortcutInfo $sc -TargetPowerShell $highest -IconStyle $IconStyle -DryRun:$DryRun
}

# 8. Actualizar variables de entorno PATH
Update-EnvironmentVariables -TargetPowerShell $highest -DryRun:$DryRun

# 9. Configurar Windows Terminal si procede
if ($UpdateTerminal) {
    Update-WindowsTerminalDefaultProfile -DryRun:$DryRun
}

# 10. Finalizacion y refresco de cache
if (-not $DryRun) {
    Refresh-WindowsIconCache
    $scriptName = if ($PSCommandPath) { Split-Path $PSCommandPath -Leaf } else { 'Script Platform - PowerShell - Forzar version mas alta.ps1' }
    Write-Host "`nProceso completado con exito." -ForegroundColor Green
    Write-Host "Copia de seguridad guardada en: $BackupDirectory" -ForegroundColor Gray
    Write-Host "Fichero de log: $LogFile" -ForegroundColor Gray
    Write-Host "Para revertir los cambios: .\$scriptName -Restore`n" -ForegroundColor Gray
    exit 0
} else {
    Write-Host "`nSimulacion finalizada sin cambios en el equipo.`n" -ForegroundColor Magenta
    exit 0
}
