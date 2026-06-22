<#
.SYNOPSIS
    DETECTION SCRIPT: DETECTAR INSTALACION DE WSL Y DISTRIBUCIONES

.DESCRIPTION
    Comprueba si Windows Subsystem for Linux (WSL) esta presente en el sistema, cubriendo
    todas las vias de instalacion conocidas:
      - Caracteristica opcional de Windows (DISM / Enable-WindowsOptionalFeature)
      - Paquete AppX del componente WSL (Microsoft Store / winget)
      - Instalador MSI clasico de WSL
      - Binarios de WSL instalados localmente (C:\Program Files\WSL)
      - Servicio de Windows wslservice
      - Paquetes AppX de distribuciones de Linux (Store / sideload)
      - Claves de registro Lxss de distribuciones para todos los usuarios del equipo

.PARAMETER
    Ninguno.

.EXAMPLE
    Executes as Intune Detection Script.

.NOTES
    Name: Script Remediation - Desinstalar WSL - Detection.ps1
    Author: Alejandro Suarez (@alexsf93)
    Version: 1.1.0
    Date: 2026-06-22
    Context: System
#>

$WslDetected = $false
$DetectionReasons = [System.Collections.Generic.List[string]]::new()

# ─────────────────────────────────────────────────────────────────────────────
# 1. Caracteristica opcional de Windows
# ─────────────────────────────────────────────────────────────────────────────
try {
    $feature = Get-WindowsOptionalFeature -Online -FeatureName "Microsoft-Windows-Subsystem-Linux" -ErrorAction SilentlyContinue
    if ($null -ne $feature -and $feature.State -eq "Enabled") {
        $WslDetected = $true
        $DetectionReasons.Add("Caracteristica opcional habilitada")
    }
} catch {}

# ─────────────────────────────────────────────────────────────────────────────
# 2. Binarios de WSL instalados localmente (instalacion via Store / binarios)
# ─────────────────────────────────────────────────────────────────────────────
if (Test-Path "C:\Program Files\WSL\wsl.exe") {
    $wslBin = Get-Item "C:\Program Files\WSL\wsl.exe" -ErrorAction SilentlyContinue
    # El stub de System32 pesa ~250 KB; el binario real pesa varios MB
    if ($null -ne $wslBin -and $wslBin.Length -gt 500KB) {
        $WslDetected = $true
        $DetectionReasons.Add("Binario wsl.exe en 'C:\Program Files\WSL'")
    }
}

# ─────────────────────────────────────────────────────────────────────────────
# 3. Servicio wslservice
# ─────────────────────────────────────────────────────────────────────────────
$wslSvc = Get-Service -Name "wslservice" -ErrorAction SilentlyContinue
if ($null -ne $wslSvc) {
    $WslDetected = $true
    $DetectionReasons.Add("Servicio wslservice presente (Estado: $($wslSvc.Status))")
}

# ─────────────────────────────────────────────────────────────────────────────
# 4. Paquete AppX del componente WSL (Microsoft Store / winget / sideload)
# ─────────────────────────────────────────────────────────────────────────────
try {
    $wslAppx = Get-AppxPackage -AllUsers -Name "MicrosoftCorporationII.WindowsSubsystemforLinux" -ErrorAction SilentlyContinue
    if ($wslAppx) {
        $WslDetected = $true
        $DetectionReasons.Add("AppX WSL instalado ($($wslAppx.Version))")
    }
} catch {}

# ─────────────────────────────────────────────────────────────────────────────
# 5. Paquetes AppX de distribuciones de Linux (Store / sideload / manual)
# ─────────────────────────────────────────────────────────────────────────────
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
        $pkg = Get-AppxPackage -AllUsers -Name $pattern -ErrorAction SilentlyContinue
        if ($pkg) {
            $names = ($pkg | Select-Object -ExpandProperty Name) -join ", "
            $WslDetected = $true
            $DetectionReasons.Add("Distribucion Linux AppX detectada: $names")
            break
        }
    }
} catch {}

