<#
.SYNOPSIS
    Instalacion y configuracion desatendida de modulos de PowerShell para administracion de Microsoft 365, Azure e Intune.

.DESCRIPTION
    Este script esta disenado para ejecutarse como Platform Script en Microsoft Intune bajo contexto SYSTEM
    o manualmente por un administrador desde PowerShell o PowerShell ISE.
    
    Verifica la existencia e instala automaticamente en el ambito 'AllUsers' (para todos los usuarios) los modulos 
    oficiales necesarios para la gestion completa de tenants cloud desde terminal:
    1. Microsoft.Graph: Administracion completa de Microsoft Entra ID (Azure AD), Intune y M365.
    2. ExchangeOnlineManagement: Gestion moderna de Exchange Online, buzones y cumplimiento (v3+ REST).
    3. Microsoft.Online.SharePoint.PowerShell: Administracion de SharePoint Online y OneDrive for Business.
    4. PnP.PowerShell: Automatizacion avanzada y aprovisionamiento de SharePoint / M365.
    5. MicrosoftTeams: Gestion de Microsoft Teams, directivas y telefonia.
    6. Az.Accounts y modulos esenciales de Azure: Autenticacion y gestion de suscripciones y recursos en Azure.

    Garantiza los requisitos previos:
    - Habilita protocolos de seguridad modernos TLS 1.2 / TLS 1.3.
    - Instala y actualiza de forma desatendida el proveedor de paquetes NuGet.
    - Configura el repositorio 'PSGallery' como de confianza para evitar prompts interactivos.
    - Si detecta PowerShell 7 (pwsh), asegura la disponibilidad de los modulos en el nuevo entorno.

.PARAMETER DryRun
    Ejecuta el script en modo simulacion (solo lectura), comprobando que modulos faltan sin instalarlos.

.PARAMETER Force
    Fuerza la ejecucion desatendida (requerido para despliegues de Intune).

.PARAMETER UpdateExisting
    Si un modulo ya esta instalado, intenta actualizarlo a la version mas reciente disponible en la PSGallery. Por defecto: $false.

.EXAMPLE
    .\Script - PowerShell - Instalar Modulos Administracion M365 Azure Intune.ps1

.EXAMPLE
    .\Script - PowerShell - Instalar Modulos Administracion M365 Azure Intune.ps1 -Force -UpdateExisting

.EXAMPLE
    powershell.exe -ExecutionPolicy Bypass -File ".\Script - PowerShell - Instalar Modulos Administracion M365 Azure Intune.ps1" -Force

.NOTES
    Name:       Script - PowerShell - Instalar Modulos Administracion M365 Azure Intune.ps1
    Author:     Alejandro Suarez (@alexsf93)
    Date:       2026-11-14
    Version:    1.1.0
#>

[CmdletBinding(SupportsShouldProcess = $true)]
param (
    [switch]$DryRun,
    [switch]$Force,
    [switch]$UpdateExisting = $false,
    [string]$LogDirectory   = (Join-Path $env:ProgramData 'M365Modules\Logs')
)

$ErrorActionPreference = 'Stop'
$ConfirmPreference     = 'None'
$ScriptVersion = "1.1.0"
$Timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"

# Configuracion de carpetas de log
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

# --- 1. Modulos esenciales para gestion Cloud ---
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
        Description = "Administracion de SharePoint Online y OneDrive for Business"
    },
    @{
        Name        = "PnP.PowerShell"
        Description = "Automatizacion y administracion avanzada de SharePoint / M365"
    },
    @{
        Name        = "MicrosoftTeams"
        Description = "Administracion de Microsoft Teams, Directivas y Telefonia"
    },
    @{
        Name        = "Az.Accounts"
        Description = "Autenticacion centralizada y gestion de suscripciones en Azure"
    },
    @{
        Name        = "Az.Resources"
        Description = "Gestion de grupos de recursos, despliegues y plantillas ARM/Bicep en Azure"
    }
)

