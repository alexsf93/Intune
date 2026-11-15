<#
.SYNOPSIS
    DETECTION SCRIPT: VERIFICAR ACCESO DIRECTO DE PORTAL DE EMPRESA Y AUSENCIA DE DUPLICADOS (SOPORTE ES/EN + LOGS + ICONO OFICIAL)

.DESCRIPTION
    Script de deteccion para Microsoft Intune (contexto SYSTEM).
    Asume que la aplicacion Portal de Empresa (Company Portal) se despliega como aplicacion UWP
    desde la Microsoft Store a traves de Intune.
    
    Logica de evaluacion:
    1. Si Company Portal NO esta instalado todavia: Sale con Exit 0 (Compliant). La aplicacion aun no
       ha sido aprovisionada por Intune, por lo que no procede generar alertas falsas de remediacion.
    2. Deteccion de idioma del sistema operativo (espanol / ingles):
       - Si el SO esta en ingles: Nombre canonico = "Company Portal.lnk" (y "Portal de Empresa.lnk" es redundante).
       - Si el SO esta en espanol u otro: Nombre canonico = "Portal de Empresa.lnk" (y "Company Portal.lnk" es redundante).
    3. Si Company Portal SI esta instalado:
       - Verifica que exista el acceso directo canonico en C:\Users\Public\Desktop.
       - Valida que el acceso directo apunte a la AUMID oficial (Microsoft.CompanyPortal_8wekyb3d8bbwe!App).
       - Verifica que el archivo de icono oficial exista en C:\ProgramData\Microsoft\CompanyPortal\CompanyPortal.ico.
       - Valida que el acceso directo apunte al archivo .ico oficial como IconLocation.
       - Verifica que no exista el acceso directo redundante del idioma opuesto en el Escritorio Publico.
       - Verifica que NO existan copias duplicadas en los escritorios personales de los usuarios ni en
         carpetas sincronizadas por OneDrive (Known Folder Move / KFM).
    4. Registro de auditoria local (Log) en C:\ProgramData\Microsoft\IntuneManagementExtension\Logs.
    
    Salida Intune:
    - Exit 0: Compliant (Acceso directo correcto, icono oficial valido y sin duplicados, o app no instalada).
    - Exit 1: Non-Compliant (Falta el acceso directo publico, icono desalineado, idioma incorrecto o duplicados en carpetas de usuario/OneDrive).

.PARAMETER
    Ninguno.

.EXAMPLE
    Executes as Intune Detection Script.

.NOTES
    Name:       Script Remediation - Portal de Empresa - Acceso directo Escritorio - Detection.ps1
    Author:     Alejandro Suarez (@alexsf93)
    Date:       2026-11-15
    Version:    4.1.0
    Context:    System
#>

$ErrorActionPreference = 'SilentlyContinue'

# ==============================================================================
# CONFIGURACION DEL SISTEMA DE LOGS LOCAL (Compatible con "Collect Diagnostics")
# ==============================================================================
$logFolder = "$env:ProgramData\Microsoft\IntuneManagementExtension\Logs"
if (-not (Test-Path -Path $logFolder)) {
    $logFolder = "$env:ProgramData\IntuneLogs"
    if (-not (Test-Path -Path $logFolder)) {
        try { New-Item -Path $logFolder -ItemType Directory -Force | Out-Null } catch {}
    }
}
$logFile = Join-Path $logFolder "PortalDeEmpresa_Shortcut_Detection.log"

# Rotacion sencilla: si supera 2MB, renueva el log
if (Test-Path $logFile) {
    if ((Get-Item $logFile).Length -gt 2MB) {
        Remove-Item $logFile -Force -ErrorAction SilentlyContinue
    }
}

function Write-Log {
    param (
        [Parameter(Mandatory = $true)][string]$Message,
        [ValidateSet('INFO', 'WARN', 'ERROR', 'SUCCESS')][string]$Level = 'INFO'
    )
    $stamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    $line = "[$stamp] [$Level] $Message"
    try {
        Add-Content -Path $logFile -Value $line -Encoding UTF8 -ErrorAction SilentlyContinue
    } catch {}
    Write-Host $line
}

