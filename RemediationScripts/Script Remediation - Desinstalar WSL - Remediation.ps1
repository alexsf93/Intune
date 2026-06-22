<#
.SYNOPSIS
    REMEDIATION SCRIPT: DESINSTALAR WSL Y ELIMINAR DISTRIBUCIONES

.DESCRIPTION
    Este script realiza la eliminacion completa de Windows Subsystem for Linux (WSL).
    Detiene los procesos de WSL, elimina todas las distribuciones registradas y sus archivos vhdx
    en los perfiles de todos los usuarios (cargando colmenas offline NTUSER.DAT si es necesario),
    desinstala el paquete AppX de WSL, desinstala el MSI de WSL y deshabilita la caracteristica
    opcional de Windows.

.PARAMETER
    Ninguno.

.EXAMPLE
    Executes as Intune Remediation Script.

.NOTES
    Name: Script Remediation - Desinstalar WSL - Remediation.ps1
    Author: Alejandro Suarez (@alexsf93)
    Version: 1.0.0
    Date: 2026-06-22
    Context: System
#>

# Comprobar si el script tiene privilegios de administrador o SYSTEM
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")
if (-not $isAdmin) {
    Write-Output "El script necesita ejecutarse con privilegios de administrador o como SYSTEM."
    exit 1
}

# 1. Detener procesos de WSL para evitar bloqueos de archivos
try {
    if (Get-Command wsl.exe -ErrorAction SilentlyContinue) {
        & wsl.exe --shutdown | Out-Null
    }
} catch {}
Stop-Process -Name "wslhost", "wsl" -Force -ErrorAction SilentlyContinue

# 2. Desinstalar y limpiar distribuciones de Linux para todos los perfiles de usuario
$profilesPath = "HKLM:\Software\Microsoft\Windows NT\CurrentVersion\ProfileList"
if (Test-Path $profilesPath) {
    $profiles = Get-ChildItem -Path $profilesPath -ErrorAction SilentlyContinue
    foreach ($profile in $profiles) {
        $sid = $profile.PSChildName
        # Omitir SIDs de sistema
        if ($sid -notlike "S-1-5-21-*") { continue }

        $profileImagePath = $profile.GetValue("ProfileImagePath")
        if (-not $profileImagePath -or -not (Test-Path $profileImagePath)) { continue }

        $userHiveLoaded = Test-Path "Registry::HKEY_USERS\$sid"

        if ($userHiveLoaded) {
            $lxssPath = "Registry::HKEY_USERS\$sid\Software\Microsoft\Windows\CurrentVersion\Lxss"
            if (Test-Path $lxssPath) {
                $subkeys = Get-ChildItem -Path $lxssPath -ErrorAction SilentlyContinue
                foreach ($subkey in $subkeys) {
                    $distName = $subkey.GetValue("DistributionName")
                    $basePath = $subkey.GetValue("BasePath")
                    if ($distName) {
                        if ($basePath -and (Test-Path $basePath)) {
                            Remove-Item -Path $basePath -Recurse -Force -ErrorAction SilentlyContinue
                        }
                        Remove-Item -Path $subkey.PSPath -Recurse -Force -ErrorAction SilentlyContinue
                    }
                }
                Remove-Item -Path $lxssPath -Recurse -Force -ErrorAction SilentlyContinue
            }
        } else {
            # Cargar colmena offline NTUSER.DAT
            $ntuserPath = Join-Path $profileImagePath "NTUSER.DAT"
            if (Test-Path $ntuserPath) {
                $tempHiveName = "Temp_$sid"
                $loaded = $false
                try {
                    & reg.exe load "HKU\$tempHiveName" "$ntuserPath" 2>&1 | Out-Null
                    if ($LASTEXITCODE -eq 0) {
                        $loaded = $true
                        $lxssPath = "Registry::HKEY_USERS\$tempHiveName\Software\Microsoft\Windows\CurrentVersion\Lxss"
                        if (Test-Path $lxssPath) {
                            $subkeys = Get-ChildItem -Path $lxssPath -ErrorAction SilentlyContinue
                            foreach ($subkey in $subkeys) {
                                $distName = $subkey.GetValue("DistributionName")
                                $basePath = $subkey.GetValue("BasePath")
                                if ($distName) {
                                    if ($basePath -and (Test-Path $basePath)) {
                                        Remove-Item -Path $basePath -Recurse -Force -ErrorAction SilentlyContinue
                                    }
                                    Remove-Item -Path $subkey.PSPath -Recurse -Force -ErrorAction SilentlyContinue
                                }
                            }
                            Remove-Item -Path $lxssPath -Recurse -Force -ErrorAction SilentlyContinue
                        }
                    }
                } catch {
                    Write-Error "Error al procesar la colmena offline del usuario ${sid}: $_"
                } finally {
                    if ($loaded) {
                        [GC]::Collect()
                        [GC]::WaitForPendingFinalizers()
                        & reg.exe unload "HKU\$tempHiveName" 2>&1 | Out-Null
                    }
                }
            }
        }
    }
}

