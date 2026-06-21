<#
.SYNOPSIS
    DETECTION SCRIPT: DNS DE ADAPTADORES DE RED (8.8.8.8 y 1.1.1.1)

.DESCRIPTION
    Este script verifica que todos los adaptadores de red con conectividad IPv4 utilicen exclusivamente
    los DNS "8.8.8.8" y "1.1.1.1". Si todos cumplen, devuelve exit code 0; en caso contrario, exit code 1.

.PARAMETER
    Ninguno.

.EXAMPLE
    Executes as Intune Detection Script.

.NOTES
    Name: COMPROBAR_Script Remediation - DNS GOOGLE_CLOUDFLARE - Detection.ps1
    Author: Alejandro Suárez (@alexsf93)
    Version: 1.0.0
    Date: 2026-01-21
    Context: System
#>

[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

# DNS objetivo
$DesiredDns = @('8.8.8.8', '1.1.1.1')

# Patrones de exclusión (regex, sin distinción de mayúsculas/minúsculas)
$ExcludePatterns = @(
    'virtual',                 # genérico
    'hyper-?v',
    'vmware',
    'vbox|virtualbox',
    'npcap|loopback',
    'wi-?fi\s*direct',
    'isatap|teredo|6to4',
    'cisco.*(anyconnect|secure\s*client|vpn)',
    'globalprotect',
    'forti(client|gate|net|vpn)',
    'juniper|pulse\s*secure',
    'check\s*point|sonicwall',
    'openvpn|tap-?windows',
    'wireguard',
    'tailscale',
    'zerotier',
    'hamachi',
    'nordlynx|protonvpn|expressvpn|surfshark',
    'gl-?inet'
) -join '|'

function Test-SetEquality {
    param(
        [string[]]$A,
        [string[]]$B
    )
    $sa = ($A | Where-Object { $_ } | Sort-Object -Unique)
    $sb = ($B | Where-Object { $_ } | Sort-Object -Unique)
    return ($sa -join ',') -eq ($sb -join ',')
}

try {
    # Interfaces IPv4 conectadas
    $connectedIfs = Get-NetIPInterface -AddressFamily IPv4 |
    Where-Object { $_.ConnectionState -eq 'Connected' }

    if (-not $connectedIfs) {
        Write-Output "Sin interfaces IPv4 en estado Connected. No se evalúa cumplimiento. OK."
        exit 0
    }

    # Excluir virtuales o VPN
    $filteredIfs = @()
    foreach ($ifi in $connectedIfs) {
        $na = Get-NetAdapter -InterfaceIndex $ifi.InterfaceIndex -ErrorAction SilentlyContinue
        if (-not $na) { continue }

        $desc = "$($na.InterfaceDescription) $($na.Name)"
        $isVirtualish = ($na.Virtual -eq $true) -or ($na.HardwareInterface -ne $true) -or ($desc -match $ExcludePatterns)

        if (-not $isVirtualish) {
            $filteredIfs += $ifi
        }
    }

    if (-not $filteredIfs) {
        Write-Output "No hay interfaces conectadas válidas para evaluar. OK."
        exit 0
    }

    $nonCompliant = @()

    foreach ($if in $filteredIfs) {
        $dnsInfo = Get-DnsClientServerAddress -InterfaceIndex $if.InterfaceIndex -AddressFamily IPv4 -ErrorAction SilentlyContinue
        $servers = $dnsInfo.ServerAddresses

        if (-not (Test-SetEquality -A $servers -B $DesiredDns)) {
            $nonCompliant += [pscustomobject]@{
                InterfaceAlias = $if.InterfaceAlias
                InterfaceIndex = $if.InterfaceIndex
                CurrentDNS     = ($servers -join ', ')
                RequiredDNS    = ($DesiredDns -join ', ')
            }
        }
    }

    if ($nonCompliant.Count -eq 0) {
        Write-Output "OK: Todas las interfaces conectadas usan 8.8.8.8 y 1.1.1.1."
        exit 0
    }
    else {
        Write-Output "NOK: Se encontraron interfaces no conformes:"
        $nonCompliant | Format-Table -AutoSize | Out-String | Write-Output
        exit 1
    }
}
catch {
    Write-Error "Error en la detección: $($_.Exception.Message)"
    exit 1
}
