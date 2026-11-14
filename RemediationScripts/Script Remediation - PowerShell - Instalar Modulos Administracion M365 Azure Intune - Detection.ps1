<#
.SYNOPSIS
    DETECTION SCRIPT: VERIFICAR INSTALACION DE MODULOS POWERSHELL PARA ADMINISTRACION CLOUD (M365, AZURE, INTUNE)

.DESCRIPTION
    Este script comprueba si el equipo cumple con la politica de aprovisionamiento de modulos PowerShell
    esenciales para la administracion remota de entornos cloud de Microsoft:
    1. Microsoft.Graph: Entra ID (Azure AD), Intune y Seguridad M365.
    2. ExchangeOnlineManagement: Exchange Online, buzones y cumplimiento (v3 REST).
    3. Microsoft.Online.SharePoint.PowerShell: SharePoint Online y OneDrive for Business.
    4. PnP.PowerShell: Automatizacion avanzada y aprovisionamiento moderno.
    5. MicrosoftTeams: Gestion de Microsoft Teams, canales y directivas.
    6. Az.Accounts: Autenticacion centralizada y suscripciones en Azure.
    7. Az.Resources: Gestion de recursos, plantillas ARM y Bicep en Azure.

    Salida Intune:
    - Exit 0: Compliant (Todos los modulos requeridos estan instalados).
    - Exit 1: Non-Compliant (Faltan uno o mas modulos; requiere remediacion).

.PARAMETER
    Ninguno.

.EXAMPLE
    Executes as Intune Detection Script.

.NOTES
    Name:       Script Remediation - PowerShell - Instalar Modulos Administracion M365 Azure Intune - Detection.ps1
    Author:     Alejandro Suarez (@alexsf93)
    Date:       2026-11-14
    Version:    1.0.0
    Context:    System
#>

$ErrorActionPreference = 'SilentlyContinue'

# Lista de modulos requeridos para administracion Cloud
$RequiredModules = @(
    @{ Name = "Microsoft.Graph";                        Description = "Entra ID (Azure AD), Intune y M365" },
    @{ Name = "ExchangeOnlineManagement";                Description = "Exchange Online y buzones (v3 REST)" },
    @{ Name = "Microsoft.Online.SharePoint.PowerShell";  Description = "SharePoint Online y OneDrive" },
    @{ Name = "PnP.PowerShell";                          Description = "Automatizacion avanzada SharePoint / M365" },
    @{ Name = "MicrosoftTeams";                          Description = "Microsoft Teams y directivas" },
    @{ Name = "Az.Accounts";                             Description = "Autenticacion centralizada Azure" },
    @{ Name = "Az.Resources";                            Description = "Gestion de recursos y despliegues ARM/Bicep" }
)

function Test-ModuleInstalled {
    param (
        [Parameter(Mandatory = $true)]
        [string]$ModuleName
    )

    # 1. Comprobacion directa en los directorios estandar del sistema (AllUsers)
    # Evita falsos negativos en Windows PowerShell 5.1 con modulos compilados para Core/v7 (p. ej. PnP.PowerShell)
    $standardDirs = @(
        "$env:ProgramFiles\WindowsPowerShell\Modules\$ModuleName",
        "$env:ProgramFiles\PowerShell\Modules\$ModuleName",
        "$env:SystemRoot\system32\WindowsPowerShell\v1.0\Modules\$ModuleName"
    )

    foreach ($dir in $standardDirs) {
        if (Test-Path -Path $dir) {
            $hasFiles = Get-ChildItem -Path $dir -Filter "*.*" -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
            if ($hasFiles) {
                return $true
            }
        }
    }

    # 2. Comprobacion mediante catalogo nativo Get-Module
    $found = Get-Module -ListAvailable -Name $ModuleName -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($found) {
        return $true
    }

    # 3. Comprobacion mediante PowerShell 7 (si esta disponible)
    $pwshCandidates = @(
        "$env:ProgramFiles\PowerShell\7\pwsh.exe",
        "${env:ProgramFiles(x86)}\PowerShell\7\pwsh.exe",
        (Join-Path $env:LOCALAPPDATA "Microsoft\WindowsApps\pwsh.exe")
    )
    foreach ($cand in $pwshCandidates) {
        if (Test-Path $cand) {
            try {
                $verCheck = & $cand -NoProfile -Command "if (Get-Module -ListAvailable -Name '$ModuleName' -ErrorAction SilentlyContinue) { '1' }"
                if ($verCheck -match '1') {
                    return $true
                }
            } catch {}
            break
        }
    }

    return $false
}

# Evaluacion de modulos en el equipo
$missingModules = [System.Collections.Generic.List[string]]::new()
$installedModules = [System.Collections.Generic.List[string]]::new()

foreach ($item in $RequiredModules) {
    if (Test-ModuleInstalled -ModuleName $item.Name) {
        $installedModules.Add($item.Name)
    } else {
        $missingModules.Add("$($item.Name) ($($item.Description))")
    }
}

# Conclusion de la deteccion para Intune
if ($missingModules.Count -gt 0) {
    Write-Output "Non-Compliant: Faltan $($missingModules.Count) de $($RequiredModules.Count) modulos requeridos en el equipo:"
    $missingModules | ForEach-Object { Write-Output " - $_" }
    Exit 1
}

Write-Output "Compliant: Todos los modulos cloud de administracion ($($installedModules.Count)/$($RequiredModules.Count)) estan instalados y verificados en el equipo."
Exit 0
