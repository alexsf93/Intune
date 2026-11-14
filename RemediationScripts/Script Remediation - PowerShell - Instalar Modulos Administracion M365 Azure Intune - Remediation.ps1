<#
.SYNOPSIS
    REMEDIATION SCRIPT: INSTALACION AUTOMATICA DE MODULOS POWERSHELL PARA ADMINISTRACION CLOUD (M365, AZURE, INTUNE)

.DESCRIPTION
    Script de remediacion desatendida para Microsoft Intune.
    Se ejecuta automaticamente cuando el script de deteccion detecta que faltan uno o mas modulos en el equipo.
    
    Acciones correctivas:
    1. Habilita protocolos de seguridad modernos TLS 1.2 / TLS 1.3.
    2. Aprovisiona el proveedor de paquetes NuGet y marca PSGallery como de confianza (Trusted).
    3. Asegura la presencia y operatividad del motor de paquetes PowerShellGet (v2.2.6) en Windows PowerShell 5.1.
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
    Version:    1.0.0
    Context:    System
#>

$ErrorActionPreference = 'Stop'
$Timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
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

# --- 3. Inicializacion del entorno de paquetes ---
function Initialize-PackageEnvironment {
    Write-RemLog "Configurando protocolos de seguridad TLS 1.2 / TLS 1.3..." 'INFO'
    try {
        [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
        if ([Net.SecurityProtocolType]::Tls13) {
            [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls13
        }
    } catch {}

    $script:PwshExe = Get-PowerShellCoreExe
    $script:HasInstallModule = [bool](Get-Command Install-Module -ErrorAction SilentlyContinue)

    # Si Windows PowerShell 5.1 no tiene Install-Module funcional, aprovisionar PowerShellGet 2.2.6
    if (-not $script:HasInstallModule) {
        Write-RemLog "Windows PowerShell 5.1 no dispone del motor de paquetes PowerShellGet. Procediendo a su aprovisionamiento..." 'INFO'
        $targetDir = "$env:ProgramFiles\WindowsPowerShell\Modules"
        if (-not (Test-Path $targetDir)) { New-Item -ItemType Directory -Path $targetDir -Force | Out-Null }

        if ($script:PwshExe) {
            try {
                Write-RemLog "Aprovisionando motor PowerShellGet mediante PowerShell 7 ($($script:PwshExe))..." 'INFO'
                $repairCmd = "Set-PSRepository -Name 'PSGallery' -InstallationPolicy Trusted -ErrorAction SilentlyContinue; Save-Module -Name PowerShellGet -Path '$targetDir' -Force -ErrorAction SilentlyContinue; Save-Module -Name PackageManagement -Path '$targetDir' -Force -ErrorAction SilentlyContinue"
                Start-Process -FilePath $script:PwshExe -ArgumentList "-NoProfile", "-ExecutionPolicy", "Bypass", "-Command", $repairCmd -Wait -NoNewWindow
            } catch {
                Write-RemLog "Aviso en aprovisionamiento mediante pwsh: $($_.Exception.Message)" 'WARN'
            }
        } else {
            try {
                Write-RemLog "Aprovisionando motor PowerShellGet mediante descarga directa desde PSGallery..." 'INFO'
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

        Import-Module "$env:ProgramFiles\WindowsPowerShell\Modules\PowerShellGet" -ErrorAction SilentlyContinue
        $script:HasInstallModule = [bool](Get-Command Install-Module -ErrorAction SilentlyContinue)
        if ($script:HasInstallModule) {
            Write-RemLog "Motor PowerShellGet operativo en Windows PowerShell 5.1." 'SUCCESS'
        }
    } else {
        Import-Module PowerShellGet -ErrorAction SilentlyContinue
        $modVer = (Get-Module -Name PowerShellGet -ErrorAction SilentlyContinue | Select-Object -First 1).Version
        Write-RemLog "Motor PowerShellGet operativo en Windows PowerShell 5.1 (v$modVer)." 'INFO'
    }

    # Proveedor NuGet
    if (Get-Command Get-PackageProvider -ErrorAction SilentlyContinue) {
        try {
            $nuget = Get-PackageProvider -Name NuGet -ListAvailable -ErrorAction SilentlyContinue | Select-Object -First 1
            if (-not $nuget -or $nuget.Version -lt [System.Version]"2.8.5.201") {
                Write-RemLog "Instalando/actualizando proveedor NuGet para descargas desatendidas..." 'INFO'
                Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force -Confirm:$false -ErrorAction SilentlyContinue | Out-Null
            }
        } catch {}
    }

    # Repositorio de confianza
    if (Get-Command Get-PSRepository -ErrorAction SilentlyContinue) {
        try {
            $repo = Get-PSRepository -Name 'PSGallery' -ErrorAction SilentlyContinue
            if ($repo -and $repo.InstallationPolicy -ne 'Trusted') {
                Write-RemLog "Estableciendo PSGallery como repositorio de confianza..." 'INFO'
                Set-PSRepository -Name 'PSGallery' -InstallationPolicy Trusted -ErrorAction SilentlyContinue
            }
        } catch {}
    }
}

# --- 4. Comprobacion de instalacion individual ---
function Test-SingleModuleInstalled {
    param ([string]$ModuleName)

    $dirs = @(
        "$env:ProgramFiles\WindowsPowerShell\Modules\$ModuleName",
        "$env:ProgramFiles\PowerShell\Modules\$ModuleName",
        "$env:SystemRoot\system32\WindowsPowerShell\v1.0\Modules\$ModuleName"
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
            $verCheck = & $script:PwshExe -NoProfile -Command "if (Get-Module -ListAvailable -Name '$ModuleName' -ErrorAction SilentlyContinue) { '1' }"
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
            Install-Module -Name $ModuleName -Scope AllUsers -Force -AllowClobber -Confirm:$false -ErrorAction Stop
        } elseif ($script:PwshExe) {
            $cmd = "Set-PSRepository -Name 'PSGallery' -InstallationPolicy Trusted -ErrorAction SilentlyContinue; Install-Module -Name '$ModuleName' -Scope AllUsers -Force -AllowClobber -Confirm:`$false"
            $proc = Start-Process -FilePath $script:PwshExe -ArgumentList "-NoProfile", "-ExecutionPolicy", "Bypass", "-Command", $cmd -Wait -PassThru -NoNewWindow
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

Initialize-PackageEnvironment

$failedModules = [System.Collections.Generic.List[string]]::new()
$successCount = 0

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
