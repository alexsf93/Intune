<#
.SYNOPSIS
    REMEDIATION SCRIPT: INSTALACION AUTOMATICA DE MODULOS POWERSHELL PARA ADMINISTRACION CLOUD (M365, AZURE, INTUNE)

.DESCRIPTION
    Script de remediacion desatendida para Microsoft Intune.
    Se ejecuta automaticamente cuando el script de deteccion detecta que faltan uno o mas modulos en el equipo.

    Acciones correctivas:
    1. Habilita protocolos de seguridad modernos TLS 1.2 / TLS 1.3.
    2. Aprovisiona el proveedor de paquetes NuGet y marca PSGallery como de confianza (Trusted).
    3. Asegura la presencia y operatividad del motor de paquetes PowerShellGet (v2.x) en Windows PowerShell 5.1.
    4. Descarga e instala en el ambito 'AllUsers' (para todos los usuarios y perfiles) los modulos cloud requeridos:
       - Microsoft.Graph: Entra ID (Azure AD), Intune, Usuarios, Grupos y Seguridad M365.
       - ExchangeOnlineManagement: Exchange Online, Buzones y Cumplimiento (v3 REST).
       - Microsoft.Online.SharePoint.PowerShell: SharePoint Online y OneDrive for Business.
       - PnP.PowerShell: Automatizacion avanzada y aprovisionamiento SharePoint / M365.
       - MicrosoftTeams: Gestion de Microsoft Teams, canales y directivas.
       - Az.Accounts: Autenticacion centralizada y suscripciones en Azure.
       - Az.Resources: Gestion de recursos, plantillas ARM y Bicep en Azure.
    5. Registra auditoria completa de ejecucion en C:\ProgramData\M365Modules\Logs.

    Salida Intune:
    - Exit 0: Remediated (Todos los modulos ausentes fueron instalados y verificados con exito).
    - Exit 1: Error (Ocurrio un error critico durante la instalacion de los modulos).

.PARAMETER
    Ninguno.

.EXAMPLE
    Executes as Intune Remediation Script.

.NOTES
    Name:       Script Remediation - PowerShell - Instalar Modulos Administracion M365 Azure Intune - Remediation.ps1
    Author:     Alejandro Suarez (@alexsf93)
    Date:       2026-11-14
    Version:    1.1.0
    Context:    System
#>

# NOTA: Se usa SilentlyContinue para evitar que errores no criticos terminen el script.
# Las secciones criticas usan try/catch con ErrorAction Stop especifico.
$ErrorActionPreference = 'SilentlyContinue'
$ConfirmPreference     = 'None'

$Timestamp    = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
$LogDirectory = Join-Path $env:ProgramData "M365Modules\Logs"

if (-not (Test-Path -Path $LogDirectory)) {
    New-Item -ItemType Directory -Path $LogDirectory -Force | Out-Null
}
$LogFile = Join-Path -Path $LogDirectory "Remediation_M365Modules_$Timestamp.log"

function Write-RemLog {
    param (
        [Parameter(Mandatory = $true)]
        [string]$Message,
        [ValidateSet('INFO', 'SUCCESS', 'WARN', 'ERROR')]
        [string]$Level = 'INFO'
    )

    $timeStr = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logLine = "[$timeStr] [$Level] $Message"

    switch ($Level) {
        'INFO'    { Write-Host "[$Level] " -ForegroundColor Cyan -NoNewline; Write-Host $Message }
        'SUCCESS' { Write-Host "[$Level] " -ForegroundColor Green -NoNewline; Write-Host $Message }
        'WARN'    { Write-Host "[$Level] " -ForegroundColor Yellow -NoNewline; Write-Host $Message }
        'ERROR'   { Write-Host "[$Level] " -ForegroundColor Red -NoNewline; Write-Host $Message }
    }

    try {
        Add-Content -Path $LogFile -Value $logLine -Encoding UTF8 -ErrorAction SilentlyContinue
    } catch {}
}

# --- 1. Modulos esenciales a gestionar ---
$RequiredModules = @(
    @{ Name = "Microsoft.Graph";                        Description = "Entra ID (Azure AD), Intune y M365" },
    @{ Name = "ExchangeOnlineManagement";                Description = "Exchange Online y buzones (v3 REST)" },
    @{ Name = "Microsoft.Online.SharePoint.PowerShell";  Description = "SharePoint Online y OneDrive" },
    @{ Name = "PnP.PowerShell";                          Description = "Automatizacion avanzada SharePoint / M365" },
    @{ Name = "MicrosoftTeams";                          Description = "Microsoft Teams y directivas" },
    @{ Name = "Az.Accounts";                             Description = "Autenticacion centralizada Azure" },
    @{ Name = "Az.Resources";                            Description = "Gestion de recursos y despliegues ARM/Bicep" }
)

