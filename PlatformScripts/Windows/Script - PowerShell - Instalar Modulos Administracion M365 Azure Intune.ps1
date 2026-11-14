<#
.SYNOPSIS
    Instalación y configuración desatendida de módulos de PowerShell para administración de Microsoft 365, Azure e Intune.

.DESCRIPTION
    Este script está diseñado para ejecutarse como Platform Script en Microsoft Intune bajo contexto SYSTEM
    o manualmente por un administrador desde PowerShell o PowerShell ISE.
    
    Verifica la existencia e instala automáticamente en el ámbito 'AllUsers' (para todos los usuarios) los módulos 
    oficiales necesarios para la gestión completa de tenants cloud desde terminal:
    1. Microsoft.Graph: Administración completa de Microsoft Entra ID (Azure AD), Intune y M365.
    2. ExchangeOnlineManagement: Gestión moderna de Exchange Online, buzones y cumplimiento (v3+ REST).
    3. Microsoft.Online.SharePoint.PowerShell: Administración de SharePoint Online y OneDrive for Business.
    4. PnP.PowerShell: Automatización avanzada y aprovisionamiento de SharePoint / M365.
    5. MicrosoftTeams: Gestión de Microsoft Teams, directivas y telefonía.
    6. Az.Accounts y módulos esenciales de Azure: Autenticación y gestión de suscripciones y recursos en Azure.

    Garantiza los requisitos previos:
    - Habilita protocolos de seguridad modernos TLS 1.2 / TLS 1.3.
    - Instala y actualiza de forma desatendida el proveedor de paquetes NuGet.
    - Configura el repositorio 'PSGallery' como de confianza para evitar prompts interactivos.
    - Si detecta PowerShell 7 (pwsh), asegura la disponibilidad de los módulos en el nuevo entorno.

.PARAMETER DryRun
    Ejecuta el script en modo simulación (solo lectura), comprobando qué módulos faltan sin instalarlos.

.PARAMETER Force
    Fuerza la ejecución desatendida (requerido para despliegues de Intune).

.PARAMETER UpdateExisting
    Si un módulo ya está instalado, intenta actualizarlo a la versión más reciente disponible en la PSGallery. Por defecto: $false.

.EXAMPLE
    .\Script - PowerShell - Instalar Modulos Administracion M365 Azure Intune.ps1

.EXAMPLE
    .\Script - PowerShell - Instalar Modulos Administracion M365 Azure Intune.ps1 -Force -UpdateExisting

.EXAMPLE
    powershell.exe -ExecutionPolicy Bypass -File ".\Script - PowerShell - Instalar Modulos Administracion M365 Azure Intune.ps1" -Force

.NOTES
    Name:       Script - PowerShell - Instalar Modulos Administracion M365 Azure Intune.ps1
    Author:     Alejandro Suárez (@alexsf93)
    Date:       2026-11-14
    Version:    1.0.0
#>

[CmdletBinding(SupportsShouldProcess = $true)]
param (
    [switch]$DryRun,
    [switch]$Force,
    [switch]$UpdateExisting = $false,
    [string]$LogDirectory   = (Join-Path $env:ProgramData 'M365Modules\Logs')
)

$ErrorActionPreference = 'Stop'
$ScriptVersion = "1.0.0"
$Timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"

# Configuración de carpetas de log
if (-not (Test-Path -Path $LogDirectory)) {
    New-Item -ItemType Directory -Path $LogDirectory -Force | Out-Null
}
$LogFile = Join-Path -Path $LogDirectory "Install_M365Modules_$Timestamp.log"

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

