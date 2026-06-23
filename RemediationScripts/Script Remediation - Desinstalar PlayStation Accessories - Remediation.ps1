<#
.SYNOPSIS
    REMEDIATION SCRIPT: ELIMINAR COMPLETAMENTE LA APLICACION "PLAYSTATION ACCESSORIES"

.DESCRIPTION
    Este script desinstala PlayStation Accessories usando msiexec como primer paso (ya que
    la aplicacion se instala via un MSI embebido en el setup.exe de InstallShield). A continuacion
    realiza una limpieza profunda de la base de datos de Windows Installer, claves de registro,
    archivos MSI cacheados, carpetas de InstallShield y accesos directos.

.PARAMETER
    Ninguno.

.EXAMPLE
    Executes as Intune Remediation Script.

.NOTES
    Name: Script Remediation - Desinstalar PlayStation Accessories - Remediation.ps1
    Author: Alejandro Suarez (@alexsf93)
    Version: 1.2.0
    Date: 2026-06-23
    Context: System
#>

$OutputEncoding = [System.Text.Encoding]::UTF8

$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")
if (-not $isAdmin) {
    Write-Host "ERROR: El script requiere ejecutarse con privilegios elevados (Administrator/SYSTEM)."
    exit 1
}

if ([Environment]::Is64BitOperatingSystem -and -not [Environment]::Is64BitProcess) {
    Write-Host "Ejecutando en proceso de 32 bits. Relanzando en PowerShell de 64 bits..."
    $powershell64 = Join-Path $env:SystemRoot "Sysnative\WindowsPowerShell\v1.0\powershell.exe"
    if (Test-Path $powershell64) {
        $arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`""
        Start-Process -FilePath $powershell64 -ArgumentList $arguments -Wait -NoNewWindow
        exit $LASTEXITCODE
    } else {
        Write-Host "No se pudo encontrar PowerShell de 64 bits en Sysnative. Continuando en modo actual."
    }
}

Write-Host "Iniciando proceso de eliminacion de 'PlayStation Accessories'..."

# --- Funciones auxiliares ---

function Remove-RegistryKey {
    param ([string]$Path)
    if (Test-Path $Path) {
        try {
            Write-Host "Eliminando clave de registro: $Path"
            Remove-Item -Path $Path -Recurse -Force -ErrorAction Stop
        } catch {
            Write-Host "Advertencia al eliminar clave ($Path): $_"
        }
    }
}

function Convert-GuidToSquished {
    param ([string]$Guid)
    $clean = $Guid.Replace("{","").Replace("}","").Replace("-","")
    if ($clean.Length -ne 32) { return $null }
    $g1 = $clean.Substring(0, 8).ToCharArray(); [array]::Reverse($g1); $g1 = -join $g1
    $g2 = $clean.Substring(8, 4).ToCharArray(); [array]::Reverse($g2); $g2 = -join $g2
    $g3 = $clean.Substring(12, 4).ToCharArray(); [array]::Reverse($g3); $g3 = -join $g3
    $g4 = ""; for ($i = 0; $i -lt 4; $i += 2) { $g4 += $clean.Substring(16+$i+1,1) + $clean.Substring(16+$i,1) }
    $g5 = ""; for ($i = 0; $i -lt 12; $i += 2) { $g5 += $clean.Substring(20+$i+1,1) + $clean.Substring(20+$i,1) }
    return "$g1$g2$g3$g4$g5"
}

function Convert-SquishedToGuid {
    param ([string]$Squished)
    if ($Squished.Length -ne 32) { return $null }
    $g1 = $Squished.Substring(0, 8).ToCharArray(); [array]::Reverse($g1); $g1 = -join $g1
    $g2 = $Squished.Substring(8, 4).ToCharArray(); [array]::Reverse($g2); $g2 = -join $g2
    $g3 = $Squished.Substring(12, 4).ToCharArray(); [array]::Reverse($g3); $g3 = -join $g3
    $g4 = ""; for ($i = 0; $i -lt 4; $i += 2) { $g4 += $Squished.Substring(16+$i+1,1) + $Squished.Substring(16+$i,1) }
    $g5 = ""; for ($i = 0; $i -lt 12; $i += 2) { $g5 += $Squished.Substring(20+$i+1,1) + $Squished.Substring(20+$i,1) }
    return "{$g1-$g2-$g3-$g4-$g5}"
}

# --- Mapear HKU ---
if (-not (Get-PSDrive -Name HKU -ErrorAction SilentlyContinue)) {
    New-PSDrive -Name HKU -PSProvider Registry -Root HKEY_USERS -ErrorAction SilentlyContinue | Out-Null
}
$loadedUserSids = @()
if (Test-Path "HKU:\") {
    $loadedUserSids = Get-ChildItem -Path "HKU:\" -ErrorAction SilentlyContinue |
        Where-Object { $_.PSChildName -match "^S-1-5-21-\d+-\d+-\d+-\d+$" } |
        Select-Object -ExpandProperty PSChildName
}

$KeysToDelete = [System.Collections.Generic.List[string]]::new()
$GuidSet      = [System.Collections.Generic.HashSet[string]]::new()
$SquishedSet  = [System.Collections.Generic.HashSet[string]]::new()

$userDataPath        = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Installer\UserData"
$classesProductsPath = "HKLM:\SOFTWARE\Classes\Installer\Products"

# GUID conocido del diagnostico (fallback garantizado)
$KnownGuid    = "{A27B17B9-90C8-4B07-83C6-1303FC186B6B}"
$KnownSquished = "9B71B72A8C0970B4386C3130CF81B6B6"
[void]$GuidSet.Add($KnownGuid)
[void]$SquishedSet.Add($KnownSquished)

# =============================================================================
# PASO 1: Finalizar procesos activos
# =============================================================================
Write-Host "--- Paso 1: Finalizando procesos activos ---"
$ProcessNamesToKill = @(
    "PlayStationAccessories*",
    "PlayStationAccessoriesInstaller*",
    "PSAInstall*"
)
foreach ($procName in $ProcessNamesToKill) {
    try {
        Get-Process -Name $procName -ErrorAction SilentlyContinue | ForEach-Object {
            Write-Host "Terminando proceso $($_.Name) (PID: $($_.Id))..."
            Stop-Process -Id $_.Id -Force -ErrorAction SilentlyContinue
        }
    } catch { }
}

# Esperar a que msiexec quede libre (si habia una instalacion en curso)
Write-Host "Esperando a que msiexec quede libre..."
$maxWait = 60  # segundos maximos de espera
$elapsed = 0
do {
    $msiRunning = Get-Process -Name "msiexec" -ErrorAction SilentlyContinue |
        Where-Object { $_.MainWindowTitle -ne "" -or $_.SessionId -eq 0 }
    if ($msiRunning) {
        Write-Host "  msiexec en ejecucion (PID: $($msiRunning.Id -join ', ')). Esperando..."
        Start-Sleep -Seconds 5
        $elapsed += 5
    }
} while ($msiRunning -and $elapsed -lt $maxWait)

Start-Sleep -Seconds 2

# =============================================================================
# PASO 2: Recopilar todos los GUIDs de TODAS las fuentes del registro
# =============================================================================
Write-Host "--- Paso 2: Recopilando GUIDs del registro ---"

# 2a. Claves Uninstall (HKLM + HKU)
$UninstallSearchPaths = @(
    "HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall",
    "HKLM:\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall"
)
foreach ($sid in $loadedUserSids) {
    $UninstallSearchPaths += "HKU:\$sid\Software\Microsoft\Windows\CurrentVersion\Uninstall"
    $UninstallSearchPaths += "HKU:\$sid\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall"
}

$FoundInstallers = [System.Collections.Generic.List[PSCustomObject]]::new()
foreach ($basePath in $UninstallSearchPaths) {
    if (-not (Test-Path $basePath)) { continue }
    Get-ChildItem -Path $basePath -ErrorAction SilentlyContinue | ForEach-Object {
        $name        = $_.PSChildName
        $displayName = $_.GetValue("DisplayName")
        if ($name -like "*PlayStationAccessories*" -or $name -like "*PlayStation Accessories*" -or
            $name -eq $KnownGuid -or
            $displayName -like "*PlayStationAccessories*" -or $displayName -like "*PlayStation*") {
            $FoundInstallers.Add([PSCustomObject]@{
                BasePath             = $basePath
                KeyName              = $name
                DisplayName          = $displayName
                UninstallString      = $_.GetValue("UninstallString")
                QuietUninstallString = $_.GetValue("QuietUninstallString")
            })
            if ($name -match "^\{[0-9a-fA-F\-]{36}\}$") { [void]$GuidSet.Add($name) }
            Write-Host "Encontrado en Uninstall: $basePath -> $name ($displayName)"
        }
    }
}

# 2b. Classes\Installer\Products
if (Test-Path $classesProductsPath) {
    Get-ChildItem -Path $classesProductsPath -ErrorAction SilentlyContinue | ForEach-Object {
        $pname = $_.GetValue("ProductName")
        if ($pname -like "*PlayStationAccessories*" -or $pname -like "*PlayStation Accessories*") {
            Write-Host "Encontrado en Classes\Installer\Products: $($_.PSChildName) ($pname)"
            [void]$SquishedSet.Add($_.PSChildName)
            $std = Convert-SquishedToGuid -Squished $_.PSChildName
            if ($std) { [void]$GuidSet.Add($std) }
        }
    }
}

# 2c. UserData
if (Test-Path $userDataPath) {
    Get-ChildItem -Path $userDataPath -ErrorAction SilentlyContinue | ForEach-Object {
        $sidKey       = $_.PSChildName
        $productsPath = "$userDataPath\$sidKey\Products"
        if (Test-Path $productsPath) {
            Get-ChildItem -Path $productsPath -ErrorAction SilentlyContinue | ForEach-Object {
                $sq          = $_.PSChildName
                $installProp = "$productsPath\$sq\InstallProperties"
                if (Test-Path $installProp) {
                    $dn = (Get-ItemProperty -Path $installProp -ErrorAction SilentlyContinue).DisplayName
                    if ($dn -like "*PlayStationAccessories*" -or $dn -like "*PlayStation Accessories*") {
                        Write-Host "Encontrado en UserData\$sidKey\Products: $sq ($dn)"
                        [void]$SquishedSet.Add($sq)
                        $std = Convert-SquishedToGuid -Squished $sq
                        if ($std) { [void]$GuidSet.Add($std) }
                    }
                }
            }
        }
    }
}

# 2d. HKU\*\Software\Microsoft\Installer\Products
foreach ($sid in $loadedUserSids) {
    $hkuPath = "HKU:\$sid\Software\Microsoft\Installer\Products"
    if (Test-Path $hkuPath) {
        Get-ChildItem -Path $hkuPath -ErrorAction SilentlyContinue | ForEach-Object {
            $pname = $_.GetValue("ProductName")
            if ($pname -like "*PlayStationAccessories*" -or $pname -like "*PlayStation Accessories*") {
                Write-Host "Encontrado en HKU\$sid\...\Installer\Products: $($_.PSChildName) ($pname)"
                [void]$SquishedSet.Add($_.PSChildName)
                $std = Convert-SquishedToGuid -Squished $_.PSChildName
                if ($std) { [void]$GuidSet.Add($std) }
                $KeysToDelete.Add("HKU:\$sid\Software\Microsoft\Installer\Products\$($_.PSChildName)")
            }
        }
    }
}

# Asegurar que tenemos ambas representaciones (GUID <-> Squished) para todo lo encontrado
foreach ($guid in @($GuidSet)) {
    $sq = Convert-GuidToSquished -Guid $guid
    if ($sq) { [void]$SquishedSet.Add($sq) }
}
foreach ($sq in @($SquishedSet)) {
    $std = Convert-SquishedToGuid -Squished $sq
    if ($std) { [void]$GuidSet.Add($std) }
}

Write-Host "GUIDs identificados: $($GuidSet.Count) | Squished: $($SquishedSet.Count)"

# =============================================================================
# PASO 3: Desinstalar via msiexec /x (PRIMER METODO - limpieza oficial)
# =============================================================================
Write-Host "--- Paso 3: Desinstalando via msiexec ---"
foreach ($guid in @($GuidSet)) {
    Write-Host "msiexec /x $guid /qn /norestart ..."
    try {
        $msiProc = Start-Process -FilePath "msiexec.exe" `
            -ArgumentList "/x `"$guid`" /qn /norestart REBOOT=ReallySuppress" `
            -Wait -NoNewWindow -PassThru -ErrorAction Stop
        Write-Host "msiexec /x $guid -> ExitCode $($msiProc.ExitCode)"
    } catch {
        Write-Host "Advertencia msiexec /x $guid : $_"
    }
}
if ($GuidSet.Count -gt 0) { Start-Sleep -Seconds 5 }