# --- 2. Deteccion de binario PowerShell 7 ---
# NOTA: Se excluye $env:LOCALAPPDATA porque bajo SYSTEM apunta al perfil del sistema,
# no a la instalacion de pwsh del usuario. Solo se usan rutas de maquina confiables.
function Get-PowerShellCoreExe {
    # Rutas de instalacion MSI/Win32 (siempre accesibles bajo SYSTEM)
    $candidates = @(
        "C:\Program Files\PowerShell\7\pwsh.exe",
        "C:\Program Files (x86)\PowerShell\7\pwsh.exe"
    )

    # Buscar cualquier version en Program Files (no solo v7)
    Get-Item -Path "C:\Program Files\PowerShell\*\pwsh.exe" -ErrorAction SilentlyContinue |
        Sort-Object { $_.VersionInfo.FileVersion } -Descending |
        ForEach-Object { $candidates += $_.FullName }

    # Instalacion AppX / Store - Get-AppxPackage -AllUsers funciona bajo SYSTEM
    try {
        $appxPkg = Get-AppxPackage -AllUsers -Name "*PowerShell*" -ErrorAction SilentlyContinue |
            Sort-Object Version -Descending | Select-Object -First 1
        if ($appxPkg) {
            $cand = Join-Path $appxPkg.InstallLocation "pwsh.exe"
            if (Test-Path $cand) {
                $candidates += $cand
            }
        }
    } catch {}

    foreach ($cand in $candidates) {
        if (Test-Path $cand) { return $cand }
    }
    return $null
}