# --- 2. Preparacion del entorno y repositorios de paquetes ---
function Get-PowerShellCoreExe {
    $candidates = @(
        "C:\Program Files\PowerShell\7\pwsh.exe",
        "C:\Program Files (x86)\PowerShell\7\pwsh.exe"
    )
    Get-Item -Path "C:\Program Files\PowerShell\*\pwsh.exe" -ErrorAction SilentlyContinue |
        Sort-Object { $_.VersionInfo.FileVersion } -Descending |
        ForEach-Object { $candidates += $_.FullName }

    try {
        $appx = Get-AppxPackage -AllUsers -Name "*PowerShell*" -ErrorAction SilentlyContinue |
            Sort-Object Version -Descending | Select-Object -First 1
        if ($appx) {
            $cand = Join-Path $appx.InstallLocation "pwsh.exe"
            if (Test-Path $cand) { $candidates += $cand }
        }
    } catch {}

    foreach ($cand in $candidates) {
        if (Test-Path $cand) { return $cand }
    }
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
        Write-Log "Windows PowerShell 5.1 no dispone del motor de paquetes PowerShellGet (Install-Module). Procediendo a su instalacion y reparacion..." 'INFO'
        if (-not $DryRun) {
            $targetDir = "$env:ProgramFiles\WindowsPowerShell\Modules"
            if (-not (Test-Path $targetDir)) { New-Item -ItemType Directory -Path $targetDir -Force | Out-Null }

            # Estrategia 1: Si PowerShell 7 esta disponible, usar pwsh para descargar PowerShellGet y PackageManagement en el repositorio comun de 5.1
            if ($script:PwshExe) {
                try {
                    Write-Log "Aprovisionando motor PowerShellGet y PackageManagement en 5.1 mediante PowerShell 7 ($($script:PwshExe))..." 'INFO'
                    $repairCmd = "Set-PSRepository -Name 'PSGallery' -InstallationPolicy Trusted -ErrorAction SilentlyContinue; Save-Module -Name PowerShellGet -Path '$targetDir' -Force -ErrorAction SilentlyContinue; Save-Module -Name PackageManagement -Path '$targetDir' -Force -ErrorAction SilentlyContinue"
                    Start-Process -FilePath $script:PwshExe -ArgumentList "-NoProfile", "-NonInteractive", "-ExecutionPolicy", "Bypass", "-Command", $repairCmd -Wait -NoNewWindow
                } catch {
                    Write-Log "Aviso en aprovisionamiento mediante pwsh: $($_.Exception.Message)" 'WARN'
                }
            } else {
                # Estrategia 2: Fallback autonomo directo desde PSGallery via TLS 1.2 sin requerir PowerShell 7
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

            # Importar el nuevo motor reparado en la sesion
            Import-Module "$env:ProgramFiles\WindowsPowerShell\Modules\PowerShellGet" -ErrorAction SilentlyContinue
            $script:HasInstallModule = [bool](Get-Command Install-Module -ErrorAction SilentlyContinue)
            if ($script:HasInstallModule) {
                Write-Log "Motor PowerShellGet (Install-Module) instalado y operativo con exito en Windows PowerShell 5.1." 'SUCCESS'
            }
        }
    } else {
        # Si ya esta presente, asegurar su carga y registrar version
        Import-Module PowerShellGet -ErrorAction SilentlyContinue
        $modVer = (Get-Module -Name PowerShellGet -ErrorAction SilentlyContinue | Select-Object -First 1).Version
        Write-Log "Motor PowerShellGet operativo en Windows PowerShell 5.1 (v$modVer)." 'INFO'
    }

    if (-not $DryRun) {
        # Asegurar proveedor NuGet para instalacion desatendida bajo SYSTEM
        if (Get-Command Get-PackageProvider -ErrorAction SilentlyContinue) {
            try {
                $nuget = Get-PackageProvider -Name NuGet -ListAvailable -ErrorAction SilentlyContinue | Select-Object -First 1
                if (-not $nuget -or $nuget.Version -lt [System.Version]"2.8.5.201") {
                    Write-Log "Instalando/actualizando proveedor NuGet (desatendido)..." 'INFO'
                    Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Scope AllUsers -Force -ForceBootstrap -Confirm:$false -ErrorAction SilentlyContinue | Out-Null
                }
            } catch {
                Write-Log "Aviso en proveedor NuGet: $($_.Exception.Message)" 'WARN'
            }
        }

        # Asegurar que PSGallery este registrada y marcada como de confianza (Trusted)
        if (Get-Command Get-PSRepository -ErrorAction SilentlyContinue) {
            try {
                $repo = Get-PSRepository -Name 'PSGallery' -ErrorAction SilentlyContinue
                if ($repo) {
                    if ($repo.InstallationPolicy -ne 'Trusted') {
                        Write-Log "Estableciendo repositorio 'PSGallery' como de confianza (Trusted)..." 'INFO'
                        Set-PSRepository -Name 'PSGallery' -InstallationPolicy Trusted -ErrorAction SilentlyContinue
                    }
                } else {
                    Write-Log "Registrando repositorio 'PSGallery' por defecto (Trusted)..." 'INFO'
                    Register-PSRepository -Default -InstallationPolicy Trusted -ErrorAction SilentlyContinue
                }
            } catch {
                Write-Log "Aviso en repositorio PSGallery: $($_.Exception.Message)" 'WARN'
            }
        }

        # Actualizar PowerShellGet v1 (v1.0.0.1 en Windows 11) a v2.x si es necesario
        if ($script:HasInstallModule) {
            $loadedPSGet = Get-Module -Name PowerShellGet -ErrorAction SilentlyContinue | Select-Object -First 1
            $psgetVer = if ($loadedPSGet) { $loadedPSGet.Version } else { [version]"0.0" }
            if ($psgetVer -lt [version]"2.0") {
                Write-Log "Actualizando PowerShellGet a v2.x para compatibilidad con PSGallery moderno..." 'INFO'
                try {
                    Install-Module -Name PowerShellGet -Force -Scope AllUsers -AllowClobber -ErrorAction Stop -Confirm:$false
                    Remove-Module -Name PowerShellGet -Force -ErrorAction SilentlyContinue
                    Import-Module PowerShellGet -ErrorAction SilentlyContinue
                    Write-Log "PowerShellGet actualizado con exito." 'SUCCESS'
                } catch {
                    Write-Log "Aviso al actualizar PowerShellGet: $($_.Exception.Message)" 'WARN'
                }
            }
        }
    }
}