# =============================================================================
# PASO 4: Ejecutar desinstalador de InstallShield (SEGUNDO METODO - fallback)
# =============================================================================
Write-Host "--- Paso 4: Ejecutando desinstalador de InstallShield ---"
foreach ($installer in $FoundInstallers) {
    $uninstallCommand = ""
    if ($installer.QuietUninstallString) {
        $uninstallCommand = $installer.QuietUninstallString
    } elseif ($installer.UninstallString) {
        if ($installer.UninstallString -like "*MsiExec.exe*") {
            $uninstallCommand = $installer.UninstallString -replace "/I", "/X"
            if ($uninstallCommand -notlike "*/qn*") { $uninstallCommand = "$uninstallCommand /qn /norestart" }
        } else {
            $uninstallCommand = "$($installer.UninstallString) /S /silent /quiet /qn /norestart /s /v`"/qn`""
        }
    }
    if ($uninstallCommand) {
        try {
            Write-Host "Ejecutando desinstalador: $uninstallCommand"
            $proc = Start-Process "cmd.exe" -ArgumentList "/c `"$uninstallCommand`"" -Wait -NoNewWindow -PassThru
            Write-Host "Desinstalador -> ExitCode $($proc.ExitCode)"
        } catch {
            Write-Host "ERROR al invocar el desinstalador: $_"
        }
    }
    $KeysToDelete.Add("$($installer.BasePath)\$($installer.KeyName)")
}
if ($FoundInstallers.Count -gt 0) { Start-Sleep -Seconds 5 }