# 5b. Paquetes AppX provisionados (presentes en la imagen, aun sin usuarios)
try {
    $provPkgs = Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue
    $wslProvAppx = $provPkgs | Where-Object {
        $_.DisplayName -like "MicrosoftCorporationII.WindowsSubsystemforLinux" -or
        $_.DisplayName -like "CanonicalGroupLimited*" -or
        $_.DisplayName -like "*Debian*" -or
        $_.DisplayName -like "*Kali*"
    }
    if ($wslProvAppx) {
        $provNames = ($wslProvAppx | Select-Object -ExpandProperty DisplayName) -join ", "
        $WslDetected = $true
        $DetectionReasons.Add("AppX provisionado WSL/distro: $provNames")
    }
} catch {}

# ─────────────────────────────────────────────────────────────────────────────
# 6. Instalador MSI clasico de WSL (registro de desinstalacion en HKLM)
# ─────────────────────────────────────────────────────────────────────────────
$msiKeys = @(
    "HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall",
    "HKLM:\Software\Wow6432Node\Software\Microsoft\Windows\CurrentVersion\Uninstall"
)
foreach ($keyPath in $msiKeys) {
    if (-not (Test-Path $keyPath)) { continue }
    $keys = Get-ChildItem -Path $keyPath -ErrorAction SilentlyContinue
    foreach ($k in $keys) {
        $displayName = $k.GetValue("DisplayName")
        if ($displayName -and ($displayName -like "*Windows Subsystem for Linux*" -or $displayName -eq "WSL")) {
            $WslDetected = $true
            $DetectionReasons.Add("MSI instalado: $displayName")
        }
    }
}

# ─────────────────────────────────────────────────────────────────────────────
# 7. Claves de registro Lxss (distribuciones registradas por usuario)
# ─────────────────────────────────────────────────────────────────────────────
$profilesPath = "HKLM:\Software\Microsoft\Windows NT\CurrentVersion\ProfileList"
$detectedDistros = [System.Collections.Generic.List[string]]::new()

if (Test-Path $profilesPath) {
    $profiles = Get-ChildItem -Path $profilesPath -ErrorAction SilentlyContinue
    foreach ($profile in $profiles) {
        $sid = $profile.PSChildName
        if ($sid -notlike "S-1-5-21-*") { continue }

        $profileImagePath = $profile.GetValue("ProfileImagePath")
        if (-not $profileImagePath -or -not (Test-Path $profileImagePath)) { continue }

        $userHiveLoaded = Test-Path "Registry::HKEY_USERS\$sid"

        if ($userHiveLoaded) {
            $lxssPath = "Registry::HKEY_USERS\$sid\Software\Microsoft\Windows\CurrentVersion\Lxss"
            if (Test-Path $lxssPath) {
                Get-ChildItem -Path $lxssPath -ErrorAction SilentlyContinue | ForEach-Object {
                    $dn = $_.GetValue("DistributionName")
                    if ($dn) { $detectedDistros.Add($dn) }
                }
            }
        } else {
            $ntuserPath = Join-Path $profileImagePath "NTUSER.DAT"
            if (-not (Test-Path $ntuserPath)) { continue }

            $tempHiveName = "WslDetect_$sid"
            $loaded = $false
            try {
                & reg.exe load "HKU\$tempHiveName" "$ntuserPath" 2>&1 | Out-Null
                if ($LASTEXITCODE -eq 0) {
                    $loaded = $true
                    $lxssPath = "Registry::HKEY_USERS\$tempHiveName\Software\Microsoft\Windows\CurrentVersion\Lxss"
                    if (Test-Path $lxssPath) {
                        Get-ChildItem -Path $lxssPath -ErrorAction SilentlyContinue | ForEach-Object {
                            $dn = $_.GetValue("DistributionName")
                            if ($dn) { $detectedDistros.Add("$dn (offline)") }
                        }
                    }
                }
            } catch {
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

if ($detectedDistros.Count -gt 0) {
    $WslDetected = $true
    $DetectionReasons.Add("Distribuciones Lxss: $($detectedDistros -join ', ')")
}

# ─────────────────────────────────────────────────────────────────────────────
# Salida
# ─────────────────────────────────────────────────────────────────────────────
if ($WslDetected) {
    Write-Output "WSL detectado. $($DetectionReasons -join ' | ')"
    exit 1 # No conforme -> Ejecutar remediacion
} else {
    Write-Output "WSL no detectado."
    exit 0 # Conforme -> Sin accion requerida
}
