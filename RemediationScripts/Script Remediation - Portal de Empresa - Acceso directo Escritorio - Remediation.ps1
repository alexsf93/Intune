<#
.SYNOPSIS
    REMEDIATION SCRIPT: CREAR ACCESO DIRECTO UNICO DE PORTAL DE EMPRESA CON ICONO OFICIAL Y PURGAR DUPLICADOS DE ONEDRIVE (SOPORTE ES/EN + LOGS)

.DESCRIPTION
    Script de remediacion desatendida para Microsoft Intune (contexto SYSTEM).
    Asume que la aplicacion Portal de Empresa (Company Portal) se despliega como aplicacion UWP desde Intune.
    
    Acciones realizadas:
    1. Registra logs locales detallados en C:\ProgramData\Microsoft\IntuneManagementExtension\Logs.
    2. Verifica que la aplicacion Microsoft.CompanyPortal este instalada. Si no lo esta, sale limpiamente sin error.
    3. Determina el idioma del sistema operativo (espanol / ingles):
       - Equipos en ingles: Crea "Company Portal.lnk" y elimina "Portal de Empresa.lnk" de Public Desktop.
       - Equipos en espanol / otros: Crea "Portal de Empresa.lnk" y elimina "Company Portal.lnk" de Public Desktop.
    4. Garantiza el icono oficial de Microsoft Company Portal (.ico) en C:\ProgramData\Microsoft\CompanyPortal\CompanyPortal.ico:
       - Metodo 1 (Online): Descarga directa del icono oficial de alta fidelidad desde GitHub:
         https://raw.githubusercontent.com/VCCRI/CompanyPortal/main/Company-Portal-Icon.ico
       - Metodo 2 (Offline Fallback): Payload Base64 embebido de 240x240 con la fidelidad exacta de color corporativo Fluent.
       - Asigna permisos de lectura explicitos para todos los usuarios (BUILTIN\Users).
    5. Crea un UNICO acceso directo canonico en el Escritorio Publico:
       C:\Users\Public\Desktop\<Nombre>.lnk -> explorer.exe shell:AppsFolder\Microsoft.CompanyPortal_8wekyb3d8bbwe!App
       - Visible para TODOS los usuarios locales de la maquina sin duplicados.
       - OneDrive KFM NUNCA sincroniza el Escritorio Publico, evitando subidas a la nube y duplicidades.
       - Apunta de forma explicita al archivo .ico oficial de Company Portal.
    6. Purga todos los accesos directos duplicados o residuales de los perfiles de usuario y carpetas de OneDrive
       (tanto en 'Desktop' como en 'Escritorio', y variantes como 'Portal de Empresa', 'Company Portal', copias, etc.).
    7. Invalida y refresca la cache del shell de Windows (SHChangeNotify e ie4uinit).

.PARAMETER
    Ninguno.

.EXAMPLE
    Executes as Intune Remediation Script.

.NOTES
    Name:       Script Remediation - Portal de Empresa - Acceso directo Escritorio - Remediation.ps1
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
$logFile = Join-Path $logFolder "PortalDeEmpresa_Shortcut_Remediation.log"

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

Write-Log "=== INICIANDO REMEDIACION ACCESO DIRECTO PORTAL DE EMPRESA (v4.1.0) ===" "INFO"
Write-Log "Ejecutando en contexto: $([System.Security.Principal.WindowsIdentity]::GetCurrent().Name) en equipo: $env:COMPUTERNAME" "INFO"

# Cargar tipos Win32 auxiliares para refresco de shell
try {
    $shellCode = @"
using System;
using System.Runtime.InteropServices;
public class ShellRefreshHelper {
    [DllImport("shell32.dll")]
    public static extern void SHChangeNotify(int wEventId, uint uFlags, IntPtr dwItem1, IntPtr dwItem2);
}
"@
    if (-not ([System.Management.Automation.PSTypeName]'ShellRefreshHelper').Type) {
        Add-Type -TypeDefinition $shellCode -ErrorAction SilentlyContinue
    }
} catch {}

# ==============================================================================
# 1. DETERMINACION DEL IDIOMA DEL SISTEMA
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
    $shortcutDesc  = "Company Portal"
} else {
    $canonicalName = "Portal de Empresa.lnk"
    $redundantName = "Company Portal.lnk"
    $shortcutDesc  = "Portal de Empresa"
}

$publicDesktop = "$env:PUBLIC\Desktop"
$canonicalPath = Join-Path $publicDesktop $canonicalName
$redundantPath = Join-Path $publicDesktop $redundantName
$targetAUMID   = "shell:AppsFolder\Microsoft.CompanyPortal_8wekyb3d8bbwe!App"

Write-Log "Configuracion: Canonico='$canonicalName' | Redundante a purgar='$redundantName'" "INFO"