# =============================================================================
# PASO 5: Limpiar archivos MSI cacheados en C:\Windows\Installer
# =============================================================================
Write-Host "--- Paso 5: Limpiando archivos MSI cacheados ---"
$windowsInstallerPath = "C:\Windows\Installer"

# 5a. Via COM: obtener la ruta del LocalPackage registrado para cada GUID
foreach ($guid in @($GuidSet)) {
    try {
        $comInstaller = New-Object -ComObject WindowsInstaller.Installer -ErrorAction Stop
        try {
            $localPkg = $comInstaller.ProductInfo($guid, "LocalPackage")
            if ($localPkg -and (Test-Path $localPkg)) {
                Write-Host "Eliminando MSI cacheado via COM: $localPkg"
                Remove-Item -Path $localPkg -Force -ErrorAction SilentlyContinue
            }
        } catch { }
    } catch {
        Write-Host "Advertencia COM WindowsInstaller: $_"
    }
}

# 5b. Red de seguridad: escanear C:\Windows\Installer buscando MSI de PlayStation
if (Test-Path $windowsInstallerPath) {
    Get-ChildItem -Path $windowsInstallerPath -File -ErrorAction SilentlyContinue |
        Where-Object { $_.Extension -in @(".msi", ".msp") } | ForEach-Object {
        try {
            $comDb = New-Object -ComObject WindowsInstaller.Installer -ErrorAction SilentlyContinue
            if ($comDb) {
                $db     = $comDb.OpenDatabase($_.FullName, 0)
                $view   = $db.OpenView("SELECT ``Value`` FROM ``Property`` WHERE ``Property``='ProductName'")
                $view.Execute()
                $record = $view.Fetch()
                if ($record) {
                    $pname = $record.StringData(1)
                    if ($pname -like "*PlayStationAccessories*" -or $pname -like "*PlayStation Accessories*") {
                        Write-Host "Eliminando MSI cacheado: $($_.FullName) ($pname)"
                        Remove-Item -Path $_.FullName -Force -ErrorAction SilentlyContinue
                    }
                }
            }
        } catch { }
    }
}