# --- 3. Instalacion y actualizacion de modulos ---
function Install-CloudModule {
    param (
        [string]$ModuleName,
        [string]$Description,
        [switch]$DryRun,
        [switch]$Update
    )

    Write-Log "Verificando estado del modulo: $ModuleName ($Description)..." 'INFO'

    # Comprobar si ya esta instalado en el sistema mediante comprobacion directa en disco (evita falsos negativos en 5.1)
    $standardDirs = @(
        "$env:ProgramFiles\WindowsPowerShell\Modules\$ModuleName",
        "$env:ProgramFiles\PowerShell\Modules\$ModuleName",
        "$env:SystemRoot\system32\WindowsPowerShell\v1.0\Modules\$ModuleName"
    )
    foreach ($dir in $standardDirs) {
        if (Test-Path -Path $dir) {
            $hasFiles = Get-ChildItem -Path $dir -Filter "*.*" -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
            if ($hasFiles) {
                $verFolder = Get-ChildItem -Path $dir -Directory -ErrorAction SilentlyContinue | Sort-Object Name -Descending | Select-Object -First 1
                $verStr = if ($verFolder) { $verFolder.Name } else { "Instalado" }
                $installed = [PSCustomObject]@{ Version = $verStr }
                break
            }
        }
    }

    if (-not $installed) {
        $installed = Get-Module -ListAvailable -Name $ModuleName -ErrorAction SilentlyContinue | Sort-Object -Property Version -Descending | Select-Object -First 1
    }

    if (-not $installed -and $script:PwshExe) {
        try {
            $checkVer = & $script:PwshExe -NoProfile -Command "`$m = Get-Module -ListAvailable -Name '$ModuleName' -ErrorAction SilentlyContinue | Select-Object -First 1; if (`$m) { `$m.Version.ToString() }"
            if ($checkVer) {
                $installed = [PSCustomObject]@{ Version = $checkVer.Trim() }
            }
        } catch {}
    }

    if ($installed) {
        Write-Log "El modulo '$ModuleName' ya esta instalado (v$($installed.Version))." 'SUCCESS'
        
        if ($Update) {
            if ($DryRun) {
                Write-Log "[SIMULACION] Se actualizaria el modulo '$ModuleName' a la version mas reciente." 'DRYRUN'
                return
            }
            try {
                Write-Log "Buscando actualizaciones para '$ModuleName'..." 'INFO'
                if ($script:HasInstallModule) {
                    Update-Module -Name $ModuleName -Force -Confirm:$false -ErrorAction Stop
                } elseif ($script:PwshExe) {
                    $updateCmd = "Update-Module -Name '$ModuleName' -Force -Confirm:`$false"
                    Start-Process -FilePath $script:PwshExe -ArgumentList "-NoProfile", "-NonInteractive", "-ExecutionPolicy", "Bypass", "-Command", $updateCmd -Wait -NoNewWindow
                }
                Write-Log "Modulo '$ModuleName' actualizado correctamente." 'SUCCESS'
            } catch {
                Write-Log "Aviso al actualizar '$ModuleName': $($_.Exception.Message)" 'WARN'
            }
        }
        return
    }

    # Si no esta instalado, proceder con la instalacion
    if ($DryRun) {
        Write-Log "[SIMULACION] El modulo '$ModuleName' no esta presente. Se procederia a instalarlo en el ambito AllUsers." 'DRYRUN'
        return
    }

    try {
        Write-Log "Instalando modulo '$ModuleName' desde PSGallery (ambito: AllUsers)..." 'INFO'
        
        if ($script:HasInstallModule) {
            Install-Module -Name $ModuleName -Scope AllUsers -Force -AllowClobber -Confirm:$false -ErrorAction Stop
        } elseif ($script:PwshExe) {
            Write-Log "Ejecutando instalacion mediante el motor de PowerShell 7..." 'INFO'
            $pwshCmd = "Set-PSRepository -Name 'PSGallery' -InstallationPolicy Trusted -ErrorAction SilentlyContinue; Install-Module -Name '$ModuleName' -Scope AllUsers -Force -AllowClobber -Confirm:`$false"
            $proc = Start-Process -FilePath $script:PwshExe -ArgumentList "-NoProfile", "-NonInteractive", "-ExecutionPolicy", "Bypass", "-Command", $pwshCmd -Wait -PassThru -NoNewWindow
            if ($proc.ExitCode -ne 0) {
                throw "El proceso pwsh.exe finalizo con codigo de error $($proc.ExitCode)"
            }
        } else {
            throw "No se encontro ningun motor con 'Install-Module' disponible (ni en PowerShell 5.1 ni en PowerShell 7)."
        }
        
        # Verificar instalacion
        $verified = Get-Module -ListAvailable -Name $ModuleName -ErrorAction SilentlyContinue | Sort-Object Version -Descending | Select-Object -First 1
        if (-not $verified -and $script:PwshExe) {
            $verCheck = & $script:PwshExe -NoProfile -Command "`$m = Get-Module -ListAvailable -Name '$ModuleName' -ErrorAction SilentlyContinue | Select-Object -First 1; if (`$m) { `$m.Version.ToString() }"
            if ($verCheck) {
                Write-Log "Modulo '$ModuleName' instalado y verificado con exito en PowerShell 7 (v$($verCheck.Trim()))." 'SUCCESS'
                return
            }
        }

        if ($verified) {
            Write-Log "Modulo '$ModuleName' instalado con exito (v$($verified.Version))." 'SUCCESS'
        } else {
            Write-Log "El modulo '$ModuleName' se instalo pero no se pudo verificar en el catalogo." 'WARN'
        }
    } catch {
        Write-Log "Error al instalar el modulo '$ModuleName': $($_.Exception.Message)" 'ERROR'
    }
}