# --- 3. Inicializacion del entorno de paquetes ---
function Initialize-PackageEnvironment {
    # 3.1. TLS 1.2 obligatorio - PS 5.1 en .NET 4.x usa TLS 1.0 por defecto y PSGallery lo rechaza
    Write-RemLog "Configurando protocolos de seguridad TLS 1.2 / TLS 1.3..." 'INFO'
    try {
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        # Intentar TLS 1.3 si existe (PS 7+ / .NET 5+)
        $tls13 = [Net.SecurityProtocolType]::Tls13
        if ($tls13) {
            [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor $tls13
        }
    } catch {}

    $script:PwshExe = Get-PowerShellCoreExe
    if ($script:PwshExe) {
        Write-RemLog "PowerShell 7 encontrado en: $($script:PwshExe)" 'INFO'
    } else {
        Write-RemLog "PowerShell 7 no encontrado en rutas de maquina. Se usara PS 5.1." 'WARN'
    }

    # 3.2. Proveedor NuGet - CRITICO: -Force -ForceBootstrap evita el prompt interactivo
    # que bloquea el script indefinidamente bajo SYSTEM (sesion no interactiva)
    Write-RemLog "Verificando proveedor NuGet..." 'INFO'
    try {
        $nuget = Get-PackageProvider -Name NuGet -ListAvailable -ErrorAction SilentlyContinue | Select-Object -First 1
        if (-not $nuget -or $nuget.Version -lt [System.Version]"2.8.5.201") {
            Write-RemLog "Instalando proveedor NuGet (desatendido)..." 'INFO'
            # -Force y -ForceBootstrap son esenciales para ejecucion silenciosa bajo SYSTEM
            Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Scope AllUsers -Force -ForceBootstrap -ErrorAction SilentlyContinue | Out-Null
        } else {
            Write-RemLog "Proveedor NuGet ya disponible (v$($nuget.Version))." 'INFO'
        }
    } catch {
        Write-RemLog "Aviso en instalacion de NuGet: $($_.Exception.Message)" 'WARN'
    }

    # 3.3. PSGallery como repositorio de confianza
    # Bajo SYSTEM la configuracion de repositorios es especifica del perfil de SYSTEM
    # y PSGallery aparece como "Untrusted" por defecto, lo que genera prompt interactivo.
    Write-RemLog "Configurando PSGallery como repositorio de confianza..." 'INFO'
    try {
        $repo = Get-PSRepository -Name 'PSGallery' -ErrorAction SilentlyContinue
        if ($repo) {
            if ($repo.InstallationPolicy -ne 'Trusted') {
                Set-PSRepository -Name 'PSGallery' -InstallationPolicy Trusted -ErrorAction SilentlyContinue
            }
        } else {
            # PSGallery no registrado en el perfil de SYSTEM: registrarlo
            Register-PSRepository -Default -InstallationPolicy Trusted -ErrorAction SilentlyContinue
        }
    } catch {
        Write-RemLog "Aviso al configurar PSGallery: $($_.Exception.Message)" 'WARN'
    }

    # 3.4. Motor PowerShellGet
    # Windows 11 incluye PowerShellGet v1.0.0.1 que tiene bugs y no funciona bien
    # con PSGallery moderno. Se actualiza a v2.x antes de instalar cualquier modulo.
    Write-RemLog "Verificando motor PowerShellGet..." 'INFO'
    $script:HasInstallModule = [bool](Get-Command Install-Module -ErrorAction SilentlyContinue)

    if ($script:HasInstallModule) {
        $loadedPSGet = Get-Module -Name PowerShellGet -ErrorAction SilentlyContinue | Select-Object -First 1
        if (-not $loadedPSGet) {
            # Importar la version mas reciente disponible
            Import-Module PowerShellGet -ErrorAction SilentlyContinue
            $loadedPSGet = Get-Module -Name PowerShellGet -ErrorAction SilentlyContinue | Select-Object -First 1
        }

        $psgetVer = if ($loadedPSGet) { $loadedPSGet.Version } else { [version]"0.0" }
        Write-RemLog "PowerShellGet activo: v$psgetVer" 'INFO'

        # Si la version es anterior a 2.0, actualizar primero para evitar fallos en Install-Module
        if ($psgetVer -lt [version]"2.0") {
            Write-RemLog "Actualizando PowerShellGet de v1.x a v2.x para garantizar compatibilidad..." 'INFO'
            try {
                Install-Module -Name PowerShellGet -Force -Scope AllUsers -AllowClobber `
                    -ErrorAction Stop -Confirm:$false
                Write-RemLog "PowerShellGet actualizado. Recargando modulo..." 'SUCCESS'
                # Recargar el modulo actualizado en la sesion actual
                Remove-Module -Name PowerShellGet -Force -ErrorAction SilentlyContinue
                Import-Module PowerShellGet -ErrorAction SilentlyContinue
            } catch {
                Write-RemLog "Aviso al actualizar PowerShellGet: $($_.Exception.Message)" 'WARN'
            }
        }
    } else {
        # Install-Module no disponible: intentar aprovisionar PowerShellGet desde cero
        Write-RemLog "Install-Module no disponible. Aprovisionando PowerShellGet..." 'INFO'
        $targetDir = "C:\Program Files\WindowsPowerShell\Modules"
        if (-not (Test-Path $targetDir)) { New-Item -ItemType Directory -Path $targetDir -Force | Out-Null }

        if ($script:PwshExe) {
            try {
                Write-RemLog "Aprovisionando PowerShellGet mediante pwsh ($($script:PwshExe))..." 'INFO'
                $repairCmd = "Set-PSRepository -Name 'PSGallery' -InstallationPolicy Trusted -ErrorAction SilentlyContinue; Save-Module -Name PowerShellGet -Path '$targetDir' -Force -ErrorAction SilentlyContinue; Save-Module -Name PackageManagement -Path '$targetDir' -Force -ErrorAction SilentlyContinue"
                Start-Process -FilePath $script:PwshExe -ArgumentList "-NoProfile", "-NonInteractive", "-ExecutionPolicy", "Bypass", "-Command", $repairCmd -Wait -NoNewWindow
            } catch {
                Write-RemLog "Aviso en aprovisionamiento via pwsh: $($_.Exception.Message)" 'WARN'
            }
        } else {
            try {
                Write-RemLog "Aprovisionando PowerShellGet via descarga directa..." 'INFO'
                $tempZip = Join-Path $env:TEMP "PowerShellGet_Remediation.zip"
                $wc = New-Object System.Net.WebClient
                $wc.DownloadFile("https://www.powershellgallery.com/api/v2/package/PowerShellGet/2.2.5", $tempZip)
                $destFolder = Join-Path $targetDir "PowerShellGet\2.2.5"
                if (-not (Test-Path $destFolder)) { New-Item -ItemType Directory -Path $destFolder -Force | Out-Null }
                Add-Type -AssemblyName System.IO.Compression.FileSystem
                [System.IO.Compression.ZipFile]::ExtractToDirectory($tempZip, $destFolder)
                Remove-Item -Path $tempZip -Force -ErrorAction SilentlyContinue
            } catch {
                Write-RemLog "Aviso en aprovisionamiento directo: $($_.Exception.Message)" 'WARN'
            }
        }

        Import-Module "C:\Program Files\WindowsPowerShell\Modules\PowerShellGet" -ErrorAction SilentlyContinue
        $script:HasInstallModule = [bool](Get-Command Install-Module -ErrorAction SilentlyContinue)
        if ($script:HasInstallModule) {
            Write-RemLog "Motor PowerShellGet operativo." 'SUCCESS'
        } else {
            Write-RemLog "No se pudo activar Install-Module. Se intentara via pwsh si esta disponible." 'WARN'
        }
    }
}

# --- 4. Comprobacion de instalacion individual ---
function Test-SingleModuleInstalled {
    param ([string]$ModuleName)

    # Rutas AllUsers accesibles bajo SYSTEM (absolutas, no $env:ProgramFiles que puede ser x86)
    $dirs = @(
        "C:\Program Files\WindowsPowerShell\Modules\$ModuleName",
        "C:\Program Files (x86)\WindowsPowerShell\Modules\$ModuleName",
        "C:\Program Files\PowerShell\Modules\$ModuleName",
        "$env:SystemRoot\System32\WindowsPowerShell\v1.0\Modules\$ModuleName"
    )
    foreach ($dir in $dirs) {
        if (Test-Path -Path $dir) {
            $hasFiles = Get-ChildItem -Path $dir -Filter "*.*" -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
            if ($hasFiles) { return $true }
        }
    }

    $found = Get-Module -ListAvailable -Name $ModuleName -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($found) { return $true }

    if ($script:PwshExe) {
        try {
            $verCheck = & $script:PwshExe -NoProfile -NonInteractive -ExecutionPolicy Bypass -Command "if (Get-Module -ListAvailable -Name '$ModuleName' -ErrorAction SilentlyContinue) { '1' }"
            if ($verCheck -match '1') { return $true }
        } catch {}
    }

    return $false
}

# --- 5. Instalacion de modulo individual ---
function Install-SingleCloudModule {
    param (
        [string]$ModuleName,
        [string]$Description
    )

    if (Test-SingleModuleInstalled -ModuleName $ModuleName) {
        Write-RemLog "El modulo '$ModuleName' ya esta presente en el equipo." 'SUCCESS'
        return $true
    }

    Write-RemLog "Instalando modulo ausente: '$ModuleName' ($Description)..." 'INFO'
    try {
        if ($script:HasInstallModule) {
            # -Scope AllUsers instala en C:\Program Files\WindowsPowerShell\Modules (accesible a todos)
            # NO omitir -Scope AllUsers: sin el, instala en el perfil de SYSTEM (invisible a usuarios)
            Install-Module -Name $ModuleName -Scope AllUsers -Force -AllowClobber `
                -Confirm:$false -ErrorAction Stop
        } elseif ($script:PwshExe) {
            # Fallback: instalar via proceso pwsh con -ExecutionPolicy Bypass
            $cmd = "[Net.ServicePointManager]::SecurityProtocol=[Net.SecurityProtocolType]::Tls12; Set-PSRepository -Name 'PSGallery' -InstallationPolicy Trusted -ErrorAction SilentlyContinue; Install-Module -Name '$ModuleName' -Scope AllUsers -Force -AllowClobber -Confirm:`$false"
            $proc = Start-Process -FilePath $script:PwshExe `
                -ArgumentList "-NoProfile", "-NonInteractive", "-ExecutionPolicy", "Bypass", "-Command", $cmd `
                -Wait -PassThru -NoNewWindow
            if ($proc.ExitCode -ne 0) {
                throw "pwsh.exe finalizo con codigo de error $($proc.ExitCode)"
            }
        } else {
            throw "No hay ningun motor de instalacion disponible en el sistema."
        }

        if (Test-SingleModuleInstalled -ModuleName $ModuleName) {
            Write-RemLog "Modulo '$ModuleName' instalado y verificado con exito." 'SUCCESS'
            return $true
        } else {
            Write-RemLog "No se pudo verificar el modulo '$ModuleName' tras la instalacion." 'WARN'
            return $false
        }
    } catch {
        Write-RemLog "Error al instalar el modulo '$ModuleName': $($_.Exception.Message)" 'ERROR'
        return $false
    }
}

# ==============================================================================
# EJECUCION PRINCIPAL DE REMEDIACION
# ==============================================================================
Write-RemLog "Iniciando remediacion desatendida de modulos de PowerShell para administracion cloud..." 'INFO'
Write-RemLog "Contexto de ejecucion: $([Security.Principal.WindowsIdentity]::GetCurrent().Name)" 'INFO'

Initialize-PackageEnvironment

$failedModules  = [System.Collections.Generic.List[string]]::new()
$successCount   = 0

foreach ($item in $RequiredModules) {
    $ok = Install-SingleCloudModule -ModuleName $item.Name -Description $item.Description
    if ($ok) {
        $successCount++
    } else {
        $failedModules.Add($item.Name)
    }
}

# Evaluacion final de la remediacion
if ($failedModules.Count -gt 0) {
    $errMsg = "Remediacion incompleta: No se pudieron instalar $($failedModules.Count) modulos: ($($failedModules -join ', ')). Fichero de log: $LogFile"
    Write-RemLog $errMsg 'ERROR'
    Write-Output "Error: $errMsg"
    Exit 1
}

$okMsg = "Remediacion completada con exito: Los $($RequiredModules.Count) modulos cloud requeridos estan instalados y verificados en el equipo. Fichero de log: $LogFile"
Write-RemLog $okMsg 'SUCCESS'
Write-Output "Remediated: $okMsg"
Exit 0