# =============================================================================
# PASO 6: Limpieza profunda de claves de registro (manual, como fallback final)
# =============================================================================
Write-Host "--- Paso 6: Limpieza de claves de registro ---"

# Claves Uninstall y variantes InstallShield
foreach ($guid in $GuidSet) {
    $KeysToDelete.Add("HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\$guid")
    $KeysToDelete.Add("HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\$guid")
    $KeysToDelete.Add("HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\InstallShield Uninstall Information\$guid")
    $KeysToDelete.Add("HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\InstallShield Uninstall Information\$guid")
    $KeysToDelete.Add("HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\InstallShield_$guid")
    $KeysToDelete.Add("HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\InstallShield_$guid")
    foreach ($sid in $loadedUserSids) {
        $KeysToDelete.Add("HKU:\$sid\Software\Microsoft\Windows\CurrentVersion\Uninstall\$guid")
        $KeysToDelete.Add("HKU:\$sid\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\$guid")
        $KeysToDelete.Add("HKU:\$sid\Software\Microsoft\Windows\CurrentVersion\Uninstall\InstallShield Uninstall Information\$guid")
        $KeysToDelete.Add("HKU:\$sid\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\InstallShield Uninstall Information\$guid")
        $KeysToDelete.Add("HKU:\$sid\Software\Microsoft\Windows\CurrentVersion\Uninstall\InstallShield_$guid")
        $KeysToDelete.Add("HKU:\$sid\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\InstallShield_$guid")
    }
}