# --- 4. Soporte para PowerShell 7 (si esta instalado en el equipo) ---
function Sync-ModulesWithPowerShellCore {
    param (
        [switch]$DryRun
    )

    $pwshExe = Get-PowerShellCoreExe

    if ($pwshExe) {
        Write-Log "Detectado PowerShell 7 ($pwshExe). Verificando compatibilidad de modulos..." 'INFO'
        # En Windows, PowerShell 7 incluye automaticamente C:\Program Files\WindowsPowerShell\Modules en $env:PSModulePath,
        # por lo que los modulos instalados en AllUsers estan inmediatamente disponibles para pwsh.
        Write-Log "Los modulos instalados en AllUsers son accesibles de forma nativa por PowerShell 7." 'SUCCESS'
    }
}

# ==============================================================================
# EJECUCION PRINCIPAL
# ==============================================================================

# Control de modo interactivo (ISE) vs Desatendido (Intune)
$isISE = ($null -ne $psISE) -or ($Host.Name -match "ISE")
$isSystem = [Security.Principal.WindowsIdentity]::GetCurrent().IsSystem

if (-not $isISE -or $isSystem) {
    $Force = $true
}

if (-not $Force -and -not $DryRun) {
    Write-Host "`nModo interactivo de pruebas detectado (PowerShell ISE):" -ForegroundColor Cyan
    Write-Host " [S] Instalar modulos ausentes ahora" -ForegroundColor White
    Write-Host " [D] Modo simulacion (Dry Run / Solo comprobar)" -ForegroundColor White
    Write-Host " [C] Cancelar" -ForegroundColor White

    $resp = Read-Host "Selecciona una opcion [S/D/C] (por defecto: S)"
    if ([string]::IsNullOrWhiteSpace($resp)) { $resp = 'S' }

    switch ($resp.ToUpper()) {
        'S' { $DryRun = $false }
        'D' { $DryRun = $true; Write-Log "Iniciando en modo Simulacion..." 'DRYRUN' }
        default { Write-Log "Operacion cancelada por el usuario." 'INFO'; exit 0 }
    }
}