# ==============================================================================
# 2. VERIFICAR QUE COMPANY PORTAL (UWP) ESTA INSTALADO
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
    $msgNotInst = "Aviso: Portal de Empresa / Company Portal (UWP) no esta instalado todavia en el equipo. La instalacion corresponde a la aplicacion de Intune Store."
    Write-Log $msgNotInst "WARN"
    Write-Output $msgNotInst
    Exit 0
}

# ==============================================================================
# 3. GARANTIZAR ICONO OFICIAL DE MARCA (.ICO) EN RUTA PUBLICA
# ==============================================================================
$iconDir = "$env:ProgramData\Microsoft\CompanyPortal"
if (-not (Test-Path $iconDir)) {
    try { New-Item -Path $iconDir -ItemType Directory -Force | Out-Null } catch {}
}
$iconFilePath = Join-Path $iconDir "CompanyPortal_Fluent.ico"

# Limpiar posibles iconos de versiones previas con cache persistente en Explorer
@('CompanyPortal.ico', 'CompanyPortal.png') | ForEach-Object {
    $oldFile = Join-Path $iconDir $_
    if (Test-Path $oldFile) {
        Remove-Item -Path $oldFile -Force -ErrorAction SilentlyContinue
    }
}


$iconGitHubUrl = "https://raw.githubusercontent.com/VCCRI/CompanyPortal/main/Company-Portal-Icon.ico"
$iconReady = $false

