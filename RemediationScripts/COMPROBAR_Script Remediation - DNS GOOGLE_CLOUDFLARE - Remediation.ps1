<#
=====================================================================================================
    REMEDIATION SCRIPT: AJUSTE DE DNS EN ADAPTADORES DE RED
-----------------------------------------------------------------------------------------------------
Este script corrige la configuración de DNS en las interfaces IPv4 conectadas para que usen
exclusivamente "8.8.8.8" y "1.1.1.1".

Se excluyen de la remediación los adaptadores virtuales o de VPN (Cisco, Hyper-V, VMware, VirtualBox,
WireGuard, FortiClient, etc.).

-----------------------------------------------------------------------------------------------------
REQUISITOS
-----------------------------------------------------------------------------------------------------
- PowerShell 5.1 o 7.x.
- Permisos de administrador (en Intune se ejecuta como SYSTEM).

-----------------------------------------------------------------------------------------------------
¿CÓMO FUNCIONA?
-----------------------------------------------------------------------------------------------------
- Identifica interfaces IPv4 en estado "Connected".
- Excluye adaptadores virtuales o VPN según sus propiedades o nombre.
- Para cada interfaz que no cumpla, aplica:
  Set-DnsClientServerAddress -InterfaceIndex <idx> -ServerAddresses 8.8.8.8,1.1.1.1
- Al finalizar:
  * Exit code 0 → Remediación exitosa (o nada que remediar).
  * Exit code 1 → Falló la remediación en alguna interfaz.

Notas:
- Solo afecta IPv4.
- No cambia interfaces ya conformes.
- Tras la corrección, opcionalmente limpia caché DNS.

-----------------------------------------------------------------------------------------------------
INSTRUCCIONES DE USO
-----------------------------------------------------------------------------------------------------
- Usar como Remediation Script en Intune Proactive Remediations emparejado con el Detection Script.
- Revisar el output para ver qué interfaces fueron modificadas.

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

$changed = @()
$failed  = @()

try {
    # Interfaces IPv4 conectadas
    $connectedIfs = Get-NetIPInterface -AddressFamily IPv4 |
        Where-Object { $_.ConnectionState -eq 'Connected' }

    if (-not $connectedIfs) {
        Write-Output "Sin interfaces IPv4 en estado Connected. Nada que remediar."
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
        Write-Output "No hay interfaces conectadas válidas para remediar. Nada que hacer."
        exit 0
    }

    foreach ($if in $filteredIfs) {
        try {
            $dnsInfo = Get-DnsClientServerAddress -InterfaceIndex $if.InterfaceIndex -AddressFamily IPv4 -ErrorAction SilentlyContinue
            $servers = $dnsInfo.ServerAddresses

            if (-not (Test-SetEquality -A $servers -B $DesiredDns)) {
                Write-Output "Corrigiendo DNS en '$($if.InterfaceAlias)' (Idx $($if.InterfaceIndex))..."
                Set-DnsClientServerAddress -InterfaceIndex $if.InterfaceIndex -ServerAddresses $DesiredDns -ErrorAction Stop
                $changed += $if.InterfaceAlias
            } else {
                Write-Output "OK: '$($if.InterfaceAlias)' ya cumple. Sin cambios."
            }
        }
        catch {
            $failed += [pscustomobject]@{
                InterfaceAlias = $if.InterfaceAlias
                InterfaceIndex = $if.InterfaceIndex
                Error          = $_.Exception.Message
            }
        }
    }

    if ($changed.Count -gt 0) {
        # Limpia caché DNS tras cambios (opcional, no crítico)
        try { ipconfig /flushdns | Out-Null } catch { }
        Write-Output "Interfaz(es) corregida(s): $($changed -join ', ')"
    }

    if ($failed.Count -gt 0) {
        Write-Error "Fallos en remediación:"
        $failed | Format-Table -AutoSize | Out-String | Write-Error
        exit 1
    } else {
        Write-Output "Remediación completada sin errores."
        exit 0
    }
}
catch {
    Write-Error "Error general en remediación: $($_.Exception.Message)"
    exit 1
}