function Test-IsAdmin {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

# --- 1. Módulos esenciales para gestión Cloud ---
$ModulesToManage = @(
    @{
        Name        = "Microsoft.Graph"
        Description = "Entra ID (Azure AD), Intune, Usuarios, Grupos y Seguridad M365"
    },
    @{
        Name        = "ExchangeOnlineManagement"
        Description = "Exchange Online, Buzones, Flujo de correo y Seguridad/Cumplimiento"
    },
    @{
        Name        = "Microsoft.Online.SharePoint.PowerShell"
        Description = "Administración de SharePoint Online y OneDrive for Business"
    },
    @{
        Name        = "PnP.PowerShell"
        Description = "Automatización y administración avanzada de SharePoint / M365"
    },
    @{
        Name        = "MicrosoftTeams"
        Description = "Administración de Microsoft Teams, Directivas y Telefonía"
    },
    @{
        Name        = "Az.Accounts"
        Description = "Autenticación centralizada y gestión de suscripciones en Azure"
    },
    @{
        Name        = "Az.Resources"
        Description = "Gestión de grupos de recursos, despliegues y plantillas ARM/Bicep en Azure"
    }
)

# --- 2. Preparación del entorno y repositorios de paquetes ---
function Get-PowerShellCoreExe {
    $candidates = @(
        "$env:ProgramFiles\PowerShell\7\pwsh.exe",
        "${env:ProgramFiles(x86)}\PowerShell\7\pwsh.exe",
        (Join-Path $env:LOCALAPPDATA "Microsoft\WindowsApps\pwsh.exe")
    )
    foreach ($cand in $candidates) {
        if (Test-Path $cand) { return $cand }
    }
    try {
        $appx = Get-AppxPackage -Name "*PowerShell*" -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($appx) {
            $cand = Join-Path $appx.InstallLocation "pwsh.exe"
            if (Test-Path $cand) { return $cand }
        }
    } catch {}
    return $null
}

function Initialize-PackageEnvironment {
    param (
        [switch]$DryRun
    )

    Write-Log "Configurando protocolos de seguridad TLS 1.2 / TLS 1.3..." 'INFO'
    try {
        [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
        if ([Net.SecurityProtocolType]::Tls13) {
            [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls13
        }
    } catch {}

    $script:PwshExe = Get-PowerShellCoreExe
    $script:HasInstallModule = [bool](Get-Command Install-Module -ErrorAction SilentlyContinue)

    # Si Windows PowerShell 5.1 no tiene Install-Module funcional, instalar y aprovisionar el motor PowerShellGet 2.2.6
    if (-not $script:HasInstallModule) {
        Write-Log "Windows PowerShell 5.1 no dispone del motor de paquetes PowerShellGet (Install-Module). Procediendo a su instalación y reparación..." 'INFO'
        if (-not $DryRun) {
            $targetDir = "$env:ProgramFiles\WindowsPowerShell\Modules"
            if (-not (Test-Path $targetDir)) { New-Item -ItemType Directory -Path $targetDir -Force | Out-Null }

            # Estrategia 1: Si PowerShell 7 está disponible, usar pwsh para descargar PowerShellGet y PackageManagement en el repositorio común de 5.1
            if ($script:PwshExe) {
                try {
                    Write-Log "Aprovisionando motor PowerShellGet y PackageManagement en 5.1 mediante PowerShell 7 ($($script:PwshExe))..." 'INFO'
                    $repairCmd = "Set-PSRepository -Name 'PSGallery' -InstallationPolicy Trusted -ErrorAction SilentlyContinue; Save-Module -Name PowerShellGet -Path '$targetDir' -Force -ErrorAction SilentlyContinue; Save-Module -Name PackageManagement -Path '$targetDir' -Force -ErrorAction SilentlyContinue"
                    Start-Process -FilePath $script:PwshExe -ArgumentList "-NoProfile", "-ExecutionPolicy", "Bypass", "-Command", $repairCmd -Wait -NoNewWindow
                } catch {
                    Write-Log "Aviso en aprovisionamiento mediante pwsh: $($_.Exception.Message)" 'WARN'
                }
            } else {
                # Estrategia 2: Fallback autónomo directo desde PSGallery vía TLS 1.2 sin requerir PowerShell 7
                try {
                    Write-Log "Aprovisionando motor PowerShellGet mediante descarga directa segura desde PSGallery..." 'INFO'
                    $tempZip = Join-Path $env:TEMP "PowerShellGet_Bootstrap.zip"
                    $wc = New-Object System.Net.WebClient
                    $wc.DownloadFile("https://www.powershellgallery.com/api/v2/package/PowerShellGet/2.2.5", $tempZip)
                    $destFolder = Join-Path $targetDir "PowerShellGet\2.2.5"
                    if (-not (Test-Path $destFolder)) { New-Item -ItemType Directory -Path $destFolder -Force | Out-Null }
                    Add-Type -AssemblyName System.IO.Compression.FileSystem
                    [System.IO.Compression.ZipFile]::ExtractToDirectory($tempZip, $destFolder)
                    Remove-Item -Path $tempZip -Force -ErrorAction SilentlyContinue
                } catch {
                    Write-Log "Aviso en aprovisionamiento directo: $($_.Exception.Message)" 'WARN'
                }
            }

            # Importar el nuevo motor reparado en la sesión
            Import-Module "$env:ProgramFiles\WindowsPowerShell\Modules\PowerShellGet" -ErrorAction SilentlyContinue
            $script:HasInstallModule = [bool](Get-Command Install-Module -ErrorAction SilentlyContinue)
            if ($script:HasInstallModule) {
                Write-Log "Motor PowerShellGet (Install-Module) instalado y operativo con éxito en Windows PowerShell 5.1." 'SUCCESS'
            }
        }
    } else {
        # Si ya está presente, asegurar su carga y registrar versión
        Import-Module PowerShellGet -ErrorAction SilentlyContinue
        $modVer = (Get-Module -Name PowerShellGet -ErrorAction SilentlyContinue | Select-Object -First 1).Version
        Write-Log "Motor PowerShellGet operativo en Windows PowerShell 5.1 (v$modVer)." 'INFO'
    }

    if (-not $DryRun) {
        # Asegurar proveedor NuGet para instalación desatendida si el comando está disponible
        if (Get-Command Get-PackageProvider -ErrorAction SilentlyContinue) {
            try {
                $nuget = Get-PackageProvider -Name NuGet -ListAvailable -ErrorAction SilentlyContinue | Select-Object -First 1
                if (-not $nuget -or $nuget.Version -lt [System.Version]"2.8.5.201") {
                    Write-Log "Instalando/actualizando proveedor NuGet para descargas desatendidas..." 'INFO'
                    Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force -Confirm:$false -ErrorAction SilentlyContinue | Out-Null
                }
            } catch {}
        }

        # Asegurar que PSGallery esté marcada como de confianza (evita prompts interactivos)
        if (Get-Command Get-PSRepository -ErrorAction SilentlyContinue) {
            try {
                $repo = Get-PSRepository -Name 'PSGallery' -ErrorAction SilentlyContinue
                if ($repo -and $repo.InstallationPolicy -ne 'Trusted') {
                    Write-Log "Estableciendo repositorio 'PSGallery' como de confianza (Trusted)..." 'INFO'
                    Set-PSRepository -Name 'PSGallery' -InstallationPolicy Trusted -ErrorAction SilentlyContinue
                }
            } catch {}
        }
    }
}

# --- 3. Instalación y actualización de módulos ---
function Install-CloudModule {
    param (
        [string]$ModuleName,
        [string]$Description,
        [switch]$DryRun,
        [switch]$Update
    )

    Write-Log "Verificando estado del módulo: $ModuleName ($Description)..." 'INFO'

    # Comprobar si ya está instalado en el sistema
    $installed = Get-Module -ListAvailable -Name $ModuleName -ErrorAction SilentlyContinue | Sort-Object -Property Version -Descending | Select-Object -First 1
    if (-not $installed -and $script:PwshExe) {
        try {
            $checkVer = & $script:PwshExe -NoProfile -Command "`$m = Get-Module -ListAvailable -Name '$ModuleName' -ErrorAction SilentlyContinue | Select-Object -First 1; if (`$m) { `$m.Version.ToString() }"
            if ($checkVer) {
                $installed = [PSCustomObject]@{ Version = $checkVer.Trim() }
            }
        } catch {}
    }

    if ($installed) {
        Write-Log "El módulo '$ModuleName' ya está instalado (v$($installed.Version))." 'SUCCESS'
        
        if ($Update) {
            if ($DryRun) {
                Write-Log "[SIMULACIÓN] Se actualizaría el módulo '$ModuleName' a la versión más reciente." 'DRYRUN'
                return
            }
            try {
                Write-Log "Buscando actualizaciones para '$ModuleName'..." 'INFO'
                if ($script:HasInstallModule) {
                    Update-Module -Name $ModuleName -Force -Confirm:$false -ErrorAction Stop
                } elseif ($script:PwshExe) {
                    $updateCmd = "Update-Module -Name '$ModuleName' -Force -Confirm:`$false"
                    Start-Process -FilePath $script:PwshExe -ArgumentList "-NoProfile", "-ExecutionPolicy", "Bypass", "-Command", $updateCmd -Wait -NoNewWindow
                }
                Write-Log "Módulo '$ModuleName' actualizado correctamente." 'SUCCESS'
            } catch {
                Write-Log "Aviso al actualizar '$ModuleName': $($_.Exception.Message)" 'WARN'
            }
        }
        return
    }

    # Si no está instalado, proceder con la instalación
    if ($DryRun) {
        Write-Log "[SIMULACIÓN] El módulo '$ModuleName' no está presente. Se procedería a instalarlo en el ámbito AllUsers." 'DRYRUN'
        return
    }

    try {
        Write-Log "Instalando módulo '$ModuleName' desde PSGallery (ámbito: AllUsers)..." 'INFO'
        
        if ($script:HasInstallModule) {
            Install-Module -Name $ModuleName -Scope AllUsers -Force -AllowClobber -Confirm:$false -ErrorAction Stop
        } elseif ($script:PwshExe) {
            Write-Log "Ejecutando instalación mediante el motor de PowerShell 7..." 'INFO'
            $pwshCmd = "Set-PSRepository -Name 'PSGallery' -InstallationPolicy Trusted -ErrorAction SilentlyContinue; Install-Module -Name '$ModuleName' -Scope AllUsers -Force -AllowClobber -Confirm:`$false"
            $proc = Start-Process -FilePath $script:PwshExe -ArgumentList "-NoProfile", "-ExecutionPolicy", "Bypass", "-Command", $pwshCmd -Wait -PassThru -NoNewWindow
            if ($proc.ExitCode -ne 0) {
                throw "El proceso pwsh.exe finalizó con código de error $($proc.ExitCode)"
            }
        } else {
            throw "No se encontró ningún motor con 'Install-Module' disponible (ni en PowerShell 5.1 ni en PowerShell 7)."
        }
        
        # Verificar instalación
        $verified = Get-Module -ListAvailable -Name $ModuleName -ErrorAction SilentlyContinue | Sort-Object Version -Descending | Select-Object -First 1
        if (-not $verified -and $script:PwshExe) {
            $verCheck = & $script:PwshExe -NoProfile -Command "`$m = Get-Module -ListAvailable -Name '$ModuleName' -ErrorAction SilentlyContinue | Select-Object -First 1; if (`$m) { `$m.Version.ToString() }"
            if ($verCheck) {
                Write-Log "Módulo '$ModuleName' instalado y verificado con éxito en PowerShell 7 (v$($verCheck.Trim()))." 'SUCCESS'
                return
            }
        }

        if ($verified) {
            Write-Log "Módulo '$ModuleName' instalado con éxito (v$($verified.Version))." 'SUCCESS'
        } else {
            Write-Log "El módulo '$ModuleName' se instaló pero no se pudo verificar en el catálogo." 'WARN'
        }
    } catch {
        Write-Log "Error al instalar el módulo '$ModuleName': $($_.Exception.Message)" 'ERROR'
    }
}

# --- 4. Soporte para PowerShell 7 (si está instalado en el equipo) ---
function Sync-ModulesWithPowerShellCore {
    param (
        [switch]$DryRun
    )

    $pwshCandidates = @(
        "$env:ProgramFiles\PowerShell\7\pwsh.exe",
        "$env:LOCALAPPDATA\Microsoft\WindowsApps\pwsh.exe"
    )
    $pwshExe = $null
    foreach ($cand in $pwshCandidates) {
        if (Test-Path $cand) { $pwshExe = $cand; break }
    }
    if (-not $pwshExe) {
        $appx = Get-AppxPackage -Name "*PowerShell*" -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($appx) {
            $testExe = Join-Path $appx.InstallLocation "pwsh.exe"
            if (Test-Path $testExe) { $pwshExe = $testExe }
        }
    }

    if ($pwshExe) {
        Write-Log "Detectado PowerShell 7 ($pwshExe). Verificando compatibilidad de módulos..." 'INFO'
        # En Windows, PowerShell 7 incluye automáticamente C:\Program Files\WindowsPowerShell\Modules en $env:PSModulePath,
        # por lo que los módulos instalados en AllUsers están inmediatamente disponibles para pwsh.
        Write-Log "Los módulos instalados en AllUsers son accesibles de forma nativa por PowerShell 7." 'SUCCESS'
    }
}

# ==============================================================================
# EJECUCIÓN PRINCIPAL
# ==============================================================================

# Control de modo interactivo (ISE) vs Desatendido (Intune)
$isISE = ($null -ne $psISE) -or ($Host.Name -match "ISE")
$isSystem = [Security.Principal.WindowsIdentity]::GetCurrent().IsSystem

if (-not $isISE -or $isSystem) {
    $Force = $true
}

if (-not $Force -and -not $DryRun) {
    Write-Host "`nModo interactivo de pruebas detectado (PowerShell ISE):" -ForegroundColor Cyan
    Write-Host " [S] Instalar módulos ausentes ahora" -ForegroundColor White
    Write-Host " [D] Modo simulación (Dry Run / Solo comprobar)" -ForegroundColor White
    Write-Host " [C] Cancelar" -ForegroundColor White

    $resp = Read-Host "Selecciona una opción [S/D/C] (por defecto: S)"
    if ([string]::IsNullOrWhiteSpace($resp)) { $resp = 'S' }

    switch ($resp.ToUpper()) {
        'S' { $DryRun = $false }
        'D' { $DryRun = $true; Write-Log "Iniciando en modo Simulación..." 'DRYRUN' }
        default { Write-Log "Operación cancelada por el usuario." 'INFO'; exit 0 }
    }
}

Write-Log "Iniciando verificación e instalación de módulos cloud M365 / Azure / Intune..." 'INFO'

if (-not (Test-IsAdmin)) {
    Write-Log "Aviso: No se ejecuta como Administrador. La instalación en AllUsers requiere elevación." 'WARN'
}

# Inicializar TLS y repositorios
Initialize-PackageEnvironment -DryRun:$DryRun

# Procesar cada módulo de la lista
foreach ($item in $ModulesToManage) {
    Install-CloudModule -ModuleName $item.Name -Description $item.Description -DryRun:$DryRun -Update:$UpdateExisting
}

# Sincronización con PowerShell 7
Sync-ModulesWithPowerShellCore -DryRun:$DryRun

# Resumen de módulos instalados al finalizar
Write-Host "`n--- ESTADO FINAL DE MÓDULOS DE ADMINISTRACIÓN CLOUD ---" -ForegroundColor Yellow
$summary = [System.Collections.Generic.List[PSCustomObject]]::new()
foreach ($item in $ModulesToManage) {
    $found = Get-Module -ListAvailable -Name $item.Name -ErrorAction SilentlyContinue | Sort-Object Version -Descending | Select-Object -First 1
    if (-not $found -and $script:PwshExe) {
        try {
            $vCheck = & $script:PwshExe -NoProfile -Command "`$m = Get-Module -ListAvailable -Name '$($item.Name)' -ErrorAction SilentlyContinue | Select-Object -First 1; if (`$m) { `$m.Version.ToString() }"
            if ($vCheck) { $found = [PSCustomObject]@{ Version = $vCheck.Trim() } }
        } catch {}
    }
    $summary.Add([PSCustomObject]@{
        "Módulo"      = $item.Name
        "Instalado"   = if ($found) { "Sí" } else { "No" }
        "Versión"     = if ($found) { $found.Version.ToString() } else { "-" }
        "Descripción" = $item.Description
    })
}
$summary | Format-Table -AutoSize | Out-String | Write-Host

Write-Log "Proceso finalizado con éxito. Fichero de log: $LogFile" 'SUCCESS'
exit 0