Write-Log "=== INICIANDO DETECCION ACCESO DIRECTO PORTAL DE EMPRESA (v4.1.0) ===" "INFO"
Write-Log "Ejecutando en contexto: $([System.Security.Principal.WindowsIdentity]::GetCurrent().Name) en equipo: $env:COMPUTERNAME" "INFO"

# ==============================================================================
# 1. DETECCION DEL IDIOMA DEL SISTEMA OPERATIVO
# ==============================================================================
function Test-IsEnglishSystem {
    try {
        $uic = [System.Globalization.CultureInfo]::InstalledUICulture.TwoLetterISOLanguageName
        if ($uic -eq 'en') {
            Write-Log "Idioma detectado por InstalledUICulture: '$uic' (Ingles)" "INFO"
            return $true
        }

        $cur = [System.Globalization.CultureInfo]::CurrentUICulture.TwoLetterISOLanguageName
        if ($cur -eq 'en') {
            Write-Log "Idioma detectado por CurrentUICulture: '$cur' (Ingles)" "INFO"
            return $true
        }

        $sysLocale = Get-WinSystemLocale -ErrorAction SilentlyContinue
        if ($sysLocale -and $sysLocale.Name -like 'en*') {
            Write-Log "Idioma detectado por Get-WinSystemLocale: '$($sysLocale.Name)' (Ingles)" "INFO"
            return $true
        }

        $mui = (Get-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\MUI\Settings" -ErrorAction SilentlyContinue).PreferredUILanguages
        if ($mui -and ($mui[0] -like "en*")) {
            Write-Log "Idioma detectado por MUI PreferredUILanguages: '$($mui[0])' (Ingles)" "INFO"
            return $true
        }

        $installLang = (Get-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Nls\Language" -ErrorAction SilentlyContinue).InstallLanguage
        if ($installLang -match '09$') {
            Write-Log "Idioma detectado por NLS InstallLanguage: '$installLang' (Ingles)" "INFO"
            return $true
        }
        Write-Log "Idioma detectado: Espanol/Otro (InstalledUICulture='$uic', CurrentUICulture='$cur')" "INFO"
    } catch {
        Write-Log "Excepcion al evaluar idioma: $($_.Exception.Message). Usando Espanol por defecto." "WARN"
    }
    return $false
}

$isEnglish = Test-IsEnglishSystem

if ($isEnglish) {
    $canonicalName = "Company Portal.lnk"
    $redundantName = "Portal de Empresa.lnk"
} else {
    $canonicalName = "Portal de Empresa.lnk"
    $redundantName = "Company Portal.lnk"
}

$publicDesktop = "$env:PUBLIC\Desktop"
$canonicalPath = Join-Path $publicDesktop $canonicalName
$redundantPath = Join-Path $publicDesktop $redundantName
$targetAUMID   = "shell:AppsFolder\Microsoft.CompanyPortal_8wekyb3d8bbwe!App"
$iconDir       = "$env:ProgramData\Microsoft\CompanyPortal"
$iconFilePath  = Join-Path $iconDir "CompanyPortal_Fluent.ico"

Write-Log "Nombre canonico asignado: '$canonicalName' | Redundante a purgar: '$redundantName'" "INFO"

# ==============================================================================
# 2. VERIFICACION DE INSTALACION DE PORTAL DE EMPRESA (UWP)
# ==============================================================================
function Test-CompanyPortalInstalled {
    $p1 = Get-AppxPackage -AllUsers -Name "*CompanyPortal*" -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($p1) {
        Write-Log "Company Portal detectado via AppX (-AllUsers): $($p1.PackageFullName)" "INFO"
        return $true
    }

    $p2 = Get-AppxPackage -Name "*CompanyPortal*" -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($p2) {
        Write-Log "Company Portal detectado via AppX (CurrentUser): $($p2.PackageFullName)" "INFO"
        return $true
    }

    $p3 = Get-ChildItem "C:\Program Files\WindowsApps\*CompanyPortal*" -Directory -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($p3) {
        Write-Log "Company Portal detectado en directorio fisico: $($p3.FullName)" "INFO"
        return $true
    }

    return $false
}

if (-not (Test-CompanyPortalInstalled)) {
    $msgCompliantNotInstalled = "Compliant: Portal de Empresa / Company Portal no esta instalado todavia en este equipo. No procede crear acceso directo."
    Write-Log $msgCompliantNotInstalled "SUCCESS"
    Write-Output $msgCompliantNotInstalled
    Exit 0
}

$issues = [System.Collections.Generic.List[string]]::new()

# ==============================================================================
# 3. VALIDACION DEL ACCESO DIRECTO EN ESCRITORIO PUBLICO
# ==============================================================================
function Test-ShortcutPointsToPortal {
    param ([string]$Path)
    if (-not (Test-Path -Path $Path)) { return $false }

    try {
        $dir = Split-Path -Parent $Path
        $leaf = Split-Path -Leaf $Path
        $sh = New-Object -ComObject Shell.Application
        $folder = $sh.NameSpace($dir)
        $item = $folder.ParseName($leaf)
        if ($item -and $item.GetLink) {
            $link = $item.GetLink
            $t = $link.Target.Path
            $a = $link.Arguments
            if ($t -match '(?i)Microsoft\.CompanyPortal_8wekyb3d8bbwe!App' -or $a -match '(?i)Microsoft\.CompanyPortal_8wekyb3d8bbwe!App') {
                [System.Runtime.InteropServices.Marshal]::ReleaseComObject($sh) | Out-Null
                return $true
            }
        }
        if ($sh) { [System.Runtime.InteropServices.Marshal]::ReleaseComObject($sh) | Out-Null }
    } catch {}

    try {
        $bytes = [System.IO.File]::ReadAllBytes($Path)
        $text = [System.Text.Encoding]::Unicode.GetString($bytes) + [System.Text.Encoding]::ASCII.GetString($bytes)
        if ($text -match '(?i)Microsoft\.CompanyPortal_8wekyb3d8bbwe!App') {
            return $true
        }
    } catch {}

    return $false
}

function Get-ShortcutIconLocation {
    param ([string]$Path)
    if (-not (Test-Path -Path $Path)) { return "" }
    try {
        $wsh = New-Object -ComObject WScript.Shell
        $sc = $wsh.CreateShortcut($Path)
        $loc = $sc.IconLocation
        [System.Runtime.InteropServices.Marshal]::ReleaseComObject($wsh) | Out-Null
        return $loc
    } catch {
        return ""
    }
}

if (-not (Test-Path -Path $canonicalPath)) {
    $issues.Add("Falta el acceso directo canonico ($canonicalName) en el Escritorio Publico ($canonicalPath).")
    Write-Log "Falta el acceso directo canonico en: $canonicalPath" "WARN"
} elseif (-not (Test-ShortcutPointsToPortal -Path $canonicalPath)) {
    $issues.Add("El acceso directo en Escritorio Publico ($canonicalName) existe pero no apunta a la AUMID de Portal de Empresa.")
    Write-Log "El acceso directo en $canonicalPath no apunta a la AUMID oficial." "WARN"
} else {
    Write-Log "Acceso directo canonico verificado correctamente en: $canonicalPath" "INFO"
    
    # Validar que el icono oficial este presente y asignado al acceso directo
    if (-not (Test-Path -Path $iconFilePath) -or ((Get-Item -Path $iconFilePath).Length -lt 1000)) {
        $issues.Add("El archivo de icono oficial no existe o es invalido en $iconFilePath.")
        Write-Log "Falta el archivo de icono oficial en: $iconFilePath" "WARN"
    } else {
        $currentIcon = Get-ShortcutIconLocation -Path $canonicalPath
        if ($currentIcon -notlike "*CompanyPortal_Fluent.ico*") {
            $issues.Add("El acceso directo existe pero no tiene asignado el icono oficial ($iconFilePath). IconLocation actual: '$currentIcon'")
            Write-Log "IconLocation desalineado en el acceso directo: '$currentIcon'" "WARN"
        }
    }
}

# Comprobar si existe el acceso directo del idioma opuesto/redundante en Public Desktop
if (Test-Path -Path $redundantPath) {
    $issues.Add("Existe acceso directo redundante en otro idioma en Public Desktop ($redundantPath).")
    Write-Log "Detectado acceso redundante en Public Desktop: $redundantPath" "WARN"
}

# ==============================================================================
# 4. DETECCION DE DUPLICADOS EN PERFILES DE USUARIO Y ONEDRIVE
# ==============================================================================
$userDesktops = [System.Collections.Generic.List[string]]::new()
$excludedProfiles = @('Public', 'All Users', 'Default', 'Default User', 'WDAGUtilityAccount')
$profileDirs = [System.Collections.Generic.List[string]]::new()

try {
    Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList\*" -ErrorAction SilentlyContinue | Where-Object {
        $_.ProfileImagePath -like "C:\Users\*" -and $_.ProfileImagePath -notmatch '\\(Public|All Users|Default|Default User)$'
    } | ForEach-Object {
        if (Test-Path $_.ProfileImagePath) { $profileDirs.Add($_.ProfileImagePath) }
    }
} catch {}

if ($profileDirs.Count -eq 0) {
    Get-ChildItem -Path "C:\Users" -Directory -ErrorAction SilentlyContinue | Where-Object {
        $_.Name -notin $excludedProfiles
    } | ForEach-Object { $profileDirs.Add($_.FullName) }
}

foreach ($p in ($profileDirs | Select-Object -Unique)) {
    # 1. Escritorios locales estandar
    foreach ($sub in @('Desktop', 'Escritorio')) {
        $loc = Join-Path $p $sub
        if (Test-Path $loc) { $userDesktops.Add($loc) }
    }

    # 2. Escritorios sincronizados por OneDrive (KFM)
    Get-ChildItem -Path $p -Directory -Filter "*OneDrive*" -ErrorAction SilentlyContinue | ForEach-Object {
        $odBase = $_.FullName
        foreach ($sub in @('Desktop', 'Escritorio')) {
            $odLoc = Join-Path $odBase $sub
            if (Test-Path $odLoc) { $userDesktops.Add($odLoc) }
        }
    }
}

Write-Log "Total de carpetas de escritorio de usuarios/OneDrive a inspeccionar: $($userDesktops.Count)" "INFO"

$duplicateShortcuts = [System.Collections.Generic.List[string]]::new()

function Test-IsPortalDuplicate {
    param ([string]$FilePath)
    $leaf = Split-Path -Leaf $FilePath
    if ($leaf -match '(?i)^(Portal de Empresa|Company Portal)') { return $true }
    if (Test-ShortcutPointsToPortal -Path $FilePath) { return $true }
    return $false
}

foreach ($d in ($userDesktops | Select-Object -Unique)) {
    Get-ChildItem -Path $d -Filter "*.lnk" -ErrorAction SilentlyContinue | Where-Object {
        Test-IsPortalDuplicate -FilePath $_.FullName
    } | ForEach-Object {
        $duplicateShortcuts.Add($_.FullName)
        Write-Log "Duplicado detectado: $($_.FullName)" "WARN"
    }
}

if ($duplicateShortcuts.Count -gt 0) {
    $issues.Add("Se detectaron $($duplicateShortcuts.Count) acceso(s) directo(s) duplicado(s) en carpetas de usuario o OneDrive:")
    $duplicateShortcuts | ForEach-Object { $issues.Add("   -> $_") }
}

# ==============================================================================
# 5. EVALUACION FINAL PARA INTUNE
# ==============================================================================
if ($issues.Count -gt 0) {
    $msgNonCompliant = "Non-Compliant: Portal de Empresa esta instalado pero se detectaron $($issues.Count) discrepancia(s):"
    Write-Log $msgNonCompliant "WARN"
    Write-Output $msgNonCompliant
    $issues | ForEach-Object {
        Write-Log " - $_" "WARN"
        Write-Output " - $_"
    }
    Exit 1
}

$msgCompliant = "Compliant: Acceso directo ($canonicalName) e icono oficial verificados en Escritorio Publico y 0 duplicados en OneDrive."
Write-Log $msgCompliant "SUCCESS"
Write-Output $msgCompliant
Exit 0