# Metodo 1: Descarga directa del icono oficial de GitHub
try {
    Write-Log "Intentando descargar icono oficial desde: $iconGitHubUrl" "INFO"
    [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor [System.Net.SecurityProtocolType]::Tls12
    $wc = New-Object System.Net.WebClient
    $wc.Headers.Add("User-Agent", "Mozilla/5.0 (Windows NT 10.0; Win64; x64) IntuneRemediation")
    $wc.DownloadFile($iconGitHubUrl, $iconFilePath)
    $wc.Dispose()
    
    if ((Test-Path $iconFilePath) -and ((Get-Item $iconFilePath).Length -gt 1000)) {
        $iconReady = $true
        Write-Log "Icono oficial descargado correctamente desde GitHub ($((Get-Item $iconFilePath).Length) bytes)." "SUCCESS"
    }
} catch {
    Write-Log "Aviso: No se pudo descargar desde GitHub ($($_.Exception.Message)). Se usara el payload Base64 embebido." "WARN"
}

# Metodo 2: Fallback 100% offline mediante payload Base64 embebido
if (-not $iconReady -or (-not (Test-Path $iconFilePath)) -or ((Get-Item $iconFilePath).Length -lt 1000)) {
    try {
        Write-Log "Desplegando icono oficial desde payload Base64 embebido..." "INFO"
        $b64Icon = "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"
        $bytes = [System.Convert]::FromBase64String($b64Icon)
        [System.IO.File]::WriteAllBytes($iconFilePath, $bytes)
        $iconReady = $true
        Write-Log "Icono oficial generado con exito desde payload Base64 ($($bytes.Length) bytes)." "SUCCESS"
    } catch {
        Write-Log "Error al desplegar icono desde Base64: $($_.Exception.Message)" "ERROR"
    }
}

# Asegurar permisos de lectura explicitos para todos los usuarios (BUILTIN\Users)
if (Test-Path $iconFilePath) {
    try {
        $acl = Get-Acl $iconFilePath
        $rule = New-Object System.Security.AccessControl.FileSystemAccessRule("Users", "ReadAndExecute", "Allow")
        $acl.AddAccessRule($rule)
        Set-Acl -Path $iconFilePath -AclObject $acl
        Write-Log "Permisos de lectura asignados a BUILTIN\Users en $iconFilePath" "INFO"
    } catch {
        Write-Log "Aviso al asignar ACLs en '$iconFilePath' - $($_.Exception.Message)" "WARN"
    }
}

# ==============================================================================
# 4. CREAR ACCESO DIRECTO OPERATIVO EN ESCRITORIO PUBLICO
# ==============================================================================
if (-not (Test-Path $publicDesktop)) {
    try {
        New-Item -Path $publicDesktop -ItemType Directory -Force | Out-Null
        Write-Log "Directorio de Escritorio Publico creado: $publicDesktop" "INFO"
    } catch {
        Write-Log "Error al crear directorio '$publicDesktop' - $($_.Exception.Message)" "ERROR"
    }
}

try {
    # Eliminar cualquier version previa del acceso directo para forzar refresco
    if (Test-Path $canonicalPath) {
        Remove-Item -Path $canonicalPath -Force -ErrorAction SilentlyContinue
    }

    $wsh = New-Object -ComObject WScript.Shell
    $sc = $wsh.CreateShortcut($canonicalPath)
    $sc.TargetPath       = "$env:SystemRoot\explorer.exe"
    $sc.Arguments        = $targetAUMID
    $sc.WorkingDirectory = "$env:SystemRoot"
    $sc.Description      = $shortcutDesc

    # Icono: usar el .ico oficial en ProgramData
    if (Test-Path $iconFilePath) {
        $sc.IconLocation = "$iconFilePath,0"
        Write-Log "IconLocation apuntado al icono oficial: $iconFilePath,0" "INFO"
    } else {
        Write-Log "No se encontro archivo .ico; el acceso directo usara el icono generico de Windows." "WARN"
    }

    $sc.Save()
    [System.Runtime.InteropServices.Marshal]::ReleaseComObject($wsh) | Out-Null
    Write-Log "Acceso directo canonico creado/actualizado con exito en: $canonicalPath" "SUCCESS"
} catch {
    Write-Log "Error al crear el acceso directo en Escritorio Publico: $($_.Exception.Message)" "ERROR"
}

# Limpiar posible acceso directo del idioma opuesto/redundante en el Escritorio Publico
if (Test-Path -Path $redundantPath) {
    try {
        Remove-Item -Path $redundantPath -Force -ErrorAction SilentlyContinue
        Write-Log "Eliminado acceso directo redundante en otro idioma en Public Desktop: $redundantPath" "INFO"
    } catch {
        Write-Log "No se pudo eliminar el acceso redundante '$redundantPath' - $($_.Exception.Message)" "WARN"
    }
}

# Limpiar imagenes de prueba si existieran en el Escritorio Publico
@('Opcion1_Unplated.png', 'Opcion2_StoreLogo.png', 'Opcion3_MediumTile.png',
  '1_LightUnplated.png', '2_AppListScale100.png', '3_StoreLogo.png', '4_MediumTile.png') | ForEach-Object {
    $tempImg = Join-Path $publicDesktop $_
    if (Test-Path $tempImg) {
        Remove-Item -Path $tempImg -Force -ErrorAction SilentlyContinue
    }
}

# ==============================================================================
# 5. PURGAR DUPLICADOS EN PERFILES DE USUARIO Y ONEDRIVE
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

function Test-IsPortalDuplicate {
    param ([string]$FilePath)
    $leaf = Split-Path -Leaf $FilePath
    if ($leaf -match '(?i)^(Portal de Empresa|Company Portal)') { return $true }
    if (Test-ShortcutPointsToPortal -Path $FilePath) { return $true }
    return $false
}

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
    # 1. Escritorios locales estandar (espanol e ingles)
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

$deletedCount = 0

foreach ($d in ($userDesktops | Select-Object -Unique)) {
    Get-ChildItem -Path $d -Filter "*.lnk" -ErrorAction SilentlyContinue | Where-Object {
        Test-IsPortalDuplicate -FilePath $_.FullName
    } | ForEach-Object {
        try {
            Remove-Item -Path $_.FullName -Force -ErrorAction SilentlyContinue
            Write-Log "Duplicado de usuario eliminado: $($_.FullName)" "INFO"
            $deletedCount++
        } catch {
            Write-Log "Fallo al eliminar duplicado '$($_.FullName)' - $($_.Exception.Message)" "WARN"
        }
    }
}

Write-Log "Total de accesos directos duplicados purgados: $deletedCount" "INFO"

# ==============================================================================
# 6. REFRESCAR LA CACHE DEL SHELL DE WINDOWS
# ==============================================================================
try {
    # Actualizar la fecha del fichero para forzar a Explorer a invalidar cualquier cache previa
    if (Test-Path $canonicalPath) {
        (Get-Item $canonicalPath).LastWriteTime = (Get-Date)
    }

    # SHCNE_ASSOCCHANGED = 0x08000000 (Fuerza refresco de iconos y asociaciones en Explorer)
    if (([System.Management.Automation.PSTypeName]'ShellRefreshHelper').Type) {
        [ShellRefreshHelper]::SHChangeNotify(0x08000000, 0, [IntPtr]::Zero, [IntPtr]::Zero)
    }

    # Forzar refresco de cache de iconos de Windows (ie4uinit)
    Start-Process "$env:SystemRoot\system32\ie4uinit.exe" -ArgumentList "-show" -WindowStyle Hidden -ErrorAction SilentlyContinue
    
    Write-Log "Notificacion SHChangeNotify e ie4uinit enviadas al shell de Windows." "INFO"
} catch {
    Write-Log "Aviso al refrescar shell: $($_.Exception.Message)" "WARN"
}

# ==============================================================================
# 7. VALIDACION FINAL DEL ACCESO PUBLICO
# ==============================================================================
if (Test-Path -Path $canonicalPath) {
    $msgSuccess = "Remediado: Acceso directo ($canonicalName) garantizado con icono oficial en Escritorio Publico y $deletedCount duplicado(s) de OneDrive/usuario eliminados."
    Write-Log $msgSuccess "SUCCESS"
    Write-Output $msgSuccess
    Exit 0
} else {
    $msgFail = "Error: No se pudo garantizar la existencia del acceso directo ($canonicalName) en el Escritorio Publico."
    Write-Log $msgFail "ERROR"
    Write-Output $msgFail
    Exit 1
}