# 3. Desinstalar el paquete AppX del componente WSL (Moderno)
try {
    $wslAppx = Get-AppxPackage -AllUsers -Name "MicrosoftCorporationII.WindowsSubsystemforLinux" -ErrorAction SilentlyContinue
    if ($wslAppx) {
        Get-AppxPackage -AllUsers -Name "MicrosoftCorporationII.WindowsSubsystemforLinux" | Remove-AppxPackage -AllUsers -ErrorAction SilentlyContinue
    }
    # Desprovisionar para evitar que se reinstale en nuevos usuarios
    $wslProvAppx = Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -eq "MicrosoftCorporationII.WindowsSubsystemforLinux" }
    if ($wslProvAppx) {
        Remove-AppxProvisionedPackage -Online -PackageName $wslProvAppx.PackageName -ErrorAction SilentlyContinue
    }
} catch {
    Write-Error "Error al desinstalar el paquete AppX de WSL: $_"
}

# 4. Desinstalar distribuciones de Linux instaladas via Microsoft Store o sideload
$linuxDistroPatterns = @(
    "CanonicalGroupLimited*",   # Ubuntu (todas las versiones)
    "*Debian*",
    "*Kali*",
    "*openSUSE*",
    "*SUSE*",
    "*OracleLinux*",
    "*AlmaLinux*",
    "*Fedora*",
    "*Pengwin*"                 # Whitewater Foundry
)
try {
    foreach ($pattern in $linuxDistroPatterns) {
        # Desinstalar para todos los usuarios activos
        $pkgs = Get-AppxPackage -AllUsers -Name $pattern -ErrorAction SilentlyContinue
        if ($pkgs) {
            $pkgs | Remove-AppxPackage -AllUsers -ErrorAction SilentlyContinue
        }
        # Desprovisionar de la imagen de Windows
        $provPkgs = Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -like $pattern }
        foreach ($provPkg in $provPkgs) {
            Remove-AppxProvisionedPackage -Online -PackageName $provPkg.PackageName -ErrorAction SilentlyContinue
        }
    }
} catch {
    Write-Error "Error al desinstalar distribuciones Linux AppX: $_"
}

# 5. Desinstalar el instalador MSI de WSL (Clasico) si se encuentra registrado
$msiKeys = @(
    "HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall",
    "HKLM:\Software\Wow6432Node\Software\Microsoft\Windows\CurrentVersion\Uninstall"
)
foreach ($keyPath in $msiKeys) {
    if (Test-Path $keyPath) {
        $keys = Get-ChildItem -Path $keyPath -ErrorAction SilentlyContinue
        foreach ($k in $keys) {
            $displayName = $k.GetValue("DisplayName")
            if ($displayName -and ($displayName -like "*Windows Subsystem for Linux*" -or $displayName -eq "WSL")) {
                $uninstallString = $k.GetValue("UninstallString")
                if ($uninstallString -match '({[A-Fa-f0-9-]+})') {
                    $guid = $Matches[1]
                    Start-Process msiexec.exe -ArgumentList "/x $guid /qn /norestart" -Wait -NoNewWindow
                }
            }
        }
    }
}

# 6. Deshabilitar la caracteristica opcional de Windows para WSL
try {
    $wslFeature = Get-WindowsOptionalFeature -Online -FeatureName "Microsoft-Windows-Subsystem-Linux" -ErrorAction SilentlyContinue
    if ($null -ne $wslFeature -and $wslFeature.State -eq "Enabled") {
        Disable-WindowsOptionalFeature -Online -FeatureName "Microsoft-Windows-Subsystem-Linux" -NoRestart -ErrorAction SilentlyContinue | Out-Null
    }
} catch {
    Write-Error "Error al deshabilitar la caracteristica opcional de WSL: $_"
}

# 7. Limpieza de binarios residuales
$wslInstallDir = "C:\Program Files\WSL"
if (Test-Path $wslInstallDir) {
    Remove-Item -Path $wslInstallDir -Recurse -Force -ErrorAction SilentlyContinue
}

Write-Output "Remediacion completada. Se puede requerir reinicio para finalizar la desinstalacion."
exit 0