# Claves base de datos Windows Installer (squished)
foreach ($sq in $SquishedSet) {
    $KeysToDelete.Add("HKLM:\SOFTWARE\Classes\Installer\Products\$sq")
    $KeysToDelete.Add("HKLM:\SOFTWARE\Classes\Installer\Features\$sq")
    $KeysToDelete.Add("HKLM:\SOFTWARE\Microsoft\Installer\Products\$sq")
    if (Test-Path $userDataPath) {
        Get-ChildItem -Path $userDataPath -ErrorAction SilentlyContinue | ForEach-Object {
            $KeysToDelete.Add("$userDataPath\$($_.PSChildName)\Products\$sq")
            $KeysToDelete.Add("$userDataPath\$($_.PSChildName)\Patches\$sq")
        }
    }
    foreach ($sid in $loadedUserSids) {
        $KeysToDelete.Add("HKU:\$sid\Software\Microsoft\Installer\Products\$sq")
    }
}

# Claves de aplicacion de Sony
@(
    "HKLM:\SOFTWARE\Sony\PlayStationAccessories",
    "HKLM:\SOFTWARE\Wow6432Node\Sony\PlayStationAccessories",
    "HKCU:\SOFTWARE\Sony\PlayStationAccessories"
) | ForEach-Object { $KeysToDelete.Add($_) }
foreach ($sid in $loadedUserSids) {
    $KeysToDelete.Add("HKU:\$sid\Software\Sony\PlayStationAccessories")
}

# Eliminar todas las claves recopiladas
$KeysToDelete | Select-Object -Unique | ForEach-Object { Remove-RegistryKey -Path $_ }

# =============================================================================
# PASO 7: Limpiar carpetas de InstallShield cache
# =============================================================================
Write-Host "--- Paso 7: Limpiando carpetas de InstallShield ---"