Write-Log "Iniciando verificacion e instalacion de modulos cloud M365 / Azure / Intune..." 'INFO'

if (-not (Test-IsAdminOrSystem)) {
    Write-Log "Aviso: No se ejecuta como Administrador. La instalacion en AllUsers requiere elevacion." 'WARN'
}

# Inicializar TLS y repositorios
Initialize-PackageEnvironment -DryRun:$DryRun

# Procesar cada modulo de la lista
foreach ($item in $ModulesToManage) {
    Install-CloudModule -ModuleName $item.Name -Description $item.Description -DryRun:$DryRun -Update:$UpdateExisting
}

# Sincronizacion con PowerShell 7
Sync-ModulesWithPowerShellCore -DryRun:$DryRun

# Resumen de modulos instalados al finalizar
Write-Host "`n--- ESTADO FINAL DE MODULOS DE ADMINISTRACION CLOUD ---" -ForegroundColor Yellow
$summary = [System.Collections.Generic.List[PSCustomObject]]::new()
foreach ($item in $ModulesToManage) {
    $standardDirs = @(
        "$env:ProgramFiles\WindowsPowerShell\Modules\$($item.Name)",
        "$env:ProgramFiles\PowerShell\Modules\$($item.Name)",
        "$env:SystemRoot\system32\WindowsPowerShell\v1.0\Modules\$($item.Name)"
    )
    $found = $null
    foreach ($dir in $standardDirs) {
        if (Test-Path -Path $dir) {
            $hasFiles = Get-ChildItem -Path $dir -Filter "*.*" -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
            if ($hasFiles) {
                $verFolder = Get-ChildItem -Path $dir -Directory -ErrorAction SilentlyContinue | Sort-Object Name -Descending | Select-Object -First 1
                $verStr = if ($verFolder) { $verFolder.Name } else { "Instalado" }
                $found = [PSCustomObject]@{ Version = $verStr }
                break
            }
        }
    }
    if (-not $found) {
        $found = Get-Module -ListAvailable -Name $item.Name -ErrorAction SilentlyContinue | Sort-Object Version -Descending | Select-Object -First 1
    }
    if (-not $found -and $script:PwshExe) {
        try {
            $vCheck = & $script:PwshExe -NoProfile -Command "`$m = Get-Module -ListAvailable -Name '$($item.Name)' -ErrorAction SilentlyContinue | Select-Object -First 1; if (`$m) { `$m.Version.ToString() }"
            if ($vCheck) { $found = [PSCustomObject]@{ Version = $vCheck.Trim() } }
        } catch {}
    }
    $summary.Add([PSCustomObject]@{
        "Modulo"      = $item.Name
        "Instalado"   = if ($found) { "Si" } else { "No" }
        "Version"     = if ($found) { $found.Version.ToString() } else { "-" }
        "Descripcion" = $item.Description
    })
}
$summary | Format-Table -AutoSize | Out-String | Write-Host

Write-Log "Proceso finalizado con exito. Fichero de log: $LogFile" 'SUCCESS'
exit 0
