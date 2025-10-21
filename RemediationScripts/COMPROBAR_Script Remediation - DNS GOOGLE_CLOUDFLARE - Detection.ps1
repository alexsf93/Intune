<#
=====================================================================================================
    DETECTION SCRIPT: DNS DE ADAPTADORES DE RED (8.8.8.8 y 1.1.1.1)
-----------------------------------------------------------------------------------------------------
Este script verifica que todos los adaptadores de red con conectividad IPv4 utilicen exclusivamente
los DNS "8.8.8.8" y "1.1.1.1". Si todos cumplen, devuelve exit code 0; en caso contrario, exit code 1.

Se excluyen de la comprobación los adaptadores virtuales o de VPN (Cisco, Hyper-V, VMware, VirtualBox,
WireGuard, FortiClient, etc.).

-----------------------------------------------------------------------------------------------------
REQUISITOS
-----------------------------------------------------------------------------------------------------
- PowerShell 5.1 o 7.x.
- Permisos para consultar configuración de red (en Intune se ejecuta como SYSTEM).

-----------------------------------------------------------------------------------------------------
¿CÓMO FUNCIONA?
-----------------------------------------------------------------------------------------------------
- Identifica adaptadores con IPv4 en estado "Connected" (Get-NetIPInterface).
- Excluye adaptadores virtuales o VPN según sus propiedades o nombre.
- Obtiene los DNS configurados por interfaz (Get-DnsClientServerAddress -IPv4).
- Valida que el conjunto de DNS por interfaz sea exactamente {8.8.8.8, 1.1.1.1} (orden indiferente).
- Devuelve:
  * Exit code 0 → Todo conforme.
  * Exit code 1 → Alguna interfaz conectada no usa exactamente esos DNS.

Notas:
- Si no hay adaptadores IPv4 "Connected", se devuelve exit code 0 (no hay nada que corregir).
- Solo se evalúan interfaces con IPv4 no virtuales ni de VPN.

-----------------------------------------------------------------------------------------------------
RESULTADOS
-----------------------------------------------------------------------------------------------------
- "OK" (exit code 0) → Todas las interfaces conectadas usan 8.8.8.8 y 1.1.1.1.
- "NOK" (exit code 1) → Alguna interfaz conectada no cumple la condición.

-----------------------------------------------------------------------------------------------------
INSTRUCCIONES DE USO
-----------------------------------------------------------------------------------------------------
- Usar como Detection Script en Intune Proactive Remediations.
- Complementar con el Remediation Script adjunto para corregir automáticamente.
- Interpretar el exit code para decidir la aplicación de remediación.

-----------------------------------------------------------------------------------------------------
AUTOR: Alejandro Suárez (@alexsf93)
=====================================================================================================
#>

[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

# DNS objetivo
$DesiredDns = @('8.8.8.8','1.1.1.1')

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
    } else {
        Write-Output "NOK: Se encontraron interfaces no conformes:"
        $nonCompliant | Format-Table -AutoSize | Out-String | Write-Output
        exit 1
    }
}
catch {
    Write-Error "Error en la detección: $($_.Exception.Message)"
    exit 1
}