# Por GUID conocido
foreach ($guid in $GuidSet) {
    @(
        "C:\Program Files (x86)\InstallShield Installation Information\$guid",
        "C:\Program Files\InstallShield Installation Information\$guid",
        "C:\Program Files (x86)\InstallShield Installation Information\InstallShield_$guid",
        "C:\Program Files\InstallShield Installation Information\InstallShield_$guid"
    ) | ForEach-Object {
        if (Test-Path $_ -ErrorAction SilentlyContinue) {
            try { Remove-Item -Path $_ -Recurse -Force -ErrorAction Stop; Write-Host "Eliminada: $_" }
            catch { Write-Host "Advertencia al eliminar ($_): $_" }
        }
    }
}

# Por setup.ini (red de seguridad)
@("C:\Program Files (x86)\InstallShield Installation Information","C:\Program Files\InstallShield Installation Information") | ForEach-Object {
    if (-not (Test-Path $_)) { return }
    Get-ChildItem -Path $_ -Directory -Force -ErrorAction SilentlyContinue | ForEach-Object {
        $iniPath = Join-Path $_.FullName "setup.ini"
        if (Test-Path $iniPath) {
            $iniContent = Get-Content -Path $iniPath -ErrorAction SilentlyContinue
            if ($iniContent -like "*PlayStationAccessories*" -or $iniContent -like "*PlayStation Accessories*") {
                Write-Host "Detectada cache de InstallShield via setup.ini: $($_.FullName)"
                try { Remove-Item -Path $_.FullName -Recurse -Force -ErrorAction Stop }
                catch { Write-Host "Advertencia: $_" }
            }
        }
    }
}

# =============================================================================
# PASO 8: Paquetes AppX / MSIX
# =============================================================================
try {
    Get-AppxPackage -AllUsers -Name "*PlayStationAccessories*" -ErrorAction SilentlyContinue | ForEach-Object {
        Write-Host "Removiendo paquete UWP/Store: $($_.PackageFullName)..."
        Remove-AppxPackage -AllUsers -Package $_.PackageFullName -ErrorAction SilentlyContinue
    }
} catch {
    Write-Host "Advertencia al comprobar paquetes AppX: $_"
}

# =============================================================================
# PASO 9: Eliminar carpetas de aplicacion
# =============================================================================
Write-Host "--- Paso 9: Eliminando carpetas residuales ---"
@("C:\Program Files\Sony\PlayStationAccessories") | ForEach-Object {
    if (Test-Path $_ -ErrorAction SilentlyContinue) {
        try { Remove-Item -Path $_ -Recurse -Force -ErrorAction Stop; Write-Host "Eliminada: $_" }
        catch { Write-Host "ERROR al eliminar ($_): $_" }
    }
}

# =============================================================================
# PASO 10: Eliminar accesos directos (.lnk)
# =============================================================================
Write-Host "--- Paso 10: Eliminando accesos directos ---"
$ShortcutPaths = [System.Collections.Generic.List[string]]::new()
@("$env:PUBLIC\Desktop","$env:USERPROFILE\Desktop","$env:PROGRAMDATA\Microsoft\Windows\Start Menu") | ForEach-Object {
    if (Test-Path $_) { $ShortcutPaths.Add($_) }
}
Get-ChildItem -Path "C:\Users" -ErrorAction SilentlyContinue |
    Where-Object { $_.PSIsContainer -and $_.Name -notin @("All Users","Default","Default User","Public") } | ForEach-Object {
    $d = Join-Path $_.FullName "Desktop"
    $s = Join-Path $_.FullName "AppData\Roaming\Microsoft\Windows\Start Menu"
    if (Test-Path $d) { $ShortcutPaths.Add($d) }
    if (Test-Path $s) { $ShortcutPaths.Add($s) }
}

$lnkFiles = @()
foreach ($dir in $ShortcutPaths) {
    if (Test-Path $dir) { $lnkFiles += Get-ChildItem -Path $dir -Filter "*.lnk" -Recurse -File -ErrorAction SilentlyContinue }
}
if ($lnkFiles.Count -gt 0) {
    try {
        $wshShell = New-Object -ComObject WScript.Shell
        foreach ($file in $lnkFiles) {
            try {
                $shortcut   = $wshShell.CreateShortcut($file.FullName)
                $lnkTarget  = $shortcut.TargetPath
                if ($lnkTarget -like "*PlayStationAccessories*" -or $lnkTarget -like "*PlayStation Accessories*") {
                    Write-Host "Eliminando acceso directo: $($file.FullName)"
                    Remove-Item -Path $file.FullName -Force -ErrorAction SilentlyContinue
                }
            } catch { Write-Host "Advertencia al procesar .lnk ($($file.FullName)): $_" }
        }
    } catch { Write-Host "ERROR al inicializar WScript.Shell: $_" }
}

# =============================================================================
# POST-VERIFICACION
# =============================================================================
Write-Host "--- Post-verificacion ---"
$Failed = $false

if (Get-Process -Name "PlayStationAccessories*" -ErrorAction SilentlyContinue) {
    Write-Host "ERROR: Siguen existiendo procesos activos."; $Failed = $true
}
if (Test-Path "C:\Program Files\Sony\PlayStationAccessories" -ErrorAction SilentlyContinue) {
    Write-Host "ERROR: El directorio de la aplicacion sigue existiendo."; $Failed = $true
}

@("HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall","HKLM:\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall") | ForEach-Object {
    if (-not (Test-Path $_)) { return }
    Get-ChildItem -Path $_ -ErrorAction SilentlyContinue | ForEach-Object {
        $n = $_.PSChildName; $dn = $_.GetValue("DisplayName")
        if ($n -like "*PlayStationAccessories*" -or $n -like "*PlayStation Accessories*" -or
            $dn -like "*PlayStationAccessories*" -or $dn -like "*PlayStation Accessories*") {
            Write-Host "ERROR: Registro Uninstall residual: $n"; $Failed = $true
        }
    }
}

if (Test-Path $classesProductsPath) {
    Get-ChildItem -Path $classesProductsPath -ErrorAction SilentlyContinue | ForEach-Object {
        $pname = $_.GetValue("ProductName")
        if ($pname -like "*PlayStationAccessories*" -or $pname -like "*PlayStation Accessories*") {
            Write-Host "ERROR: Clave residual en Classes\Installer\Products: $($_.PSChildName)"; $Failed = $true
        }
    }
}

if (Test-Path $userDataPath) {
    Get-ChildItem -Path $userDataPath -ErrorAction SilentlyContinue | ForEach-Object {
        $pPath = "$userDataPath\$($_.PSChildName)\Products"
        if (Test-Path $pPath) {
            Get-ChildItem -Path $pPath -ErrorAction SilentlyContinue | ForEach-Object {
                $ip = "$pPath\$($_.PSChildName)\InstallProperties"
                if (Test-Path $ip) {
                    $dn = (Get-ItemProperty -Path $ip -ErrorAction SilentlyContinue).DisplayName
                    if ($dn -like "*PlayStationAccessories*" -or $dn -like "*PlayStation Accessories*") {
                        Write-Host "ERROR: Clave residual en UserData\Products: $($_.PSChildName)"; $Failed = $true
                    }
                }
            }
        }
    }
}

@("C:\Program Files (x86)\InstallShield Installation Information","C:\Program Files\InstallShield Installation Information") | ForEach-Object {
    if (-not (Test-Path $_)) { return }
    Get-ChildItem -Path $_ -Directory -Force -ErrorAction SilentlyContinue | ForEach-Object {
        $iniPath = Join-Path $_.FullName "setup.ini"
        if (Test-Path $iniPath) {
            $iniContent = Get-Content -Path $iniPath -ErrorAction SilentlyContinue
            if ($iniContent -like "*PlayStationAccessories*" -or $iniContent -like "*PlayStation Accessories*") {
                Write-Host "ERROR: Cache residual de InstallShield: $($_.FullName)"; $Failed = $true
            }
        }
    }
}

if ($Failed) {
    Write-Host "ERROR CRITICO: Algunos componentes no pudieron eliminarse."
    exit 1
} else {
    Write-Host "Remediacion finalizada con exito."
    exit 0
}
